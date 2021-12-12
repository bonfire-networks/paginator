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
