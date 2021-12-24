defmodule Paginator.Cursor do
  @moduledoc false
  require Logger
  @log_level :debug

  def maybe_encode([id: id] = attrs) do # workaround to use the ID as the cursor if that's the only cursor_field
    if is_id?(id) do
      Logger.log(@log_level, "Paginator maybe_encode: just use the ID: #{id}")

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
    Logger.log(@log_level, "Paginator maybe_encode: encode the cursor #{inspect values}")

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
      Logger.log(@log_level, "Paginator maybe_decode: cursor provided is an ID: #{cursor}")
      %{id: cursor}
    else
      decode(cursor)
    end
  end

  def decode(nil), do: nil
  def decode(encoded_cursor) do
    Logger.log(@log_level, "Paginator maybe_decode: decode provided cursor #{inspect encoded_cursor}")

    encoded_cursor
    |> Base.url_decode64!()
    |> Plug.Crypto.non_executable_binary_to_term([:safe])
  end


  def is_id?(str) when is_binary(str) and byte_size(str)==26 do
    if Code.ensure_loaded?(Pointers.ULID) do
      with :error <- Pointers.ULID.cast(str) do
        false
      else
        _ -> true
      end
    else
      true # not great but let's assume based on string length
    end
  end
  def is_id?(_), do: false

end
