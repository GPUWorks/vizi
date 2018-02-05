alias Vizi.{Canvas, Events, View, Node, Tween}

defmodule TestC1 do
  @moduledoc false
  use Node
  use Canvas

  def new(opts) do
    use Tween
    tween = Tween.move %{}, %{color: 100}, in: sec(6), use: :sin_inout
    tween1 = Tween.move %{}, %{angle: 359}, in: sec(2)

    __MODULE__
    |> Node.new(opts)
    |> Node.put_param(:cnt, 1)
    |> Node.animate(tween, loop: true, mode: :pingpong, update: fn node ->
      color = node.params.color
      children = for n <- node.children do
        Node.put_param(n, :color, color + n.x)
      end
      %{node|children: children}
    end)
    |> Node.animate(tween1, loop: true, update: fn node ->
      angle = node.params.angle
      children = for n <- node.children do
        Node.put_param(n, :angle, angle + n.x * n.x)
      end
      %{node|children: children}
    end)
  end

  def init(node, _ctx) do
    {:ok, node}
  end

  @tau 6.28318530718

  def draw(_params, _width, _height, _ctx) do
    :ok
  end

  def handle_event(%Events.Custom{type: :update}, node) do
    {:done, Node.update_attributes(node, rotate: fn x -> if x >= @tau, do: 0, else: x + 0.001 end)}
  end

  def handle_event(%Events.Button{type: :button_release}, node) do
    use Tween

    t = #if node.x < 200 do
      Tween.set(%{x: 0, y: 0, rotate: 0}, %{})
      |> Tween.move(%{x: 300}, %{}, in: msec(10000), use: :sin_inout)
      |> Tween.pause(60)
      |> Tween.set(%{rotate: 1}, %{})
      |> Tween.move(%{y: 300}, %{}, in: sec(4), use: :quart_out)
    #else
    #  Tween.move(%{x: 100}, %{}, in: min(0.5), use: :sin_inout)
    #  |> Tween.pause(60)
    #  |> Tween.move(%{y: 100}, %{}, in: sec(2), use: :exp_in)
    #end
    {:done, Node.animate(node, t, mode: :alternate, loop: false, tag: :test, replace: true)}
  end

  def handle_event(%Events.Motion{} = ev, node) do
    #IO.puts "TestC1 received MOTION event: #{inspect ev}"
    ch = Stream.with_index(node.children)
    |> Enum.map(fn {node, ndx} ->
      %{node|x: ndx + ev.x, y: ndx + ev.y}
    end)
    {:done, %{node|children: ch}}
  end

  def handle_event(_ev, _node) do
   # IO.inspect ev
    :cont
  end
end

defmodule TestC2 do

  @moduledoc false
  use Vizi.Node
  use Canvas

  @tau 6.28318530718

  def new(opts) do
    use Tween

    tween = Tween.move(%{rotate: -@tau}, %{}, in: sec(12))

    __MODULE__
    |> Node.new(opts)
    |> Node.put_params(%{angle: 0, img: nil})
    |> Node.animate(tween, loop: true, update: fn node ->
      %Node{node|rotate: node.rotate + node.x}
    end)
  end

  def draw(params, width, height, ctx) do
    ctx
    |> global_alpha(0.03)
    |> begin_path()
    |> rect(0, 0, width, height)
    |> fill_color(rgba(params.color, 255, 255))
    |> fill()
    |> translate(50, 50)
    |> rotate(deg_to_rad(params.angle))
    |> translate(-50, -50)
    |> global_alpha(0.2)
    |> begin_path()
    |> arc(50, 40, 20,  0, @tau, :ccw)
    |> fill_color(rgba(0, 0, 255))
    |> fill()
  end

  def handle_event(%Events.Button{type: :button_release}, _node) do
    :cont
  end
  def handle_event(%Events.Custom{} = ev, node) do
    IO.puts "TestC3 received CUSTOM event: #{inspect ev}"
    {:cont, Node.update_attributes(node, rotate: fn x -> x + 1 end)}
  end

  def handle_event(_node, _ev) do
    :cont
  end
end

defmodule TestC3 do
  @moduledoc false
  use Node
  use Canvas

  def new(opts) do
    Node.new(__MODULE__, opts)
  end

  def init(node, ctx) do
    font = Text.create_font(ctx, "/home/zambal/dev/vizi/c_src/nanovg/example/Roboto-Light.ttf")
    {:ok, %{node|params: %{font: font, color: rgba(255, 0, 0, 255)}}}
  end

  def draw(params, _width, _height, ctx) do
    ctx
    |> font_face(params.font)
    |> font_size(48.0)
    |> fill_color(params.color)
    |> text(0, 40, "Hello World!")
  end

  def handle_event(ev, _node) do
    IO.puts "TestC3 received event: #{inspect ev}"
    :cont
  end
end

defmodule Root do
  use Node

  def new(opts) do
    Node.new(__MODULE__, opts)
  end
end


defmodule T do
  @moduledoc false
  use View

  def s(name \\ :test) do
    Vizi.start_view(name, __MODULE__, redraw_mode: :interval, spawn_opt: [priority: :high])
  end

  def init(view) do
    n1 = TestC1.new(x: 0, y: 0, width: view.width, height: view.height, children: for n <- -100..300 do
      TestC2.new(x: n, y: n, width: 150, height: 100, alpha: 1)
    end)
    root = Root.new(width: 800, height: 600, children: [n1])
    {:ok, View.put_root(view, root)}
  end


  def bm_erl do
    n = %Node{params: %{test1: 0, test2: -100}}
    t = Tween.move(%{x: 100, y: 200}, %{test1: 100, test2: 0}, in: 10_000_000, use: :sin_in)
    n = Node.animate(n, t)

    ts1 = :os.timestamp()
    Enum.reduce(1..10_000_000, n, fn _x, acc ->
      Node.step_animations(acc)
    end)
    ts2 = :os.timestamp()
    IO.puts "step: #{:timer.now_diff(ts2, ts1) / 1000}"
  end
end

defmodule BM do
  use View

  defmodule Root do
    use Node
    use Canvas


    def new(opts) do
      Node.new(__MODULE__, opts)
    end

    def init(node, ctx) do
      {:ok, Node.put_params(node, %{
        img: Image.from_file(ctx, "examples/Canvas_earth.png"),
        img2: Image.from_file(ctx, "examples/Canvas_earth.png")
      })}
    end

    def draw(params, _width, _height, ctx) do
      ctx
      |> global_composite_operation(:destination_atop)
      |> draw_image(0, 50, 200, 200, params.img, alpha: 0.5, mode: :fill)
      |> draw_image(100, 150, 200, 200, params.img, alpha: 0.5, mode: :fill)

      |> global_composite_operation(:destination_over)
      |> draw_image(350, 50, 200, 200, params.img2, alpha: 0.5)
      |> draw_image(450, 150, 200, 200, params.img2, alpha: 0.5)
    end
    """
    def draw(params, width, height, ctx) do
      for n <- 0..499 do
        ctx
        |> fill_color(rgba 255, 0, 0, 110)
        |> translate(n, n)
        |> begin_path()
        |> move_to(75, 40)
        |> bezier_to(75, 37, 70, 25, 50, 25)
        |> bezier_to(20, 25, 20, 62.5, 20, 62.5)
        |> bezier_to(20, 80, 40, 102, 75, 120)
        |> bezier_to(110, 102, 130, 80, 130, 62.5)
        |> bezier_to(130, 62.5, 130, 25, 100, 25)
        |> bezier_to(85, 25, 75, 37, 75, 40)
        |> fill()
      end
    end
    """
  end

  def start do
    Vizi.start_view(:bm, __MODULE__, width: 650, height: 500, redraw_mode: :interval)
  end

  def init(view) do
    {:ok, View.put_root(view, Root.new(width: view.width, height: view.height))}
  end
end
