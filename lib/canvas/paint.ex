defmodule Vizi.Canvas.Paint do
  @moduledoc """
  Vizi supports four types of paints: linear gradient, box gradient, radial gradient and image pattern.
  These can be used as paints for strokes and fills.
  """

  alias Vizi.NIF

  @type t :: <<>>

  @doc """
  Creates and returns a linear gradient. Parameters (sx,sy)-(ex,ey) specify the start and end coordinates
  of the linear gradient, icol specifies the start color and ocol the end color.
  The gradient is transformed by the current transform when it is passed to
  `Vizi.Canvas.Style.fill_paint/2` or `Vizi.Canvas.Style.stroke_paint/2`.
  """
  defdelegate linear_gradient(ctx, sx, sy, ex, ey, icol, ocol), to: NIF

  @doc """
  Creates and returns a box gradient. Box gradient is a feathered rounded rectangle, it is useful for rendering
  drop shadows or highlights for boxes. Parameters (x,y) define the top-left corner of the rectangle,
  (w,h) define the size of the rectangle, r defines the corner radius, and f feather. Feather defines how blurry
  the border of the rectangle is. Parameter icol specifies the inner color and ocol the outer color of the gradient.
  The gradient is transformed by the current transform when it is passed to
  `Vizi.Canvas.Style.fill_paint/2` or `Vizi.Canvas.Style.stroke_paint/2`.
  """
  defdelegate box_gradient(ctx, x, y, w, h, r, f, icol, ocol), to: NIF

  @doc """
  Creates and returns a radial gradient. Parameters (cx,cy) specify the center, inr and outr specify
  the inner and outer radius of the gradient, icol specifies the start color and ocol the end color.
  The gradient is transformed by the current transform when it is passed to
  `Vizi.Canvas.Style.fill_paint/2` or `Vizi.Canvas.Style.stroke_paint/2`.
  """
  defdelegate radial_gradient(ctx, cx, cy, inr, outr, icol, ocol), to: NIF

  @doc """
  Creates and returns an image pattern. Parameters (ox,oy) specify the left-top location of the image pattern,
  (ex,ey) the size of one image, angle rotation around the top-left corner and image is a handle to the image to render.
  The gradient is transformed by the current transform when it is passed to
  `Vizi.Canvas.Style.fill_paint/2` or `Vizi.Canvas.Style.stroke_paint/2`.
  """
  defdelegate image_pattern(ctx, ox, oy, ex, ey, angle, image, alpha \\ 1.0), to: NIF
end