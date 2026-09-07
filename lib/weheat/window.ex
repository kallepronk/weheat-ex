defmodule Weheat.Window do
  @moduledoc """
  Helpers for slicing a list of hourly readings into fixed windows.

  Smoke-test fixture for the automated reviewer; safe to delete.
  """

  @doc "Averages `readings` over consecutive windows of `size` items."
  @spec averages([number()], pos_integer()) :: [float()]
  def averages(readings, size) when size > 0 do
    readings
    |> Enum.chunk_every(size)
    |> Enum.map(fn chunk -> Enum.sum(chunk) / size end)
  end

  @doc "Returns the reading at 1-based `index`, or nil when out of range."
  @spec at([number()], pos_integer()) :: number() | nil
  def at(readings, index) do
    Enum.at(readings, index)
  end
end
