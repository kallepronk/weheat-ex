defmodule WeheatTest do
  use ExUnit.Case, async: true

  alias Weheat.DTO

  @fixtures Path.expand("fixtures", __DIR__)

  # Serves a fixture and hands the captured request back to the test process.
  defp client(fixture) do
    test_pid = self()

    Req.Test.stub(Weheat, fn conn ->
      conn = Plug.Conn.fetch_query_params(conn)
      send(test_pid, {:request, conn})

      if Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"] do
        Req.Test.json(
          conn,
          @fixtures |> Path.join(fixture <> ".json") |> File.read!() |> JSON.decode!()
        )
      else
        Plug.Conn.send_resp(conn, 401, "nope")
      end
    end)

    Weheat.new(
      token: "test-token",
      base_url: "http://api.test",
      rate_limiter: false,
      req_options: [plug: {Req.Test, Weheat}]
    )
  end

  defp last_request do
    assert_received {:request, conn}
    conn
  end

  test "me" do
    assert {:ok, %DTO.ReadUserMeDto{id: "x", created_on: %DateTime{}}} =
             Weheat.me(client("users_me"))

    assert last_request().request_path == "/users/me"
  end

  test "heat_pumps maps query options" do
    assert {:ok, %DTO.ReadAllHeatPumpDtoPagedResponse{data: [pump], metadata: meta}} =
             Weheat.heat_pumps(client("heat_pumps"), page: 1, page_size: 1000, state: 3)

    assert %DTO.ReadAllHeatPumpDto{serial_number: "x"} = pump
    assert meta.total_count == 1
    conn = last_request()
    assert conn.request_path == "/heat-pumps"
    assert conn.query_params == %{"page" => "1", "pageSize" => "1000", "State" => "3"}
  end

  test "heat_pump" do
    assert {:ok, %DTO.ReadHeatPumpDto{id: "x"}} =
             Weheat.heat_pump(client("heat_pump"), "abc")

    assert last_request().request_path == "/heat-pumps/abc"
  end

  test "latest_log" do
    assert {:ok, %DTO.RawHeatpumpLogAndIsOnlineDto{is_online: true, t_water_in: 1.5}} =
             Weheat.latest_log(client("logs_latest"), "abc")

    assert last_request().request_path == "/heat-pumps/abc/logs/latest"
  end

  test "logs sends time range and interval" do
    start_time = ~U[2026-09-01 00:00:00Z]

    assert {:ok, [%DTO.HeatPumpLogViewDto{t_water_in_average: 1.5}]} =
             Weheat.logs(
               client("logs"),
               "abc",
               start_time,
               DateTime.add(start_time, 1, :day),
               :Hour
             )

    conn = last_request()
    assert conn.request_path == "/heat-pumps/abc/logs"

    assert conn.query_params == %{
             "startTime" => "2026-09-01T00:00:00Z",
             "endTime" => "2026-09-02T00:00:00Z",
             "interval" => "Hour"
           }
  end

  test "raw_logs omits nil bounds" do
    assert {:ok, [%DTO.RawHeatPumpLogDto{}]} =
             Weheat.raw_logs(client("logs_raw"), "abc", nil, nil)

    conn = last_request()
    assert conn.request_path == "/heat-pumps/abc/logs/raw"
    assert conn.query_params == %{}
  end

  test "energy_logs" do
    assert {:ok, [%DTO.EnergyViewDto{total_ein_heating: 1.5}]} =
             Weheat.energy_logs(client("energy_logs"), "abc", nil, nil, :Day)

    conn = last_request()
    assert conn.request_path == "/energy-logs/abc"
    assert conn.query_params == %{"interval" => "Day"}
  end

  test "energy_total" do
    assert {:ok, %DTO.TotalEnergyAggregate{total_ein_heating: 1.5}} =
             Weheat.energy_total(client("energy_total"), "abc")

    assert last_request().request_path == "/energy-logs/abc/total"
  end

  test "non-2xx becomes Weheat.Error" do
    bad = %{client("users_me") | token: "wrong"}
    assert {:error, %Weheat.Error{status: 401, body: "nope"}} = Weheat.me(bad)
  end

  test "zero-arity token fun is called" do
    c = %{client("users_me") | token: fn -> {:ok, "test-token"} end}
    assert {:ok, _} = Weheat.me(c)
  end
end
