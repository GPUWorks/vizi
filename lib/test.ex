alias Vizi.Events

defmodule TestC1 do
  @moduledoc false
  use Vizi.Node
  use Vizi.Canvas

  def create(opts) do
    Vizi.Node.create(__MODULE__, %{img: nil, bm: nil, cnt: 1}, opts)
  end

  def init(node, ctx) do
    bm = Bitmap.create(ctx, 500, 300)
    Enum.each(0..(Bitmap.size(bm) - 1), fn n ->
      Bitmap.put(bm, n, rem(n, 256), 255 - rem(n, 256), 0, 255)
    end)
    img = Image.from_bitmap(ctx, bm)
    {:ok, Vizi.Node.update_params!(node,
    img: fn _ -> img end,
    bm: fn _ -> bm end)}
  end

  @tau 6.28318530718

  def draw(params, width, height, ctx) do
    cnt = params.cnt
    img = params.img
    paint = Paint.image_pattern(ctx, 0, 0, 500, 300, 0, img)

    ctx
    |> begin_path()
    |> rect(0, 0, width, height)
    |> fill_paint(paint)
    |> fill()

#    Vizi.View.send_event(:update, nil)

    {:ok, update_in(params.cnt, fn x -> if x == 255, do: 0, else: x + 1 end)}
  end

  def handle_event(node, %Events.Custom{type: :update}) do
    {:done, Vizi.Node.update_attributes(node, rotate: fn x -> if x >= @tau, do: 0, else: x + 0.001 end)}
  end

  def handle_event(node, %Events.Button{type: :button_release} = ev) do
    import Vizi.Animation

    node = Vizi.Node.add_task(node, fn params, _width, _height, ctx ->
      bm = Bitmap.create(ctx, 500, 300)
      Enum.each(0..(Bitmap.size(bm) - 1), fn n ->
        Bitmap.put(bm, n, 255 - rem(n, 256), rem(n, 256), 128, 255)
      end)
      img = Image.from_bitmap(ctx, bm)

      {:ok, %{params|bm: bm, img: img}}
    end)


    t = if node.x < 200 do
      tween(%{x: 300}, in: msec(1000), use: :sin_inout)
      |> pause(60)
      |> set(%{rotate: 1})
      |> tween(%{y: 300}, in: sec(4), use: :quart_inout)
    else
      tween(%{x: 100}, in: min(0.5), use: :sin_inout)
      |> pause(60)
      |> tween(%{y: 100}, in: sec(2), use: :exp_in, mode: :pingpong)
    end
    {:done, into(t, node)}
  end

  def handle_event(node, %Events.Motion{} = ev) do
    #IO.puts "TestC1 received MOTION event: #{inspect ev}"
    ch = Stream.with_index(node.children)
    |> Enum.map(fn {node, ndx} ->
      %{node|x: ndx + ev.x, y: ndx + ev.y}
    end)
    {:done, %{node|children: ch}}
  end

  def handle_event(_node, ev) do
   # IO.inspect ev
    :cont
  end
end

defmodule TestC2 do

  @moduledoc false
  use Vizi.Node
  use Vizi.Canvas

  def create(opts) do
    import Vizi.Animation
    tween(%{{:param, :angle} => 359}, in: sec(6), mode: :loop)
    |> into(Vizi.Node.create(__MODULE__, %{angle: 0, img: nil}, opts))
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
    |> rect(40, 40, 20, 20)
    |> fill_color(rgba(0, 0, 255))
    |> fill()
  end

  def handle_event(_node, %Events.Button{type: :button_release}) do
    :done
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
    Vizi.Node.create(__MODULE__, %{}, opts)
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


defmodule T do
  @moduledoc false
  use Vizi.View

  def s do
    {:ok, _pid} = Vizi.View.start_link(__MODULE__, nil, redraw_mode: :interval, frame_rate: 60)
  end

  def init(_args, _width, _height) do
    root = TestC1.create(x: 100, y: 100, width: 500, height: 300, children: [
      TestC2.create(x: 100, y: 100, width: 100, height: 100)
    ])
    {:ok, root, nil}
  end


  def bm_erl do
    n = %Vizi.Node{}
    t = Vizi.Animation.tween(%{x: 100}, in: 10_000_000, use: :quad_inout)
    n = Vizi.Animation.into(t, n)
    ts1 = :os.timestamp()
    Enum.reduce(1..10_000_000, n, fn _x, acc ->
      Vizi.Animation.step(acc)
    end)
    ts2 = :os.timestamp()
    :timer.now_diff(ts2, ts1) / 1000
  end
end