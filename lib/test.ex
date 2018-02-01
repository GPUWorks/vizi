alias Vizi.Events

defmodule TestC1 do
  @moduledoc false
  use Vizi.Node
  use Vizi.Canvas

  def create(opts) do
    use Vizi.Tween
    tween = Tween.move %{}, %{angle: 359}, in: sec(2)

    __MODULE__
    |> Vizi.Node.create(opts)
    |> Vizi.Node.put_param(:cnt, 1)
    |> Vizi.Node.animate(tween, loop: true, updater: fn node ->
      angle = node.params.angle
      children = for n <- node.children do
        Vizi.Node.put_param(n, :angle, angle + n.x * n.x)
      end
      %{node|children: children}
    end)
  end

  def init(node, ctx) do
    bm = Bitmap.create(ctx, 500, 300)
    Enum.each(0..(Bitmap.size(bm) - 1), fn n ->
      Bitmap.put(bm, n, rem(n, 256), 255 - rem(n, 25), 0, 255)
    end)
    img = Image.from_bitmap(ctx, bm)
    {:ok, Vizi.Node.put_params(node, %{
      img: img,
      bm: bm
    })}
  end

  @tau 6.28318530718

  def draw(params, width, height, ctx) do
    img = params.img
    paint = Paint.image_pattern(ctx, 0, 0, 500, 300, 0, img)

    ctx
    |> begin_path()
    |> rect(0, 0, width, height)
    |> fill_paint(paint)
    |> fill()
    |> rotate(1)

#    Vizi.View.send_event(:update, nil)

    {:ok, update_in(params.cnt, fn x -> if x == 255, do: 0, else: x + 1 end)}
  end

  def handle_event(node, %Events.Custom{type: :update}) do
    {:done, Vizi.Node.update_attributes(node, rotate: fn x -> if x >= @tau, do: 0, else: x + 0.001 end)}
  end

  def handle_event(node, %Events.Button{type: :button_release}) do
    use Vizi.Tween

    node = Vizi.Node.add_task(node, fn params, _width, _height, ctx ->
      bm = Bitmap.create(ctx, 500, 300)
      offset1 = :rand.uniform(256)
      offset2 = :rand.uniform(256)
      Enum.each(0..(Bitmap.size(bm) - 1), fn n ->
        Bitmap.put(bm, n, 255 - rem(offset1 + n, 25), rem(offset2 + n, 256), 128, 255)
      end)
      img = Image.from_bitmap(ctx, bm)

      {:ok, %{params|bm: bm, img: img}}
    end)


    t = #if node.x < 200 do
      Tween.set(%{x: 100, y: 0, rotate: 0}, %{})
      |> Tween.move(%{x: 300}, %{}, in: msec(10000), use: :sin_inout)
      |> Tween.pause(60)
      |> Tween.set(%{rotate: 1}, %{})
      |> Tween.move(%{y: 300}, %{}, in: sec(4), use: :quart_out)
    #else
    #  Tween.move(%{x: 100}, %{}, in: min(0.5), use: :sin_inout)
    #  |> Tween.pause(60)
    #  |> Tween.move(%{y: 100}, %{}, in: sec(2), use: :exp_in)
    #end
    {:done, Vizi.Node.animate(node, t, mode: :alternate, loop: false, tag: :test, replace: true)}
  end

  def handle_event(node, %Events.Motion{} = ev) do
    #IO.puts "TestC1 received MOTION event: #{inspect ev}"
    ch = Stream.with_index(node.children)
    |> Enum.map(fn {node, ndx} ->
      %{node|x: ndx + ev.x, y: ndx + ev.y}
    end)
    {:done, %{node|children: ch}}
  end

  def handle_event(_node, _ev) do
   # IO.inspect ev
    :cont
  end
end

defmodule TestC2 do

  @moduledoc false
  use Vizi.Node
  use Vizi.Canvas

  def create(opts) do
    __MODULE__
    |> Vizi.Node.create(opts)
    |> Vizi.Node.put_params(%{angle: 0, img: nil})
  end

  def draw(params, width, height, ctx) do
    ctx
    |> begin_path()
    |> rect(0, 0, width, height)
    |> fill_color(rgba(params.angle, 255, 255))
    |> fill()
    |> translate(50, 50)
    |> rotate(deg_to_rad(params.angle))
    |> translate(-50, -50)
    |> begin_path()
    |> rect(50, 40, 20,  20)
    |> fill_color(rgba(0, 0, 255))
    |> fill()
  end

  def handle_event(_node, %Events.Button{type: :button_release}) do
    :cont
  end
  def handle_event(node, %Events.Custom{} = ev) do
    IO.puts "TestC3 received CUSTOM event: #{inspect ev}"
    {:cont, Vizi.Node.update_attributes(node, rotate: fn x -> x + 1 end)}
  end

  def handle_event(_node, _ev) do
    :cont
  end
end

defmodule TestC3 do
  @moduledoc false
  use Vizi.Node
  use Vizi.Canvas

  def create(opts) do
    Vizi.Node.create(__MODULE__, opts)
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

  def handle_event(_node, ev) do
    IO.puts "TestC3 received event: #{inspect ev}"
    :cont
  end
end

defmodule Root do
  use Vizi.Node

  def create(opts) do
    Vizi.Node.create(__MODULE__, opts)
  end
end


defmodule T do
  @moduledoc false
  use Vizi.View

  def s do
    {:ok, _pid} = Vizi.View.start(__MODULE__, nil, redraw_mode: :interval, spawn_opt: [priority: :high])
  end

  def init(_args, _width, _height) do
    n1 = TestC1.create(x: 100, y: 0, width: 500, height: 300, children: for n <- -100..400 do
      TestC2.create(x: n, y: n, width: 100, height: 100, alpha: 0.05)
    end)
    _n2 = TestC1.create(x: 100, y: 300, width: 500, height: 300, children: for n <- -100..400 do
      TestC2.create(x: n, y: n, width: 100, height: 100, alpha: 0.05)
    end)
    root = Root.create(width: 800, height: 600, children: [n1])
    {:ok, root, nil}
  end


  def bm_erl do
    n = %Vizi.Node{params: %{test1: 0, test2: -100}}
    t = Vizi.Tween.move(%{x: 100, y: 200}, %{test1: 100, test2: 0}, in: 10_000_000, use: :sin_in)
    n = Vizi.Node.animate(n, t)

    ts1 = :os.timestamp()
    Enum.reduce(1..10_000_000, n, fn _x, acc ->
      Vizi.Node.step_animations(acc)
    end)
    ts2 = :os.timestamp()
    IO.puts "step: #{:timer.now_diff(ts2, ts1) / 1000}"
  end
end

defmodule BM do
  use Vizi.View

  defmodule Node do
    use Vizi.Node
    use Vizi.Canvas


    def create(opts) do
      Vizi.Node.create(__MODULE__, opts)
    end

    def init(node, ctx) do
      {:ok, Vizi.Node.put_params(node, %{
        img: Image.create(ctx, "/home/zambal/Pictures/Vakantie-New-York.jpg"),
        img2: Image.create(ctx, "/home/zambal/Pictures/Vakantie-New-York.jpg")
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
    Vizi.View.start(__MODULE__, nil, width: 650, height: 500, redraw_mode: :interval)
  end

  def init(_args, _width, _height) do
    {:ok, Node.create(x: 0, y: 0, width: 650, height: 500), nil}
  end
end
