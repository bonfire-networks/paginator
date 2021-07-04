defmodule Paginator.CursorTest do
  use ExUnit.Case, async: true

  alias Paginator.Cursor

  describe "encoding and decoding terms" do
    test "it encodes and decodes map cursors" do
      cursor = Cursor.maybe_encode(%{a: 1, b: 2})

      assert Cursor.maybe_decode(cursor) == %{a: 1, b: 2}
    end
  end

  describe "Cursor.maybe_decode/1" do
    test "it safely decodes user input" do
      assert_raise ArgumentError, fn ->
        # this binary represents the atom :fubar_0a1b2c3d4e
        <<131, 100, 0, 16, "fubar_0a1b2c3d4e">>
        |> Base.url_encode64()
        |> Cursor.maybe_decode()
      end
    end
  end

  @ulid "B10GP0ST0RS0METH1NGS1M11AR"

  describe "handling ULID IDs" do
    test "does not encode" do
      cursor = Cursor.maybe_encode(%{id: @ulid})

      assert cursor == @ulid
      assert Cursor.maybe_decode(cursor) == %{id: @ulid}
    end

  end

end
