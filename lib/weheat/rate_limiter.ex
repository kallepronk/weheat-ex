defmodule Weheat.RateLimiter do
  @moduledoc """
  Sliding-window rate limiter. `wait/1` blocks the caller instead of returning an error.

  WeHeat caps third-party access at 34 requests per hour per user, shared between every
  client using that account, so the default of 30/hour leaves headroom.
  """
  use GenServer

  @default_limit 30
  @default_window_ms :timer.hours(1)

  def default_limit, do: @default_limit
  def default_window_ms, do: @default_window_ms

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc "Blocks until a request slot is free, then records the request."
  @spec wait(GenServer.server()) :: :ok
  def wait(server \\ __MODULE__) do
    case acquire(server) do
      :ok ->
        :ok

      {:wait, ms} ->
        Process.sleep(ms)
        wait(server)
    end
  end

  @doc "Records a request if a slot is free, otherwise says how long to wait."
  @spec acquire(GenServer.server()) :: :ok | {:wait, non_neg_integer()}
  def acquire(server \\ __MODULE__), do: GenServer.call(server, :acquire)

  @impl true
  def init(opts) do
    {:ok,
     %{
       limit: Keyword.get(opts, :limit, @default_limit),
       window_ms: Keyword.get(opts, :window_ms, @default_window_ms),
       stamps: []
     }}
  end

  @impl true
  def handle_call(:acquire, _from, state) do
    now = System.monotonic_time(:millisecond)
    stamps = Enum.filter(state.stamps, &(&1 > now - state.window_ms))

    if length(stamps) < state.limit do
      {:reply, :ok, %{state | stamps: stamps ++ [now]}}
    else
      {:reply, {:wait, hd(stamps) + state.window_ms - now}, %{state | stamps: stamps}}
    end
  end
end
