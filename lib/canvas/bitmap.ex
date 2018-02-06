defmodule Vizi.Canvas.Bitmap do
  alias Vizi.NIF

  @type t :: <<>>

  defdelegate new(ctx, width, height), to: NIF, as: :bitmap_new

  defdelegate from_file(ctx, file_path), to: NIF, as: :bitmap_from_file

  defdelegate from_binary(ctx, bin, width, height), to: NIF, as: :bitmap_from_binary

  def to_binary(bm), do: NIF.bitmap_get_slice(bm, 0, 0)

  defdelegate size(bm), to: NIF, as: :bitmap_size

  defdelegate get_slice(bm, offset \\ 0, length \\ 0), to: NIF, as: :bitmap_get_slice

  defdelegate put_slice(bm, offset \\ 0, bin), to: NIF, as: :bitmap_put_slice

  def update_slice(bm, offset \\ 0, length \\ 0, fun) when is_function(fun, 1) do
    bin = NIF.bitmap_get_slice(bm, offset, length)
    NIF.bitmap_put_slice(bm, offset, fun.(bin))
  end
end
