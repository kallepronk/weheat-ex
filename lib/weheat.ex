defmodule Weheat do
  @moduledoc """
  Thin client for the WeHeat third-party API. One function per endpoint; DTOs mirror the
  Python `weheat` SDK (`Weheat.DTO.*`); no caching or behaviour layer.

      client = Weheat.new(token: "eyJ...")           # static token
      client = Weheat.new(token: token_source_pid)   # Weheat.Auth.TokenSource
      {:ok, %Weheat.DTO.ReadUserMeDto{} = me} = Weheat.me(client)
  """

  @default_base_url "https://api.weheat.nl/third_party/api/v1"

  defstruct base_url: @default_base_url,
            token: nil,
            rate_limiter: Weheat.RateLimiter,
            req_options: []

  @type token :: String.t() | (-> {:ok, String.t()} | {:error, term()}) | GenServer.server()
  @type t :: %__MODULE__{
          base_url: String.t(),
          token: token(),
          rate_limiter: GenServer.server() | false,
          req_options: keyword()
        }
  @type interval :: :Minute | :FiveMinute | :FifteenMinute | :Hour | :Day | :Week | :Month | :Year
  @type result(dto) :: {:ok, dto} | {:error, Weheat.Error.t() | term()}

  alias Weheat.Auth.TokenSource
  alias Weheat.DTO

  @doc """
  Builds a client.

  Options: `:token` (string, zero-arity fun, or a `Weheat.Auth.TokenSource`), `:base_url`,
  `:rate_limiter` (server name/pid, or `false` to disable), `:req_options` (merged into `Req.new/1`).
  """
  @spec new(keyword()) :: t()
  def new(opts), do: struct!(__MODULE__, opts)

  @doc "GET /users/me"
  @spec me(t()) :: result(DTO.ReadUserMeDto.t())
  def me(client), do: get(client, "/users/me", [], DTO.ReadUserMeDto)

  @doc """
  GET /heat-pumps. Query options: `:page`, `:page_size`, `:models` (list of ints),
  `:organisation_id`, `:search`, `:state`.
  """
  @spec heat_pumps(t(), keyword()) :: result(DTO.ReadAllHeatPumpDtoPagedResponse.t())
  def heat_pumps(client, query \\ []) do
    params =
      Enum.flat_map(query, fn
        {:page, v} -> [page: v]
        {:page_size, v} -> [pageSize: v]
        {:models, list} -> Enum.map(list, &{:Model, &1})
        {:organisation_id, v} -> [OrganisationId: v]
        {:search, v} -> [Search: v]
        {:state, v} -> [State: v]
      end)

    get(client, "/heat-pumps", params, DTO.ReadAllHeatPumpDtoPagedResponse)
  end

  @doc "GET /heat-pumps/{id}"
  @spec heat_pump(t(), String.t()) :: result(DTO.ReadHeatPumpDto.t())
  def heat_pump(client, id),
    do: get(client, "/heat-pumps/#{URI.encode(id)}", [], DTO.ReadHeatPumpDto)

  @doc "GET /heat-pumps/{id}/logs/latest"
  @spec latest_log(t(), String.t()) :: result(DTO.RawHeatpumpLogAndIsOnlineDto.t())
  def latest_log(client, id),
    do:
      get(
        client,
        "/heat-pumps/#{URI.encode(id)}/logs/latest",
        [],
        DTO.RawHeatpumpLogAndIsOnlineDto
      )

  @doc "GET /heat-pumps/{id}/logs. Per-request window depends on the interval (see README)."
  @spec logs(t(), String.t(), DateTime.t(), DateTime.t(), interval()) ::
          result([DTO.HeatPumpLogViewDto.t()])
  def logs(client, id, start_time, end_time, interval) do
    params = time_range(start_time, end_time) ++ [interval: interval]
    get(client, "/heat-pumps/#{URI.encode(id)}/logs", params, {:list, DTO.HeatPumpLogViewDto})
  end

  @doc "GET /heat-pumps/{id}/logs/raw. Window is at most 4 hours."
  @spec raw_logs(t(), String.t(), DateTime.t(), DateTime.t()) ::
          result([DTO.RawHeatPumpLogDto.t()])
  def raw_logs(client, id, start_time, end_time),
    do:
      get(
        client,
        "/heat-pumps/#{URI.encode(id)}/logs/raw",
        time_range(start_time, end_time),
        {:list, DTO.RawHeatPumpLogDto}
      )

  @doc "GET /energy-logs/{id}"
  @spec energy_logs(t(), String.t(), DateTime.t(), DateTime.t(), interval()) ::
          result([DTO.EnergyViewDto.t()])
  def energy_logs(client, id, start_time, end_time, interval) do
    params = time_range(start_time, end_time) ++ [interval: interval]
    get(client, "/energy-logs/#{URI.encode(id)}", params, {:list, DTO.EnergyViewDto})
  end

  @doc "GET /energy-logs/{id}/total"
  @spec energy_total(t(), String.t()) :: result(DTO.TotalEnergyAggregate.t())
  def energy_total(client, id),
    do: get(client, "/energy-logs/#{URI.encode(id)}/total", [], DTO.TotalEnergyAggregate)

  defp time_range(start_time, end_time) do
    Enum.reject([startTime: iso(start_time), endTime: iso(end_time)], fn {_, v} -> is_nil(v) end)
  end

  defp iso(nil), do: nil
  defp iso(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp get(client, path, params, shape) do
    with {:ok, token} <- resolve_token(client.token),
         :ok <- maybe_wait(client.rate_limiter),
         {:ok, %Req.Response{status: status, body: body}} <-
           Req.get(request(client, token, path, params)),
         {:ok, json} <- decode(status, body) do
      {:ok, cast(shape, json)}
    end
  end

  defp request(client, token, path, params) do
    Req.new(
      [url: client.base_url <> path, params: params, auth: {:bearer, token}, decode_body: false] ++
        client.req_options
    )
  end

  defp decode(status, body) when status in 200..299, do: JSON.decode(body)
  defp decode(status, body), do: {:error, %Weheat.Error{status: status, body: body}}

  defp cast({:list, module}, list) when is_list(list), do: Enum.map(list, &module.from_map/1)
  defp cast(module, map) when is_map(map), do: module.from_map(map)

  defp resolve_token(token) when is_binary(token), do: {:ok, token}
  defp resolve_token(fun) when is_function(fun, 0), do: fun.()
  defp resolve_token(source), do: TokenSource.token(source)

  defp maybe_wait(false), do: :ok
  defp maybe_wait(server), do: Weheat.RateLimiter.wait(server)
end
