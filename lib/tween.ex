defmodule Vizi.Tween do
  alias __MODULE__
  defstruct attrs: %{}, params: %{}, length: 0, easing: nil, next: nil

  @type t :: %Tween{
          attrs: attrs,
          params: params,
          length: integer,
          easing: function,
          next: t
        }

  @type from :: number
  @type delta :: number
  @type length :: integer
  @type step :: integer

  @type attr_key ::
          :x | :y | :width | :height | :alpha | :rotate | :skew_x | :skew_y | :scale_x | :scale_y
  @type param_key :: atom
  @type value :: number | {:add, number} | {:sub, number}
  @type attrs :: %{optional(attr_key) => value}
  @type params :: %{optional(param_key) => value}

  @type easing ::
          :lin
          | :quad_in
          | :quad_out
          | :quad_inout
          | :cubic_in
          | :cubic_out
          | :cubic_inout
          | :quart_in
          | :quart_out
          | :quart_inout
          | :quint_in
          | :quint_out
          | :quint_inout
          | :sin_in
          | :sin_out
          | :sin_inout
          | :exp_in
          | :exp_out
          | :exp_inout
          | :circ_in
          | :circ_out
          | :circ_inout
          | (from, delta, length, step -> number)

  @type option :: {:in, length} | {:use, easing}
  @type options :: [option]

  @allowed_attributes [
    :x,
    :y,
    :width,
    :height,
    :alpha,
    :rotate,
    :skew_x,
    :skew_y,
    :scale_x,
    :scale_y
  ]

  # Public API

  @spec move(Tween.t() | nil, attrs, params, options) :: Tween.t()
  def move(prev \\ nil, attrs, params, opts) do
    attrs = Map.take(attrs, @allowed_attributes)
    length = Keyword.fetch!(opts, :in)
    easing = get_easing_fun(Keyword.get(opts, :use, :lin))
    anim = %Tween{attrs: attrs, params: params, length: length, easing: easing}
    maybe_set_next(prev, anim)
  end

  @spec pause(Tween.t() | nil, length) :: Tween.t()
  def pause(prev \\ nil, length) do
    anim = %Tween{length: length}
    maybe_set_next(prev, anim)
  end

  @spec set(Tween.t() | nil, attrs, params) :: Tween.t()
  def set(prev \\ nil, attrs, params) do
    attrs = Map.take(attrs, @allowed_attributes)
    length = if is_nil(prev), do: 0, else: 1
    anim = %Tween{attrs: attrs, params: params, length: length, easing: get_easing_fun(:lin)}
    maybe_set_next(prev, anim)
  end

  @frame_rate_error_msg "can not query frame rate. perhaps this function was called outside a Vizi.View process"

  @spec sec(number) :: length
  def sec(x) do
    case Process.get(:vz_frame_rate) do
      nil ->
        raise @frame_rate_error_msg

      frame_rate ->
        round(x * frame_rate)
    end
  end

  @spec msec(number) :: length
  def msec(x) do
    case Process.get(:vz_frame_rate) do
      nil ->
        raise @frame_rate_error_msg

      frame_rate ->
        round(x / 1000 * frame_rate)
    end
  end

  @spec min(number) :: length
  def min(x) do
    case Process.get(:vz_frame_rate) do
      nil ->
        raise @frame_rate_error_msg

      frame_rate ->
        round(x * 60 * frame_rate)
    end
  end

  defmacro __using__(_) do
    quote do
      import Vizi.Tween, only: [sec: 1, msec: 1, min: 1]
      alias Vizi.Tween
    end
  end

  # Internal functions

  defp maybe_set_next(%Tween{next: nil} = prev, anim) do
    %Tween{prev | next: anim}
  end

  defp maybe_set_next(%Tween{next: next} = prev, anim) do
    %Tween{prev | next: maybe_set_next(next, anim)}
  end

  defp maybe_set_next(nil, anim) do
    anim
  end

  defp get_easing_fun(:lin), do: &easing_lin/4

  defp get_easing_fun(:quad_in), do: &easing_quad_in/4

  defp get_easing_fun(:quad_out), do: &easing_quad_out/4

  defp get_easing_fun(:quad_inout), do: &easing_quad_inout/4

  defp get_easing_fun(:cubic_in), do: &easing_cubic_in/4

  defp get_easing_fun(:cubic_out), do: &easing_cubic_out/4

  defp get_easing_fun(:cubic_inout), do: &easing_cubic_inout/4

  defp get_easing_fun(:quart_in), do: &easing_quart_in/4

  defp get_easing_fun(:quart_out), do: &easing_quart_out/4

  defp get_easing_fun(:quart_inout), do: &easing_quart_inout/4

  defp get_easing_fun(:quint_in), do: &easing_quint_in/4

  defp get_easing_fun(:quint_out), do: &easing_quint_out/4

  defp get_easing_fun(:quint_inout), do: &easing_quint_inout/4

  defp get_easing_fun(:sin_in), do: &easing_sin_in/4

  defp get_easing_fun(:sin_out), do: &easing_sin_out/4

  defp get_easing_fun(:sin_inout), do: &easing_sin_inout/4

  defp get_easing_fun(:exp_in), do: &easing_exp_in/4

  defp get_easing_fun(:exp_out), do: &easing_exp_out/4

  defp get_easing_fun(:exp_inout), do: &easing_exp_inout/4

  defp get_easing_fun(:circ_in), do: &easing_circ_in/4

  defp get_easing_fun(:circ_out), do: &easing_circ_out/4

  defp get_easing_fun(:circ_inout), do: &easing_circ_inout/4

  defp get_easing_fun(fun) when is_function(fun), do: fun

  defp get_easing_fun(nil), do: nil

  defp get_easing_fun(badarg),
    do: raise(ArgumentError, message: "invalid easing function: #{inspect(badarg)}")

  @doc false
  def easing_lin(from, delta, length, step) do
    delta * (step / length) + from
  end

  defp easing_quad_in(from, delta, length, step) do
    step = step / length
    delta * step * step + from
  end

  defp easing_quad_out(from, delta, length, step) do
    step = step / length
    -delta * step * (step - 2) + from
  end

  defp easing_quad_inout(from, delta, length, step) do
    step = step / (length / 2)

    if step < 1 do
      delta / 2 * step * step + from
    else
      step = step - 1
      -delta / 2 * (step * (step - 2) - 1) + from
    end
  end

  defp easing_cubic_in(from, delta, length, step) do
    step = step / length
    delta * step * step * step + from
  end

  defp easing_cubic_out(from, delta, length, step) do
    step = step / length - 1
    delta * (step * step * step + 1) + from
  end

  defp easing_cubic_inout(from, delta, length, step) do
    step = step / (length / 2)

    if step < 1 do
      delta / 2 * step * step * step + from
    else
      step = step - 2
      delta / 2 * (step * step * step + 2) + from
    end
  end

  defp easing_quart_in(from, delta, length, step) do
    step = step / length
    delta * step * step * step * step + from
  end

  defp easing_quart_out(from, delta, length, step) do
    step = step / length - 1
    -delta * (step * step * step * step - 1) + from
  end

  defp easing_quart_inout(from, delta, length, step) do
    step = step / (length / 2)

    if step < 1 do
      delta / 2 * step * step * step * step + from
    else
      step = step - 2
      -delta / 2 * (step * step * step * step - 2) + from
    end
  end

  defp easing_quint_in(from, delta, length, step) do
    step = step / length
    delta * step * step * step * step * step + from
  end

  defp easing_quint_out(from, delta, length, step) do
    step = step / length - 1
    delta * (step * step * step * step * step + 1) + from
  end

  defp easing_quint_inout(from, delta, length, step) do
    step = step / (length / 2)

    if step < 1 do
      delta / 2 * step * step * step * step * step + from
    else
      step = step - 2
      delta / 2 * (step * step * step * step * step + 2) + from
    end
  end

  @pi 3.141592653589793
  @half_pi 3.141592653589793 / 2

  defp easing_sin_in(from, delta, length, step) do
    -delta * :math.cos(step / length * @half_pi) + delta + from
  end

  defp easing_sin_out(from, delta, length, step) do
    delta * :math.sin(step / length * @half_pi) + from
  end

  defp easing_sin_inout(from, delta, length, step) do
    -delta / 2 * (:math.cos(@pi * step / length) - 1) + from
  end

  defp easing_exp_in(from, delta, length, step) do
    delta * :math.pow(2, 10 * (step / length - 1)) + from
  end

  defp easing_exp_out(from, delta, length, step) do
    delta * (-:math.pow(2, -10 * (step / length)) + 1) + from
  end

  defp easing_exp_inout(from, delta, length, step) do
    step = step / (length / 2)

    if step < 1 do
      delta / 2 * :math.pow(2, 10 * (step - 1)) + from
    else
      step = step - 1
      delta / 2 * (-:math.pow(2, -10 * step) + 2) + from
    end
  end

  defp easing_circ_in(from, delta, length, step) do
    step = step / length
    -delta * (:math.sqrt(1 - step * step) - 1) + from
  end

  defp easing_circ_out(from, delta, length, step) do
    step = step / length - 1
    delta * :math.sqrt(1 - step * step) + from
  end

  defp easing_circ_inout(from, delta, length, step) do
    step = step / (length / 2)

    if step < 1 do
      -delta / 2 * (:math.sqrt(1 - step * step) - 1) + from
    else
      step = step - 2
      delta / 2 * (:math.sqrt(1 - step * step) + 1) + from
    end
  end
end
