defmodule Vizi.Canvas.Bitmap do
  alias Vizi.NIF

  @type t :: <<>>

  defdelegate create(width, height), to: NIF, as: :create_bitmap
  defdelegate size(bm), to: NIF, as: :bitmap_size
  defdelegate put(bm, ndx, r, g, b, a), to: NIF, as: :bitmap_put
  defdelegate put_bin(bm, ndx, rgba), to: NIF, as: :bitmap_put_bin
end