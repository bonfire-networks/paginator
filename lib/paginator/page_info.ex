defmodule Paginator.PageInfo do
  @moduledoc """
  Defines page page_info.

  ## Fields

  * `start_cursor` - an opaque cursor representing the first row of the current page, to be used with the `before` query parameter.
  * `end_cursor` - an opaque cursor representing the last row of the current page, to be used with the `after` query parameter.
  * `limit` - the maximum number of edges that can be contained in this page.
  * `total_count` - the total number of edges matching the query.
  * `total_count_cap_exceeded` - a boolean indicating whether the `:total_count_limit`
  was exceeded.
  """

  @type opaque_cursor :: String.t()

  @type t :: %__MODULE__{
          start_cursor: opaque_cursor() | nil,
          end_cursor: opaque_cursor() | nil,
          limit: integer(),
          total_count: integer() | nil,
          total_count_cap_exceeded: boolean() | nil
        }

  defstruct [:start_cursor, :end_cursor, :limit, :total_count, :total_count_cap_exceeded]
end
