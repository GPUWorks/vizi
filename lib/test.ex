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
    el = put_in(el.state.img, img)
    {:ok, put_in(el.state.bm, bm)}
  end

  def update(el, ctx) do
    img = Image.create(ctx, "c_src/nanovg/example/images/image#{el.state.cnt}.jpg", [:repeat_x, :repeat_y])
    state = %{el.state| img: img, cnt: (if el.state.cnt == 12, do: 1, else: el.state.cnt + 1)}
    {:ok, %{el|state: state}}
  end

  def draw(width, height, ctx, state) do
    paint = Paint.image_pattern(ctx, 0, 0, 100, 100, 45, state.img)

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
    c = Vizi.Element.update_any(c, :a, fn el ->
      %{el|x: ev.x, y: ev.y}
    end)
    {:done, c}
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
    {:ok, update_in(el.state.angle, fn angle -> if angle == 359, do: 0, else: angle + 1 end)}
  end

  def draw(width, height, ctx, state) do
    ctx
    |> begin_path()
    |> rect(0, 0, width, height)
    |> fill_color(rgba(state.angle, 255, 255))
    |> fill()
    |> translate(50, 50)
    |> rotate(deg_to_rad(state.angle))
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
    Vizi.Element.create(__MODULE__, nil, opts)
  end

  def init(el, ctx) do
    font = Text.create_font(ctx, "/home/zambal/dev/vizi/c_src/nanovg/example/Roboto-Light.ttf")
    {:ok, %{el|state: %{font: font, color: rgba(255, 0, 0, 255)}}}
  end

  def draw(_width, _height, ctx, state) do
    ctx
    |> font_face(state.font)
    |> font_size(48.0)
    |> fill_color(state.color)
    |> text(0, 40, "Hello World!")
  end

  def handle_event(c, %Events.Custom{}) do
    {:done, put_in(c.state.color, rgba(255, 0, 0))}
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
        TestC2.create(x: n + 100, y: n + 100, width: 100, height: 100, alpha: 0.3, tags: [:a, :b])
      end
    )
    {:ok, root, nil}
  end
end