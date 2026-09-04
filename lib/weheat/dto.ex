defmodule Weheat.DTO do
  @moduledoc """
  Shared plumbing for the generated DTO structs in `Weheat.DTO.*`.

  Each DTO declares `fields: [snake_name: {"jsonName", type}]`; `from_map/1` maps the API's
  camelCase JSON onto the struct and parses timestamps. Unknown JSON keys are dropped.
  """

  @scalars [:string, :integer, :float, :boolean]

  defmacro __using__(opts) do
    fields = Keyword.fetch!(opts, :fields)

    quote do
      @fields unquote(fields)
      defstruct Keyword.keys(@fields)
      @type t :: %__MODULE__{}

      @doc "Builds the struct from a decoded JSON map."
      @spec from_map(map()) :: t()
      def from_map(map) when is_map(map), do: Weheat.DTO.cast(__MODULE__, @fields, map)
    end
  end

  @doc false
  def cast(module, fields, map) do
    struct(
      module,
      for({key, {json_key, type}} <- fields, do: {key, cast_value(type, Map.get(map, json_key))})
    )
  end

  defp cast_value(_type, nil), do: nil
  defp cast_value(type, value) when type in @scalars, do: value

  defp cast_value({:list, type}, list) when is_list(list),
    do: Enum.map(list, &cast_value(type, &1))

  defp cast_value(:datetime, value) when is_binary(value), do: parse_datetime(value)

  defp cast_value(module, value) when is_atom(module) and is_map(value),
    do: module.from_map(value)

  defp cast_value(_type, value), do: value

  # The backend emits ISO 8601, sometimes without a zone. Zone-less means UTC per the API docs.
  defp parse_datetime(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} ->
        dt

      {:error, _} ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, naive} -> DateTime.from_naive!(naive, "Etc/UTC")
          {:error, _} -> value
        end
    end
  end
end
