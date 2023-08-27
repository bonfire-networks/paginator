defmodule Paginator.Page do
  @moduledoc """
  Defines a page.

  ## Fields

  * `edges` - a list of entries contained in this page.
  * `page_info` - meta-data attached to this page.
  """

  @type t :: %__MODULE__{
          edges: [any()] | [],
          page_info: Paginator.PageInfo.t()
        }

  defstruct [:page_info, :edges]
end
defimpl Enumerable, for: Paginator.Page do

  def reduce(%{edges: edges}, acc, fun) do
    Enumerable.reduce(edges, acc, fun)
  end

  def member?(%{edges: edges}, el), do: Enumerable.member?(edges, el)

  def count(page) do
    {:ok, page.page_info.page_count || length(page.edges)}
  end

  # def slice(%{edges: edges}) do
  #   Enumerable.member?(edges)
  # end

end