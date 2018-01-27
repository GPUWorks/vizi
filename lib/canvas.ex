defmodule Vizi.Canvas do
  @moduledoc """
  Provides various drawing and styling functions that can only be used within a
  `draw/4` callback function.

  ## Paths

  Drawing a new shape starts with `begin_path/1`, it clears all the currently defined paths.
  Then you define one or more paths and sub-paths which describe the shape. There are functions
  to draw common shapes like rectangles and circles, and lower level step-by-step functions,
  which allow to define a path curve by curve.

  Vizi uses even-odd fill rule to draw the shapes. Solid shapes should have counter clockwise
  winding and holes should have counter clockwise order. To specify winding of a path you can
  call `path_winding/2`. This is useful especially for the common shapes, which are drawn CCW.

  The curve segments and sub-paths are transformed by the current transform.

  You can fill the path using current fill style by calling `fill/1`, and stroke it
  with current stroke style by calling `stroke/1`.

  ## Styling

  Fill and stroke render style can be either a solid color or a paint which is a gradient or a pattern.
  Solid color is simply defined as a color value, different kinds of paints can be created
  using functions from the `Vizi.Canvas.Paint` module.

  Common text and font settings such as
  font size, letter spacing and text align are supported. Font blur allows you
  to create simple text effects such as drop shadows.

  ## Transformations

  The paths, gradients, patterns and scissor region are transformed by an transformation
  matrix at the time when they are passed to the API.

  The current transformation matrix is a affine matrix:

    [sx kx tx]
    [ky sy ty]
    [ 0  0  1]

  Where: sx,sy define scaling, kx,ky skewing, and tx,ty translation.
  The last row is assumed to be 0,0,1 and is not stored.

  ## Scissoring

  Scissoring allows you to clip the rendering into a rectangle. This is useful for various
  user interface cases like rendering a text edit or a timeline.

  ## Compositing

  The composite operations in Vizi are modeled after HTML Canvas API, and
  the blend func is based on OpenGL (see corresponding manuals for more info).
  The colors in the blending state have premultiplied alpha.
  """

  alias Vizi.NIF

  @doc """
  Calling `use Vizi.Canvas` is equal to

      import Vizi.Canvasa
      alias Vizi.Canvas.{Bitmap, Color, Image, Paint, Text, Transform}
  """
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
      alias unquote(__MODULE__).{Bitmap, Color, Image, Paint, Text, Transform}
    end
  end

  @doc """
  Clears the current path and sub-paths.
  """
  @spec begin_path(ctx :: Vizi.View.context) :: Vizi.View.context
  defdelegate begin_path(ctx), to: NIF

  @doc """
  Clears the current path and sub-paths.
  """
  @spec move_to(ctx :: Vizi.View.context, x :: number, y :: number) :: Vizi.View.context
  defdelegate move_to(ctx, x, y), to: NIF

  @doc """
  Adds line segment from the last point in the path to the specified point.
  """
  @spec line_to(ctx :: Vizi.View.context, x :: number, y :: number) :: Vizi.View.context
  defdelegate line_to(ctx, x, y), to: NIF

  @doc """
  Adds cubic bezier segment from last point in the path via two control points to the specified point.
  """
  @spec bezier_to(ctx :: Vizi.View.context, cx1 :: number, cy1 :: number, cx2 :: number, cy2 :: number, x :: number, y :: number) :: Vizi.View.context
  defdelegate bezier_to(ctx, cx1, cy1, cx2, cy2, x, y), to: NIF

  @doc """
  Adds quadratic bezier segment from last point in the path via a control point to the specified point.
  """
  @spec quad_to(ctx :: Vizi.View.context, cx :: number, cy :: number, x :: number, y :: number) :: Vizi.View.context
  defdelegate quad_to(ctx, cx, cy, x, y), to: NIF

  @doc """
  Adds an arc segment at the corner defined by the last path point, and two specified points.
  """
  @spec arc_to(ctx :: Vizi.View.context, x1 :: number, y1 :: number, x2 :: number, y2 :: number, radius :: number) :: Vizi.View.context
  defdelegate arc_to(ctx, x1, y1, x2, y2, radius), to: NIF

  @doc """
  Closes current sub-path with a line segment.
  """
  defdelegate close_path(ctx), to: NIF

  @doc """
  Sets the current sub-path winding. Direction can be
  `:ccw` for counter clockwise path winding and
  `:cw` for clockwise path winding.
  """
  defdelegate path_winding(ctx, direction), to: NIF

  @doc """
  Creates new circle arc shaped sub-path. The arc center is at cx,cy, the arc radius is radius,
  and the arc is drawn from angle angle1 to angle2, and swept in direction `:ccw`, or `:cw`.
  Angles are specified in radians.
  """
  defdelegate arc(ctx, cx, cy, radius, angle1, angle2, direction), to: NIF

  @doc """
  Creates new rectangle shaped sub-path.
  """
  @spec rect(ctx :: Vizi.View.context, x :: number, y :: number, height :: number, width :: number) :: Vizi.View.context
  defdelegate rect(ctx, x, y, width, height), to: NIF

  @doc """
  Creates new rounded rectangle shaped sub-path.
  """
  defdelegate rounded_rect(ctx, x, y, width, height, radius), to: NIF

  @doc """
  Creates new rounded rectangle shaped sub-path with varying radii for each corner.
  """
  defdelegate rounded_rect_varying(ctx, x, y, width, height, rad_top_left, rad_top_right, rad_bot_right, rad_bot_left), to: NIF

  @doc """
  Creates new ellipse shaped sub-path.
  """
  defdelegate ellipse(ctx, x, y, radius_x, radius_y), to: NIF

  @doc """
  Creates new circle shaped sub-path.
  """
  defdelegate circle(ctx, x, y, radius), to: NIF

  @doc """
  Fills the current path with current fill style.
  """
  defdelegate fill(ctx), to: NIF

  @doc """
  Fills the current path with current stroke style.
  """
  defdelegate stroke(ctx), to: NIF

  @doc """
  Draws text string at specified location.
  """
  def text(ctx, x, y, string) do
    NIF.text(ctx, x, y, string)
    NIF.get_reply
  end

  @doc """
  Draws multi-line text string at specified location wrapped at the specified width.
  White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
  Words longer than the max width are slit at nearest character (i.e. no hyphenation).
  """
  defdelegate text_box(ctx, x, y, break_row_width, string), to: NIF

  @doc """
  Resets current transform to a identity matrix.
  """
  defdelegate reset_transform(ctx), to: NIF

  @doc """
  Premultiplies current coordinate system by specified matrix.
  """
  defdelegate transform(ctx, xform), to: NIF

  @doc """
  Translates current coordinate system.
  """
  defdelegate translate(ctx, x, y), to: NIF

  @doc """
  Rotates current coordinate system. Angle is specified in radians.
  """
  defdelegate rotate(ctx, angle), to: NIF

  @doc """
  Skews the current coordinate system along X axis. Angle is specified in radians.
  """
  defdelegate skew_x(ctx, angle), to: NIF

  @doc """
  Skews the current coordinate system along Y axis. Angle is specified in radians.
  """
  defdelegate skew_y(ctx, angle), to: NIF

  @doc """
  Scales the current coordinate system.
  """
  defdelegate scale(ctx, x, y), to: NIF

  @doc """
  Returns the current transformation matrix.
  """
  def current_transform(ctx) do
    NIF.current_transform(ctx)
    NIF.get_reply
  end

  @doc """
  Sets the current scissor rectangle.
  The scissor rectangle is transformed by the current transform.
  """
  defdelegate scissor(ctx, x, y, w, h), to: NIF

  @doc """
  Intersects current scissor rectangle with the specified rectangle.
  The scissor rectangle is transformed by the current transform.
  Note: in case the rotation of previous scissor rect differs from
  the current one, the intersection will be done between the specified
  rectangle and the previous scissor rectangle transformed in the current
  transform space. The resulting shape is always rectangle.
  """
  defdelegate intersect_scissor(ctx, x, y, w, h), to: NIF

  @doc """
  Reset and disables scissoring.
  """
  defdelegate reset_scissor(ctx), to: NIF

  @doc """
  Convenience function that returns a color struct from red, green, blue and alpha values.
  Expects values between 0 and 255.
  """
  def rgba(r, g, b, a \\ 255) do
    %Vizi.Canvas.Color{
      r: r / 255.0,
      g: g / 255.0,
      b: b / 255.0,
      a: a / 255.0
    }
  end

  @doc """
  Converts degree to rad.
  """
  defdelegate deg_to_rad(deg), to: NIF

  @doc """
  Converts rad to degree.
  """
  defdelegate rad_to_deg(rad), to: NIF

  @doc """
  Sets whether to draw antialias for `stroke/1` and `fill/1`.
  It's enabled by default.
  """
  defdelegate shape_anti_alias(ctx, enable), to: NIF

  @doc """
  Sets current stroke style to a solid color.
  """
  defdelegate stroke_color(ctx, color), to: NIF

  @doc """
  Sets current stroke style to a paint, which can be a one of the gradients or a pattern.
  """
  defdelegate stroke_paint(ctx, paint), to: NIF

  @doc """
  Sets current fill style to a solid color.
  """
  defdelegate fill_color(ctx, color), to: NIF

  @doc """
  Sets current fill style to a paint, which can be a one of the gradients or a pattern.
  """
  defdelegate fill_paint(ctx, paint), to: NIF

  @doc """
  Sets current fill style to an image pattern. Parameters (ox,oy) specify the left-top location of the image pattern,
  (ex,ey) the size of one image, angle rotation around the top-left corner and image is a handle to the image to render.
  """
  defdelegate draw_image(ctx, x, y, width, height, image, alpha \\ 1.0), to: NIF


  @doc """
  Sets the miter limit of the stroke style.
  Miter limit controls when a sharp corner is beveled.
  """
  defdelegate miter_limit(ctx, limit), to: NIF

  @doc """
  Sets the stroke width of the stroke style.
  """
  defdelegate stroke_width(ctx, width), to: NIF

  @doc """
  Sets how the end of the line (cap) is drawn.
  Can be one of: `:butt` (default), `:round`, or `:square`.
  """
  defdelegate line_cap(ctx, cap), to: NIF

  @doc """
  Sets how sharp path corners are drawn.
  Can be one of `:miter` (default), `:round`, or `:bevel`.
  """
  defdelegate line_join(ctx, join), to: NIF

  @doc """
  Sets the font face of the current text style.
  """
  defdelegate font_face(ctx, font), to: NIF

  @doc """
  Sets the font size of the current text style.
  """
  defdelegate font_size(ctx, size), to: NIF

  @doc """
  Sets the blur of the current text style.
  """
  defdelegate font_blur(ctx, blur), to: NIF

  @doc """
  Sets the letter spacing of the current text style.
  """
  defdelegate letter_spacing(ctx, spacing), to: NIF, as: :text_letter_spacing

  @doc """
  Sets the proportional line height of current text style. The line height is specified as multiple of font size.
  """
  defdelegate line_height(ctx, line_height), to: NIF, as: :text_line_height

  @doc """
  Sets the text align of current text style.
  Can be one of `:left`, `:center`, or `:right` for horizontal alignment and
  one of `:top`, `:middle`, `:bottom`, or `:baseline` for vertical alignment.
  """
  def text_align(ctx, align) do
    NIF.text_align(ctx, List.wrap(align))
  end

  @doc """
  Sets the composite operation. The op parameter should be one of:
  `:source_over`, `:source_in`, `:source_out`, `:atop`, `:destination_over`,
  `:destination_in`, `:destination_out`, `:destinations_atop`, `:lighter`, `:copy`, or `:xor`.

  The default is `:source_over`.
  """
  defdelegate global_composite_operation(ctx, op), to: NIF

  @doc """
  Sets the composite operation with custom pixel arithmetic. `src_factor` and `dst_factor` should be one of:
  `:zero`, `:one`, `:src_color`, `:one_minus_src_color`, `:dst_color`, `:one_minus_dst_color`,
  `:src_alpha`, `:one_minus_src_alpha`, `:dst_alpha`, `:one_minus_dst_alpha`, or `:src_alpha_saturate`.
  """
  defdelegate global_composite_blend_func(ctx, src_factor, dst_factor), to: NIF

  @doc """
  Sets the composite operation with custom pixel arithmetic for RGB and alpha components separately. Accepts the same options as `global_composite_blend_func/3`.
  """
  defdelegate global_composite_blend_func_separate(ctx, src_rgb, dst_rgba, src_alpha, dst_alpha), to: NIF

  @doc """
  Sets the transparency applied to all rendered shapes.
  Already transparent paths will get proportionally more transparent as well.
  """
  defdelegate global_alpha(ctx, a), to: NIF
end