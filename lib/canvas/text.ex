defmodule Vizi.Canvas.Text do
  @moduledoc """
  Vizi allows you to load .ttf files and use the font to render text.

  Font measure functions return values in local space, the calculations are
  carried in the same resolution as the final rendering. This is done because
  the text glyph positions are snapped to the nearest pixels sharp rendering.

  The local space means that values are not rotated or scale as per the current
  transformation. For example if you set font size to 12, which would mean that
  line height is 16, then regardless of the current scaling and rotation, the
  returned line height is always 16. Some measures may vary because of the scaling
  since aforementioned pixel snapping.

  While this may sound a little odd, the setup allows you to always render the
  same way regardless of scaling. I.e. following works regardless of scaling:

    use Vizi.Canvas

    {_, {xmin, ymin, xmax, ymax}} = Text.bounds(ctx, 0, 0, "Text me up.")

    ctx
    |> begin_path()
    |> rect(xmin, ymin, xmax - xmin, ymax - ymin)
    |> fill()


  Note: currently only solid color fill is supported for text.
  """

  @type font :: <<>>

  alias Vizi.NIF

  @doc """
  Creates font by loading it from the disk from specified file name.
  Returns handle to the font.
  """
  def create_font(ctx, file_path) do
    NIF.create_font(ctx, file_path)
    NIF.get_reply()
  end

  @doc """
  Finds a loaded font of specified file_path and returns handle to it, or `nil` if the font is not found.
  """
  def find_font(ctx, file_path) do
    NIF.find_font(ctx, file_path)
    NIF.get_reply()
  end

  @doc """
  Adds a fallback font.
  """
  defdelegate add_fallback_font(ctx, base, fallback), to: NIF

  @doc """
  Measures the specified text string. The bounds value are returned as `{xmin, ymin, xmax, ymax}`.
  Also returns the horizontal advance of the measured text (i.e. where the next character should drawn).
  Measured values are returned in local coordinate space.
  """
  def bounds(ctx, x, y, string) do
    NIF.text_bounds(ctx, x, y, string)
    NIF.get_reply()
  end

  @doc """
  Measures the specified multi-text string. The bounds value are returned as `{xmin, ymin, xmax, ymax}`.
  Measured values are returned in local coordinate space.
  """
  def box_bounds(ctx, x, y, break_row_width, string) do
    NIF.text_box_bounds(ctx, x, y, break_row_width, string)
    NIF.get_reply()
  end

  @doc """
  Calculates the glyph x positions of the specified text.
  Measured values are returned in local coordinate space.
  """
  def glyph_positions(ctx, x, y, string) do
    NIF.text_glyph_positions(ctx, x, y, string)
    NIF.get_reply()
  end

  @doc """
  Returns the vertical metrics based on the current text style.
  Measured values are returned in local coordinate space.
  """
  def metrics(ctx) do
    NIF.text_metrics(ctx)
    NIF.get_reply()
  end

  @doc """
  Breaks the specified text into lines.
  White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
  Words longer than the max width are slit at nearest character (i.e. no hyphenation).
  """
  def break_lines(ctx, break_row_width, string) do
    NIF.text_break_lines(ctx, break_row_width, string)
    NIF.get_reply()
  end
end
