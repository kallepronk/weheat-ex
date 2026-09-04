defmodule Weheat.LiveTest do
  @moduledoc """
  Hits the real API. Run with `WEHEAT_LIVE=1 mix test --only live` and WEHEAT_REFRESH_TOKEN set;
  WEHEAT_CLIENT_ID defaults to the public community client. Uses 2 of the 34 hourly requests; stop
  any collector first.
  """
  use ExUnit.Case

  alias Weheat.Auth.TokenSource
  alias Weheat.DTO

  @moduletag :live

  test "me and heat_pumps" do
    {:ok, src} =
      TokenSource.start_link(
        client_id: System.get_env("WEHEAT_CLIENT_ID", Weheat.Auth.community_client_id()),
        client_secret: System.get_env("WEHEAT_CLIENT_SECRET"),
        refresh_token: System.fetch_env!("WEHEAT_REFRESH_TOKEN")
      )

    client = Weheat.new(token: src)
    assert {:ok, %DTO.ReadUserMeDto{}} = Weheat.me(client)

    assert {:ok, %DTO.ReadAllHeatPumpDtoPagedResponse{data: pumps}} =
             Weheat.heat_pumps(client)

    IO.puts("#{length(pumps)} heat pumps")
  end
end
