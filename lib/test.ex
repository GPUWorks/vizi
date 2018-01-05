alias Vizi.Events

defmodule TestC1 do
  @moduledoc false
  use Vizi.Element
  use Vizi.Canvas

  def create(opts) do
    Vizi.Element.create(__MODULE__, %{img: nil, bm: nil, cnt: 1}, opts)
  end

  def init(el, ctx) do
    bm = Bitmap.create(500, 300)
    Enum.each(0..(Bitmap.size(bm) - 1), fn n ->
      Bitmap.put(bm, n, rem(n, 256), 255 - rem(n, 256), 0, 255)
    end)
    img = Image.from_bitmap(ctx, bm)
    el = put_in(el.params.img, img)
    {:ok, put_in(el.params.bm, bm)}
  end

  @tau 6.28318530718

  def update(el, ctx) do
    el = Vizi.Element.update_attributes(el, rotate: fn x -> if x >= @tau, do: 0, else: x + 0.001 end)
    {:ok, Vizi.Element.update_params!(el,
    img: fn _ -> Image.create(ctx, "c_src/nanovg/example/images/image#{el.params.cnt}.jpg", [:repeat_x, :repeat_y]) end,
    cnt: fn x -> if x == 12, do: 1, else: x + 1 end)}
  end

  def draw(params, width, height, ctx) do
    paint = Paint.image_pattern(ctx, 0, 0, 100, 100, 45, params.img)

    ctx
    |> begin_path()
    |> rect(0, 0, width, height)
    |> fill_paint(paint)
    |> fill()
  end

  def handle_event(_c, %Events.Scroll{} = ev) do
    IO.inspect ev
    :done
  end
  def handle_event(_c, %Events.Button{type: :button_release}) do
    Vizi.View.redraw()
    :done
  end

  def handle_event(c, %Events.Motion{} = ev) do
    #IO.puts "TestC1 received event: #{inspect ev}"
    ch = Stream.with_index(c.children)
    |> Enum.map(fn {el, ndx} ->
      %{el|x: ndx + ev.x, y: ndx + ev.y}
    end)
    {:done, %{c|children: ch}}
  end

  def handle_event(_c, _ev) do
    :cont
  end
end

defmodule TestC2 do

  @moduledoc false
  use Vizi.Element
  use Vizi.Canvas

  def create(opts) do
    Vizi.Element.create(__MODULE__, %{angle: 0, img: nil}, opts)
  end

  def update(el, _ctx) do
    {:ok, update_in(el.params.angle, fn angle -> if angle == 359, do: 0, else: angle + 1 end)}
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

  def handle_event(_c, %Events.Motion{} = ev) do
    IO.inspect ev
    :cont
  end
  def handle_event(_c, _ev) do
    :cont
  end
end

defmodule TestC3 do
  @moduledoc false
  use Vizi.Element
  use Vizi.Canvas

  def create(opts) do
    Vizi.Element.create(__MODULE__, %{}, opts)
  end

  def init(el, ctx) do
    font = Text.create_font(ctx, "/home/zambal/dev/vizi/c_src/nanovg/example/Roboto-Light.ttf")
    {:ok, %{el|params: %{font: font, color: rgba(255, 0, 0, 255)}}}
  end

  def draw(params, _width, _height, ctx) do
    ctx
    |> font_face(params.font)
    |> font_size(48.0)
    |> fill_color(params.color)
    |> text(0, 40, "Hello World!")
  end

  def handle_event(c, %Events.Custom{}) do
    {:done, put_in(c.params.color, rgba(255, 0, 0))}
  end
  def handle_event(_c, _ev) do
    #IO.puts "TestC3 received event: #{inspect ev}"
    :cont
  end
end


defmodule TestView do
  @moduledoc false
  use Vizi.View

  def start do
    {:ok, _pid} = Vizi.View.start_link(__MODULE__, nil, redraw_mode: :interval, frame_rate: 60)
  end

  def init(_args) do
    root = TestC1.create(x: 100, y: 100, width: 500, height: 300, children:
      for n <- 1..100 do
        TestC2.create(x: n, y: n, width: 100, height: 100, alpha: 0.01, tags: [:a, :b])
      end
    )
    {:ok, root, nil}
  end
end