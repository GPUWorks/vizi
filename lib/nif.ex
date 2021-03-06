defmodule Vizi.NIF do
  @moduledoc false

  @on_load :init

  def init do
    :vizi
    |> Application.app_dir("priv")
    |> Path.join("vz_nif")
    |> String.to_charlist()
    |> :erlang.load_nif(0)
  end

  def create_view(_opts), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def shutdown(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def suspend(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def resume(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def ready(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def redraw(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def get_frame_rate(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def force_send_events(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def setup_node(_node, _parent_xform, _ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def global_composite_operation(_ctx, _operation), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def global_composite_blend_func(_ctx, _sfactor, _dfactor),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def global_composite_blend_func_separate(_ctx, _src_rgb, _dst_rgb, _src_alpha, _dst_alpha),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def lerp_rgba(_c1, _c2, _u), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def hsla(_h, _s, _l, _a), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def save(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def restore(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def reset(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def shape_anti_alias(_ctx, _enable), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def stroke_color(_ctx, _color), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def stroke_paint(_ctx, _paint), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def fill_color(_ctx, _color), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def fill_paint(_ctx, _paint), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def draw_image(_ctx, _x, _y, _width, _height, _image, _opts),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def miter_limit(_ctx, _limit), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def stroke_width(_ctx, _width), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def line_cap(_ctx, _cap), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def line_join(_ctx, _join), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def global_alpha(_ctx, _alpha), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def reset_transform(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform(_ctx, _matrix), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def translate(_ctx, _x, _y), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def rotate(_ctx, _angle), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def skew_x(_ctx, _angle), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def skew_y(_ctx, _angle), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def scale(_ctx, _x, _y), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def current_transform(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_identity(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_translate(_x, _y), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_scale(_x, _y), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_rotate(_angle), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_skew_x(_angle), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_skew_y(_angle), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_multiply(_dst, _src), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_premultiply(_dst, _src), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_inverse(_matrix), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def transform_point(_matrix, _x, _y), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def matrix_to_list(_matrix), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def list_to_matrix(_list), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def deg_to_rad(_deg), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def rad_to_deg(_rad), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def image_file_to_binary(_file_path), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def image_from_file(_ctx, _file_path, _flags), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def image_from_binary(_ctx, _data, _w, _h, _flags),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def image_update_from_binary(_ctx, _image, _data), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def image_size(_ctx, _image), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def image_delete(_ctx, _image), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def linear_gradient(_ctx, _sx, _sy, _ex, _ey, _icol, _ocol),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def box_gradient(_ctx, _x, _y, _w, _h, _r, _f, _icol, _ocol),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def radial_gradient(_ctx, _cx, _cy, _inr, _outr, _icol, _ocol),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def image_pattern(_ctx, _ox, _oy, _ex, _ey, _angle, _image, _alpha),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def scissor(_ctx, _x, _y, _w, _h), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def intersect_scissor(_ctx, _x, _y, _w, _h), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def reset_scissor(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def begin_path(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def move_to(_ctx, _x, _y), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def line_to(_ctx, _x, _y), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def bezier_to(_ctx, _cx1, _cy1, _cx2, _cy2, _x, _y),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def quad_to(_ctx, _cx, _cy, _x, _y), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def arc_to(_ctx, _x1, _y1, _x2, _y2, _radius), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def close_path(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def path_winding(_ctx, _dir), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def arc(_ctx, _cx, _cy, _r, _a0, _a1, _dir), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def rect(_ctx, _x, _y, _w, _h), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def rounded_rect(_ctx, _x, _y, _w, _h, _r), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def rounded_rect_varying(
        _ctx,
        _x,
        _y,
        _w,
        _h,
        _rad_top_left,
        _rad_top_right,
        _rad_bot_right,
        _rad_bot_left
      ),
      do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def ellipse(_ctx, _cx, _cy, _rx, _ry), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def circle(_ctx, _cx, _cy, _r), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def fill(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def stroke(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def create_font(_ctx, _file_path), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def find_font(_ctx, _file_path), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def add_fallback_font(_ctx, _base, _fallback), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def font_size(_ctx, _size), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def font_blur(_ctx, _blur), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text_letter_spacing(_ctx, _spacing), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text_line_height(_ctx, _line_height), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text_align(_ctx, _align), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def font_face(_ctx, _font), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text(_ctx, _x, _y, _string), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text_box(_ctx, _x, _y, _break_row_width, _string),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text_bounds(_ctx, _x, _y, _string), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text_box_bounds(_ctx, _x, _y, _break_row_width, _string),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text_glyph_positions(_ctx, _x, _y, _string), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text_metrics(_ctx), do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def text_break_lines(_ctx, _break_row_width, _string),
    do: :erlang.nif_error(:vz_nif_lib_not_loaded)

  def get_reply do
    receive do
      {:vz_reply, :badarg} ->
        raise ArgumentError

      {:vz_reply, reply} ->
        reply
    end
  end
end
