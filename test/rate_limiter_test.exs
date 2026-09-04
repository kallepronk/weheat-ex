defmodule Weheat.RateLimiterTest do
  use ExUnit.Case, async: true

  test "acquire allows limit then asks to wait" do
    {:ok, pid} = Weheat.RateLimiter.start_link(name: nil, limit: 2, window_ms: 10_000)
    assert :ok = Weheat.RateLimiter.acquire(pid)
    assert :ok = Weheat.RateLimiter.acquire(pid)
    assert {:wait, ms} = Weheat.RateLimiter.acquire(pid)
    assert ms > 9_000 and ms <= 10_000
  end

  test "wait blocks until the window frees a slot" do
    {:ok, pid} = Weheat.RateLimiter.start_link(name: nil, limit: 1, window_ms: 50)
    :ok = Weheat.RateLimiter.wait(pid)
    {elapsed_us, :ok} = :timer.tc(fn -> Weheat.RateLimiter.wait(pid) end)
    assert elapsed_us >= 40_000
  end
end
