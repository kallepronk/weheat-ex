defmodule Weheat.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Weheat.RateLimiter,
       name: Weheat.RateLimiter,
       limit: Application.get_env(:weheat, :rate_limit, Weheat.RateLimiter.default_limit()),
       window_ms:
         Application.get_env(:weheat, :rate_window_ms, Weheat.RateLimiter.default_window_ms())}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Weheat.Supervisor)
  end
end
