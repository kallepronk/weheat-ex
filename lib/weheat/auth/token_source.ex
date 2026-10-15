defmodule Weheat.Auth.TokenSource do
  @moduledoc """
  Holds a `Weheat.Auth.Token` and refreshes it before it expires.

  Keycloak rotates refresh tokens, so pass `on_refresh: fn token -> ... end` and persist
  `token.refresh_token`; otherwise a restart locks you out.

      {:ok, src} =
        Weheat.Auth.TokenSource.start_link(
          client_id: Weheat.Auth.community_client_id(), refresh_token: rt,
          on_refresh: &MyApp.save_refresh_token/1)

      client = Weheat.new(token: src)
  """
  use Agent

  @skew_seconds 30

  @type option ::
          {:client_id, String.t()}
          | {:client_secret, String.t() | nil}
          | {:refresh_token, String.t()}
          | {:token, Weheat.Auth.Token.t()}
          | {:on_refresh, (Weheat.Auth.Token.t() -> any())}
          | {:req_options, keyword()}
          | {:name, GenServer.name()}

  @spec start_link([option()]) :: Agent.on_start()
  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)

    state = %{
      client_id: Keyword.fetch!(opts, :client_id),
      client_secret: Keyword.get(opts, :client_secret),
      token: Keyword.get(opts, :token) || seed(Keyword.fetch!(opts, :refresh_token)),
      on_refresh: Keyword.get(opts, :on_refresh, fn _ -> :ok end),
      req_options: Keyword.get(opts, :req_options, [])
    }

    if name,
      do: Agent.start_link(fn -> state end, name: name),
      else: Agent.start_link(fn -> state end)
  end

  @doc "Returns a valid access token, refreshing first when expired or about to expire."
  @spec token(Agent.agent()) :: {:ok, String.t()} | {:error, term()}
  def token(agent) do
    Agent.get_and_update(agent, fn state ->
      if fresh?(state.token), do: {{:ok, state.token.access_token}, state}, else: refresh(state)
    end)
  end

  defp refresh(state) do
    case Weheat.Auth.refresh(
           state.client_id,
           state.client_secret,
           state.token.refresh_token,
           state.req_options
         ) do
      {:ok, token} ->
        state.on_refresh.(token)
        {{:ok, token.access_token}, %{state | token: token}}

      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp seed(refresh_token),
    do: %Weheat.Auth.Token{
      access_token: nil,
      refresh_token: refresh_token,
      expires_at: ~U[1970-01-01 00:00:00Z]
    }

  defp fresh?(%{access_token: nil}), do: false

  defp fresh?(%{expires_at: expires_at}),
    do:
      DateTime.compare(DateTime.add(DateTime.utc_now(), @skew_seconds, :second), expires_at) ==
        :lt
end
