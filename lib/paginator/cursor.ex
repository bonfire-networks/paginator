defmodule Paginator.Cursor do
  @moduledoc false
  import Untangle

  def maybe_encode([id: id] = attrs) do # workaround to use the ID as the cursor if that's the only cursor_field
    if is_id?(id) do
      debug(id, "Paginator maybe_encode: just use the ID")

      id
    else
      encode(attrs)
    end
  end

  def maybe_encode(cursor_fields_values) when is_map(cursor_fields_values) do
    cursor_fields_values
    |> Map.to_list()
    |> maybe_encode()
  end

  def maybe_encode(cursor_fields_values) do
    cursor_fields_values
    |> encode()
  end

  def encode(values) when is_map(values) do
    debug(values, "Paginator maybe_encode: encode the cursor")

    values
    |> :erlang.term_to_binary()
    |> Base.url_encode64()
  end

  def encode(values) do
    values
    |> Map.new()
    |> encode()
  end

  def maybe_decode(nil), do: nil
  def maybe_decode(cursor) do # workaround to use the ID as the cursor if that's the only cursor_field
    if is_id?(cursor) do
      debug(cursor, "Paginator maybe_decode: cursor provided is an ID")
      %{id: cursor}
    else
      decode(cursor)
    end
  end

  def decode(nil), do: nil
  def decode(encoded_cursor) do
    debug(encoded_cursor, "Paginator maybe_decode: decode provided cursor")

    encoded_cursor
    |> Base.url_decode64!()
    |> Plug.Crypto.non_executable_binary_to_term([:safe])
    |> debug("cursor decoded")
  end


  def is_id?(str) when is_binary(str) do
    if Code.ensure_loaded?(Needle.UID) do
      Needle.UID.valid?(str)
    else
      byte_size(str)==26 # not great but let's assume based on ULID string length
    end
  end
  def is_id?(_), do: false

end
