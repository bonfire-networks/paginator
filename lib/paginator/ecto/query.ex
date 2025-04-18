defmodule Paginator.Ecto.Query do
  @moduledoc false

  import Ecto.Query
  import Untangle
  alias Paginator.Config

  def paginate(queryable, config \\ [])

  def paginate(queryable, %Config{} = config) do
    # info(config, "config")

    queryable
    |> maybe_where(config)
    |> limit(^query_limit(config))
  end

  def paginate(queryable, opts) do
    config = Config.new(opts)
    paginate(queryable, config)
  end

  defp get_operator(:asc, :before), do: :lt
  defp get_operator(:desc, :before), do: :gt
  defp get_operator(:asc, :after), do: :gt
  defp get_operator(:desc, :after), do: :lt

  defp get_operator(direction, _),
    do: raise("Invalid sorting value :#{direction}, please use either :asc or :desc")

  defp get_operator_for_field(cursor_fields, key, direction) do
    {_, order} =
      cursor_fields
      |> Enum.find(fn {field_key, _order} ->
        field_key == key
      end)

    get_operator(order, direction)
  end

  # This clause is responsible for transforming legacy list cursors into map cursors
  defp filter_values(query, fields, values, cursor_direction) when is_list(values) do
    new_values =
      fields
      |> Keyword.keys()
      |> Enum.zip(values)
      |> Map.new()

    filter_values(query, fields, new_values, cursor_direction)
  end

  defp filter_values(query, fields, values, cursor_direction) when is_map(values) do
    sorts =
      fields
      |> Enum.map(fn {column, _order} -> {column, Map.get(values, column)} end)
      |> Enum.reject(fn val -> match?({_column, nil}, val) end)
      |> debug("sorts")

    dynamic_sorts =
      sorts
      |> Enum.with_index()
      |> Enum.reduce(true, fn {{column_field, value}, i}, dynamic_sorts ->
        
        bound_column = Config.sorted_cursor_field(column_field)

        {position, column} = column_position(query, bound_column)

        dynamic = true

        dynamic =
          case get_operator_for_field(fields, column_field, cursor_direction) do
            :lt ->
              dynamic([{q, position}], (field(q, ^column) < ^value or is_nil(field(q, ^column))) and ^dynamic)

            :gt ->
              dynamic([{q, position}], (field(q, ^column) > ^value or is_nil(field(q, ^column))) and ^dynamic)
          end

        dynamic =
          sorts
          |> Enum.take(i)
          |> Enum.reduce(dynamic, fn {prev_column, prev_value}, dynamic ->
            prev_bound_column = Config.sorted_cursor_field(prev_column)
            {position, prev_column} = column_position(query, prev_bound_column)
            dynamic([{q, position}], field(q, ^prev_column) == ^prev_value and ^dynamic)
          end)

        if i == 0 do
          dynamic([{q, position}], ^dynamic and ^dynamic_sorts)
        else
          dynamic([{q, position}], ^dynamic or ^dynamic_sorts)
        end
      end)

    where(query, [{q, 0}], ^dynamic_sorts)
  end

  defp maybe_where(query, %Config{
         after: nil,
         before: nil
       }) do
    query
  end

  defp maybe_where(query, %Config{
         after_values: after_values,
         before: nil,
         cursor_fields: cursor_fields
       }) do
    query
    |> filter_values(cursor_fields, after_values, :after)
  end

  defp maybe_where(query, %Config{
         after: nil,
         before_values: before_values,
         cursor_fields: cursor_fields
       }) do
    query
    |> filter_values(cursor_fields, before_values, :before)
    |> Ecto.Query.reverse_order()
  end

  defp maybe_where(query, %Config{
         after_values: after_values,
         before_values: before_values,
         cursor_fields: cursor_fields
       }) do
    query
    |> filter_values(cursor_fields, after_values, :after)
    |> filter_values(cursor_fields, before_values, :before)
  end

  # Lookup position of binding in query aliases
  defp column_position(query, {binding_name, column}) do
    case Map.fetch(query.aliases, binding_name) do
      {:ok, position} ->
        {position, column}

      _ ->
      warn(query)
        raise(
          ArgumentError,
          "Could not find binding `#{binding_name}` in query aliases: #{inspect(query.aliases)}"
        )
    end
  end

  # Without named binding we assume position of binding is 0
  defp column_position(_query, column), do: {0, column}

  #  In order to return the correct pagination cursors, we need to fetch one more
  # # record than we actually want to return.
  defp query_limit(%Config{limit: limit}) do
    limit + 1
  end

  # This code was based on https://github.com/elixir-ecto/ecto/blob/v2.1.4/lib/ecto/query.ex#L1212-L1226
  # defp reverse_order_bys(query) do
  #   update_in(query.order_bys, fn
  #     [] ->
  #       []

  #     order_bys ->
  #       for %{expr: expr} = order_by <- order_bys do
  #         %{
  #           order_by
  #           | expr:
  #               Enum.map(expr, fn
  #                 {:desc, ast} -> {:asc, ast}
  #                 {:asc, ast} -> {:desc, ast}
  #                 {:desc_nulls_first, ast} -> {:asc_nulls_last, ast}
  #                 {:desc_nulls_last, ast} -> {:asc_nulls_first, ast}
  #                 {:asc_nulls_first, ast} -> {:desc_nulls_last, ast}
  #                 {:asc_nulls_last, ast} -> {:desc_nulls_first, ast}
  #                 other -> error(other, "Could not paginate because the system could not recognise the query order")
  #                 raise "Could not paginate because the system could not recognise the query order"
  #               end)
  #         }
  #       end
  #   end)
  # end
end
