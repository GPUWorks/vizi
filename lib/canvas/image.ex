defmodule Vizi.Canvas.Image do
  @moduledoc """
  Vizi allows you to load jpg, png, psd, tga, pic and gif files to be used for rendering.
  In addition you can upload your own image.
  The flags argument can be one or more of the following options:

    * `:generate_mipmaps` Generate mipmaps during creation of the image.
    * `:repeat_x` Repeat image in X direction.
    * `:repeat_y` Repeat image in Y direction.
    * `:flip_y` Flips (inverses) image in Y direction when rendered.
    * `:premultiplied` Image data has premultiplied alpha.
    * `:nearest` Image interpolation is Nearest instead Linear

  """

  alias Vizi.NIF

  @type t :: <<>>

  @doc """
  Creates image by loading it from the disk from specified file name.
  Returns handle to the image.
  """
  def from_file(ctx, file_path, flags \\ []) do
    NIF.image_from_file(ctx, file_path, flags)
    NIF.get_reply()
  end

  @doc """
  Creates image from specified image data.
  Returns handle to the image.
  """
  def from_binary(ctx, data, w, h, flags \\ []) do
    NIF.image_from_binary(ctx, data, w, h, flags)
    NIF.get_reply()
  end

  @doc """
  Loads a file from disk and returns it as a binary.
  """
  defdelegate file_to_binary(file_path), to: NIF, as: :image_file_to_binary

  @doc """
  Updates image data specified by image handle.
  """
  defdelegate update_from_binary(ctx, image, data), to: NIF, as: :image_update_from_binary

  @doc """
  Returns the dimensions of a created image int the form `{width, height}`.
  """
  def size(ctx, image) do
    NIF.image_size(ctx, image)
    NIF.get_reply()
  end

  @doc """
  Deletes a created image.
  """
  defdelegate delete(ctx, image), to: NIF, as: :image_delete
end
