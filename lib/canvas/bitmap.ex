defmodule Vizi.Canvas.Bitmap do
  alias Vizi.NIF

  @type t :: <<>>

  defdelegate new(ctx, width, height), to: NIF, as: :bitmap_new

  defdelegate from_file(ctx, file_path, flags \\ []), to: NIF, as: :bitmap_from_file

  defdelegate size(bm), to: NIF, as: :bitmap_size

  defdelegate put(bm, ndx, r, g, b, a), to: NIF, as: :bitmap_put

  defdelegate get_bin(bm, ndx, size), to: NIF, as: :bitmap_put_bin

  def update(bm, offset \\ 0, count \\ nil, fun) do
    count = if is_nil(count), do: size(bm) - offset, else: count

    bin = NIF.bitmap_get_bin(bm, offset, count)
    NIF.bitmap_put_bin(bm, offset, fun.(bin))
  end

  defdelegate put_bin(bm, ndx, rgba), to: NIF, as: :bitmap_put_bin
end
