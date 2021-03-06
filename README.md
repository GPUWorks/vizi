# Vizi

Vizi is a antialiased 2D vector based visualization and GUI library for Elixir. It offers a simple
scene graph, window and event handling, animations, and 2D drawing functions that are loosely based on the HTML5 canvas
API.

All drawing is powered by [NanoVG](https://github.com/memononen/nanovg). NanoVG uses OpenGL as a render
target, so performance should be pretty decent on systems with hardware accelerated graphics.

All window and event handling is provided by [Pugl](https://github.com/drobilla/pugl).


## Getting started


### Installing

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


### Creating a View

Vizi provides the `Vizi.CanvasView` module for easy experimentation with the drawing API, so we'll
start off by using this module.

We begin with an empty window that has a canvas area of 800 x 600 pixels. Vizi both
supports manual redrawing and redrawing at a fixed interval. For now we use interval
based redrawing at a frame rate of 30 fps.
```elixir
{:ok, pid} = Vizi.CanvasView.start_link(width: 800, height: 600,
                                        redraw_mode: :interval, frame_rate: 30)
```

You should now see a new window filled with nothing but emptyness. Let's start drawing something in to it!


### Drawing on a canvas

```elixir
Vizi.CanvasView.draw(pid, %{red: 255}, fn params, width, height, ctx ->
  use Vizi.Canvas

  ctx
  |> begin_path()
  |> rect(0, 0, width, height)
  |> fill_color(rgba params.red, 0, 0)
  |> fill()
end)
```

The contents of our window should now contain a red rectangle the size of the canvas area. Let's breakdown
the snippet above line by line.

The first argument of the `draw/3` function is the `pid` of our `CanvasView` instance, the second
argument is a parameters map that is passed to the drawing function every time it is invoked. Parameters are
especially useful for animations, as we will see in the next example. The third argument expects a function that performs
the actual drawing. The signature of this function should be: `(params, width, height, context -> any)`
The first argument are the aforementioned params, the second and third argument are the width and height of
the view and the last argument is a handle to the drawing context. The drawing context is an opaque
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
functions to define the path to draw, such as `rect/5`, `rounded_rect/6` and `ellipse/5`, or you can use the common
`move_to/3`, `line_to/3`, `bezier_to/7` and `arc_to/6` functions to compose the paths step by step.


### Animations

Since looking at a big red surface is rather dull, let's add an animation to make things more interesting:

```elixir
Vizi.CanvasView.animate(pid, :pingpong, fn ->
  use Vizi.Tween

  Tween.move(%{}, %{red: 0}, in: sec(3), use: :quad_out)
end)
```

The canvas area should loop between a 3 second fade to black and fade back to red again.
Vizi uses tweening for animations which allow parameters (and attributes, which we'll cover later) to be
animated over time.

The first argument of the tween defines which parameters need to be animated and what their target value should be.
The duration of the animation must be set with the `:in` option and expects the duration to be in frames. However, the `Vizi.Tween`
module has a couple of handy helper functions which convert a duration in seconds, milliseconds, or minutes to frames. With the `:mode`
option you specify the playback mode of the animation. The default mode is `:once`, meaning the animation is triggered once and when the
target value is reached, the animation is automatically removed. In the example above we have set the mode to `:pingpong` which means
the animation is constantly looped forward and backward. Last but not least, the `:use` option sets an easing function. Easing
functions define the rate at which something moves over time. The `:exp_in` easing function for example starts to move slowly to its target
value, but accelerates its rate exponentially.

Animations can be chained too, allowing you to easily define complex animations.

We'll finish this getting started guide with a more complex shape and a chained animation.

```elixir
Vizi.CanvasView.draw(pid, %{size: 1, angle: 0}, fn params, width, height, ctx ->
  use Vizi.Canvas

    paint = Paint.box_gradient(ctx, 0, 0, width, height, 200, 500, rgba(255, 0, 0), rgba(255, 255, 255))

    ctx
    |> scale(params.size, params.size)
    |> translate(width / 2, height / 2)
    |> rotate(deg_to_rad(params.angle))
    |> translate(-width / 2, -height / 2)
    |> fill_paint(paint)
    |> begin_path()
    |> move_to(400, 160)
    |> bezier_to(400, 148, 380, 100, 300, 100)
    |> bezier_to(180, 100, 180, 250, 180, 250)
    |> bezier_to(180, 320, 260, 408, 400, 480)
    |> bezier_to(540, 408, 620, 320, 620, 250)
    |> bezier_to(620, 250, 620, 100, 500, 100)
    |> bezier_to(440, 100, 400, 148, 400, 160)
    |> fill()
end)

Vizi.CanvasView.animate(pid, fn ->
  use Vizi.Tween

  Tween.set(%{}, %{size: 1, angle: 0})
  |> Tween.move(%{}, %{size: 1.1}, in: sec(0.3), use: :sin_out)
  |> Tween.move(%{}, %{size: 1}, in: sec(0.3), use: :sin_out)
  |> Tween.pause(sec(0.5))
  |> Tween.move(%{}, %{angle: 360}, in: sec(2), use: :cubic_inout)
end)
```


## Architecture

Vizi's `CanvasView` allows you to quickly draw something and animate its parameters without writing lots of boilerplate code, but it
lacks support for events and offers no abstractions for managing complexity as soon as visualizations start to be more complex.
So let's dive into Vizi's architecture a bit more and see how a complete Vizi application is set up.


### Views

Vizi provides the `Vizi.View` behaviour for creating your own view. In fact, `Vizi.CanvasView` is just a simple implementation of
the `Vizi.View` behaviour. `Vizi.View` is implemented as a thin layer on top of Elixir's `GenServer` and is mainly responsible for handling
messages sent from other Elixir processes, dispatching events and managing redraws.

The callbacks needed for implementing the behaviour mostly matches the callbacks needed to write a `GenServer`, so if you already feel
comfortable writing a `GenServer` implementation, you'll have no problems writing your own view.


### Events

A view receives input events like keyboard input and mouse movement via its `handle_event/3` callback function. It's also possible to send
custom events to a view from other processes. Since a view allows handling generic messages via its `handle_call/4`, `handle_cast/3` and
`handle_info/3` callback functions, just like a `GenServer`, custom events are mainly used for notifying and/or updating nodes,
which will be covered in the next section.


### Nodes

A node provides a bounded drawing area in a view, defined by its `x`, `y`, `width` and `height` attributes. In addition it can receive both input and custom events. If an input event has `x` and `y` fields, like mouse movement and button clicks, the node will only receive events whose position is within the
bounds of the node. In addition to `x`, `y`, `width` and `height` attributes, nodes also have several other attributes like `scale`, `rotate` and `alpha`.

A node is a recursive data structure as it can contain other nodes as children. Attributes set on a parent node affect all its children too, so if a parent
node is rotated 45 degrees, all it's children are rotated likewise. When a view initiates a redraw, it starts drawing the root node, then its first child
node and its children, etc. This means that child nodes are drawn on top of their parent and that the next sibling node is drawn on top of the previous sibling, if their bounds overlap.

Vizi follows the idea that a node is only responsible for its children and that a child node should have no knowledge about its parent. If a node really needs to pass something to a node higher up in the tree, it should send a custom event that the parent node listens to.

### Canvas


### Animation


## Implementation

