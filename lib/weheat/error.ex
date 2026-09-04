defmodule Weheat.Error do
  @moduledoc "Non-2xx response from the WeHeat API."
  defexception [:status, :body]

  @type t :: %__MODULE__{status: pos_integer(), body: term()}

  @impl true
  def message(%{status: status, body: body}), do: "weheat: HTTP #{status}: #{inspect(body)}"
end
