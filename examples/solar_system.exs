# Vizi translation of solar system tutorial from
# https://developer.mozilla.org/nl/docs/Web/API/Canvas_API/Tutorial/Basic_animations

defmodule SolarView do
  use Vizi.View

  def start do
    Vizi.View.start(__MODULE__, %{}, width: 300, height: 300)
  end

  def init(view) do
    {:ok, SolarNode.new(width: view.width, height: view.height)}
  end
end

defmodule SolarNode do
  use Vizi.Node
  use Vizi.Canvas

  @tau 6.28318530718

  def new(opts) do
    Vizi.Node.new(__MODULE__, opts)
  end

  def init(node, ctx) do
    use Vizi.Tween

    earth_tween = Tween.move %{}, %{earth_rotation: @tau}, in: sec(60)
    moon_tween  = Tween.move %{}, %{moon_rotation: @tau}, in: sec(6)

    {:ok, node
    |> Vizi.Node.put_params(%{
      sun: Image.from_file(ctx, "examples/Canvas_sun.png"),
      moon: Image.from_file(ctx, "examples/Canvas_moon.png"),
      earth: Image.from_file(ctx, "examples/Canvas_earth.png")
    })
    |> Vizi.Node.animate(earth_tween, loop: true)
    |> Vizi.Node.animate(moon_tween, loop: true)}
  end

  def draw(params, width, height, ctx) do
    ctx
    |> global_composite_operation(:destination_over)
    #Earth
    |> scope(fn ctx ->
      ctx
      |> translate(150, 150)
      |> rotate(params.earth_rotation)
      |> translate(105, 0)
      |> begin_path() # Shadow
      |> rect(0, -12, 50, 24)
      |> fill_color(rgba 0, 0, 0, 102)
      |> fill()
      |> draw_image(-12, -12, 24, 24, params.earth)
      # Moon
      |> scope(fn ctx ->
        ctx
        |> rotate(params.moon_rotation)
        |> translate(0, 28.5)
        |> draw_image(0, 0, 7, 7, params.moon)
      end)
    end)
    # Orbit
    |> begin_path()
    |> arc(150, 150, 105, 0, @tau, :ccw)
    |> stroke_color(rgba 0, 153, 255, 102)
    |> stroke()
    # Sun
    |> draw_image(0, 0, width, height, params.sun)
  end
end
