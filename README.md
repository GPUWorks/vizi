# Vizi

## Introduction

Vizi is a antialiased 2D vector based visualization and GUI library for Elixir. It offers a simple
scene graph, window and event handling, and 2D drawing functions that are loosely based on the HTML5 canvas
API.

All drawing is powered by [NanoVG](https://github.com/memononen/nanovg). NanoVG uses OpenGL as a render
target, so performance should be pretty decent on systems with hardware accelerated graphics.

All window and event handling is provided by [Pugl](https://github.com/drobilla/pugl).


## Getting started

The easiest way to get started is by using the Hex package. The package currently provides pre-build binaries
for 64-bit Windows and Linux systems and can be installed by adding `vizi` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [
    {:vizi, "~> 0.1.0"}
  ]
end
```

Vizi provides the `Vizi.CanvasView` module for easy experimentation with the drawing API, so we'll
start off by using this module. `Vizi.CanvasView` provides just two public functions: `start_link/1`
and `draw/3`.

We begin with an empty window that has a canvas area of 800 x 600 pixels. Vizi both
supports manual redrawing and redrawing at a fixed interval. For now we use interval
based redrawing at a frame rate of 30 fps.
```elixir
iex> {:ok, pid} = Vizi.CanvasView.start_link(width: 800, height: 600,
                                             redraw_mode: :interval, frame_rate: 30)
{:ok, #PID<0.256.0>}
```

You should now see a new window filled with nothing but emptyness. Let's start drawing something in to it!

```elixir
iex> Vizi.CanvasView.draw(pid, %{}, fn params, width, height, ctx ->
  use Vizi.Canvas

  ctx
  |> begin_path()
  |> rect(0, 0, width, height)
  |> fill_color(rgba 255, 0, 0)
  |> fill()

  {:ok, params}
end)
```

The contents of our window should now contain a red rectangle the size of the canvas area. Let's breakdown
the snippet above line by line.

The first argument of the `draw/3` function is the `pid` of our `CanvasView` instance, the second
argument is a parameters term that is passed to the drawing function every time it is invoked. The params
argument accepts any Elixir term, but is a map by convention. The third argument expects a function that performs
the actual drawing. The signature of this function is expected to be: `(params, width, height, context -> {:ok, params})`
The first argument are the aforementioned params, the second and third argument are the width and height of
the view and the fourth and last argument is a handle to the drawing context. The drawing context is an opaque
resource type managed by the native code part of Vizi.

All drawing related functions are in the `Vizi.Canvas` module and its submodules. You can call
`use Vizi.Canvas` to import all functions from `Vizi.Canvas` and alias all `Vizi.Canvas.*`
submodules to `*` in the current scope. All fuctions that need a drawing context expect it to be
the first argument and will return it too in most cases, allowing nice usage of Elixir's pipe operator.

Drawing a simple shape with Vizi consists of four steps:

1. begin a new shape
2. define the path to draw
3. set fill or stroke
4. and finally fill or stroke the path.

Calling `begin_path/1` will clear any existing paths and start drawing from blank slate. There are number of number of
functions to define the path to draw, such as `rectangle`, `rounded rectangle` and `ellipse`, or you can use the common
`move_to`, `line_to`, `bezier_to` and `arc_to` functions to compose the paths step by step.

Finally, we return from our drawing function with `{:ok, params}`. `CanvasView` stores the returned params and passes
it to our drawing function the next time it is invoked. This is very useful when you want to animate things over time,
which is extactly what we are going to do with the next example:

```elixir
iex> Vizi.CanvasView.draw(pid, %{red: 0}, fn params, width, height, ctx ->
  use Vizi.Canvas

  ctx
  |> begin_path()
  |> rect(0, 0, width, height)
  |> fill_color(rgba params.red, 0, 0)
  |> fill()

  {:ok, update_in(params.red, fn x -> if x == 255, do: 0, else: x + 1 end)}
end)
```

The canvas area should now start completely black, gradually becoming more red and after becoming fully red,
the cycle should repeat itself.

iex> Vizi.CanvasView.draw(pid, %{}, fn params, width, height, ctx ->
  use Vizi.Canvas

    ctx
    |> stroke_color(rgba 255, 0, 0)
    |> fill_color(rgba 255, 0, 0)
    |> begin_path()
    |> move_to(75, 40)
    |> bezier_to(75, 37, 70, 25, 50, 25)
    |> bezier_to(20, 25, 20, 62.5, 20, 62.5)
    |> bezier_to(20, 80, 40, 102, 75, 120)
    |> bezier_to(110, 102, 130, 80, 130, 62.5)
    |> bezier_to(130, 62.5, 130, 25, 100, 25)
    |> bezier_to(85, 25, 75, 37, 75, 40)
    |> fill()

    {:ok, params}
end)


## Architecture

