defmodule Vizi.Canvas.Color do
  alias Vizi.NIF

  defstruct r: 0.0, g: 0.0, b: 0.0, a: 1.0

  @type t :: %Vizi.Canvas.Color{r: float, g: float, b: float, a: float}

  @doc """
  Linearly interpolates from color c1 to c2, and returns resulting color value.
  """
  defdelegate lerp(c1, c2, u), to: NIF, as: :lerp_rgba

  @doc """
  Returns color struct specified by hue, saturation, lightness and alpha.
  """
  defdelegate from_hsla(h, s, l, a \\ 1.0), to: NIF, as: :hsla
end
