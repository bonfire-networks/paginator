defmodule Paginator.Config do
  @moduledoc false

  alias Paginator.Cursor
  import Untangle

  @type t :: %__MODULE__{}

  defstruct [
    :after,
    :after_values,
    :before,
    :before_values,
    :cursor_fields,
    :fetch_cursor_value_fun,
    :include_total_count,
    :total_count_primary_key_field,
    :limit,
    :maximum_limit,
    :total_count_limit,
    :infinite_pages
  ]

  @default_total_count_primary_key_field :id
  @default_limit 50
  @minimum_limit 1
  @maximum_limit 500
  @default_total_count_limit 10_000
  @order_directions [:asc, :desc]

  def new(opts \\ []) do
    %__MODULE__{
      after: opts[:after],
      after_values: Cursor.maybe_decode(opts[:after]),
      before: opts[:before],
      before_values: Cursor.maybe_decode(opts[:before]),
      cursor_fields: opts[:cursor_fields],
      fetch_cursor_value_fun:
        opts[:fetch_cursor_value_fun] || (&Paginator.default_fetch_cursor_value/2),
      include_total_count: opts[:include_total_count] || false,
      total_count_primary_key_field:
        opts[:total_count_primary_key_field] || @default_total_count_primary_key_field,
      limit: limit(opts),
      total_count_limit: opts[:total_count_limit] || @default_total_count_limit,
      infinite_pages: opts[:infinite_pages] || false
    }
  end

  def validate!(%__MODULE__{} = config) do
    cursor_fields = config.cursor_fields

    unless cursor_fields do
      raise(ArgumentError, "expected `:cursor_fields` to be set")
    end

    if !cursor_values_match_cursor_fields?(config.after_values, cursor_fields) do
      warn(config.after_values, "after_values")
      warn(cursor_fields, "cursor_fields")
      raise(ArgumentError, message: "expected `:after` cursor to match `:cursor_fields`")
    end

    if !cursor_values_match_cursor_fields?(config.before_values, cursor_fields) do
      warn(config.before_values, "before_values")
      warn(cursor_fields, "cursor_fields")
      raise(ArgumentError, message: "expected `:before` cursor to match `:cursor_fields`")
    end
  end

  defp cursor_values_match_cursor_fields?(nil = _cursor_values, _cursor_fields), do: true

  defp cursor_values_match_cursor_fields?(cursor_values, _cursor_fields)
       when is_list(cursor_values) do
    # Legacy cursors are valid by default
    true
  end

  defp cursor_values_match_cursor_fields?(cursor_values, cursor_fields) do
    cursor_keys = cursor_values |> Map.keys() |> sorted_cursor_fields() # |> Enum.sort()

    match?(^cursor_keys, sorted_cursor_fields_with_direction(cursor_fields))
  end

  def sorted_cursor_fields_with_direction(cursor_fields) do
      cursor_fields
      |> Enum.map(fn
        {field, value} when value in @order_directions ->
          sorted_cursor_field(field)

        field when is_atom(field) ->
          field

      end)
      |> Enum.sort()
  end

  def sorted_cursor_fields(cursor_fields) do
      cursor_fields
      |> Enum.map(&sorted_cursor_field/1)
      |> Enum.sort()
  end
  def sorted_cursor_field(cursor_field) do
      case cursor_field do

        {schema, field}
        when is_atom(schema) and is_atom(field) ->
          {schema, field}

      {_schema, assoc, field}
        when is_atom(assoc) and is_atom(field)  ->
          {assoc, field}

        {_schema, _assoc, assoc2, field}
        when is_atom(assoc2) and is_atom(field)  ->
          {assoc2, field}

        field when is_atom(field) ->
          field

      end
  end

  def limit(opts) do
    max(ensure_int(opts[:limit]) || @default_limit, @minimum_limit)
    |> min(opts[:maximum_limit] || @maximum_limit)
  end

  defp ensure_int(num) when is_integer(num), do: num
  defp ensure_int(num) when is_binary(num), do: String.to_integer(num)
  defp ensure_int(_), do: @default_limit

end
