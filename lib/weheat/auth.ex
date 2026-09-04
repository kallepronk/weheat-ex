defmodule Weheat.Auth do
  @moduledoc """
  Keycloak token grants for the WeHeat realm. Pure request functions; see
  `Weheat.Auth.TokenSource` for a process that keeps a token fresh.

  No registration needed: WeHeat exposes the public `WeheatCommunityAPI` client
  (`community_client_id/0`, no secret) which supports the password grant. The confidential
  `HomeAssistantAPI` client, whose ID and secret are published in the WeHeat knowledge base,
  works too; pass its secret. Pass `nil` as the secret for public clients.
  """

  @community_client_id "WeheatCommunityAPI"
  @token_url "https://auth.weheat.nl/auth/realms/Weheat/protocol/openid-connect/token"
  @scope "openid offline_access"

  defmodule Token do
    @moduledoc "An access token plus the refresh token and expiry Keycloak returned with it."
    defstruct [:access_token, :refresh_token, :expires_at]

    @type t :: %__MODULE__{
            access_token: String.t(),
            refresh_token: String.t() | nil,
            expires_at: DateTime.t()
          }
  end

  def token_url, do: @token_url
  def community_client_id, do: @community_client_id

  @doc "Password grant with a WeHeat account. Community tools use this with `community_client_id/0`."
  @spec password_grant(String.t(), String.t() | nil, String.t(), String.t(), keyword()) ::
          {:ok, Token.t()} | {:error, term()}
  def password_grant(client_id, client_secret, username, password, req_opts \\ []) do
    post(
      %{
        grant_type: "password",
        client_id: client_id,
        client_secret: client_secret,
        username: username,
        password: password,
        scope: @scope
      },
      req_opts
    )
  end

  @doc "Exchanges a refresh token for a new token pair. Keycloak rotates the refresh token."
  @spec refresh(String.t(), String.t() | nil, String.t(), keyword()) ::
          {:ok, Token.t()} | {:error, term()}
  def refresh(client_id, client_secret, refresh_token, req_opts \\ []) do
    post(
      %{
        grant_type: "refresh_token",
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token
      },
      req_opts
    )
  end

  defp post(form, req_opts) do
    form = Map.reject(form, fn {_k, v} -> is_nil(v) end)
    req = Req.new([url: @token_url, form: form, decode_body: false] ++ req_opts)

    with {:ok, %Req.Response{status: 200, body: body}} <- Req.post(req),
         {:ok, %{"access_token" => access, "expires_in" => expires_in} = json} <-
           JSON.decode(body) do
      {:ok,
       %Token{
         access_token: access,
         refresh_token: json["refresh_token"],
         expires_at: DateTime.add(DateTime.utc_now(), expires_in, :second)
       }}
    else
      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, %Weheat.Error{status: status, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
