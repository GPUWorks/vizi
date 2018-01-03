alias Vizi.Events

defmodule TestC1 do
  @moduledoc false
  use Vizi.Element
  use Vizi.Canvas

  def create(opts) do
    Vizi.Element.create(__MODULE__, %{img: nil, bm: nil, cnt: 0}, opts)
  end

  def init(c, ctx) do
    bm = Bitmap.create(500, 300)
    Enum.each(0..(Bitmap.size(bm) - 1), fn n ->
      Bitmap.put(bm, n, rem(n, 256), 255 - rem(n, 256), 0, 255)
    end)
    img = Image.from_bitmap(ctx, bm)
    c = put_in(c.state.img, img)
    put_in(c.state.bm, bm)
  end

  def draw(ctx, width, height, state) do
    paint = Paint.image_pattern(ctx, 0, 0, 500, 300, 0, state.img)

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
  def handle_event(_c, %Events.Button{type: :button_release, context: ctx}) do
    Vizi.View.redraw(ctx)
    :done
  end

  def handle_event(c, %Events.Motion{} = ev) do
    #IO.puts "TestC1 received event: #{inspect ev}"
    [c2, c3] = c.children
    c2 = %{c2|x: ev.x, y: ev.y}
    {:done, %{c|children: [c2, c3]}}
  end
  def handle_event(el, %Events.Update{} = ev) do
#    bm = el.state.bm
    #t1 = :os.timestamp
#    x = el.state.cnt
#    x = round(128 + :math.sin(deg_to_rad(x)) * 128)
#    Enum.each(0..(Bitmap.size(bm) - 1), fn n ->
#      Bitmap.put(bm, n, x, rem(n + x, 256), 0, 255)
#    end)

#    buffer = for n <- 1..(300*500), into: "" do
#      <<x, 0, x, 255>>
#    end


#    Enum.each(0..(Bitmap.size(bm) - 1), fn n ->
#      Bitmap.put_bin(bm, n, <<x, 0, 0, 255>>)
#    end)

#    Enum.each(0..(div(Bitmap.size(bm), 4) - 1), fn n ->
#      Bitmap.put_bin(bm, n * 4, <<x, 0, 0, 255, x, 0, 0, 255, x, 0, 0, 255, x, 0, 0, 255>>)
#    end)

   #t2 = :os.timestamp
    #IO.puts :timer.now_diff(t2, t1)

    #Image.update_from_bitmap(ev.context, el.state.img, bm)
    #Image.update(ev.context, el.state.img, buffer)
    el = put_in(el.rotate, deg_to_rad(el.state.cnt))
    {:cont, update_in(el.state.cnt, fn x -> if x == 359, do: 0, else: x + 0.125 end)}
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

  def draw(ctx, width, height, state) do
    ctx
    |> begin_path()
    |> rect(0, 0, width, height)
    |> fill_color(rgba(255, 255, 255))
    |> fill()
    |> translate(50, 50)
    |> rotate(deg_to_rad(state.angle))
    |> translate(-50, -50)
    |> begin_path()
    |> rect(40, 40, 20, 20)
    |> fill_color(rgba(0, 0, 255))
    |> fill()
  end

  def handle_event(el, %Events.Update{}) do
    el = update_in(el.state.angle, fn a -> if a == 359, do: 0, else: a + 1 end)
    {:cont, put_in(el.rotate, deg_to_rad(20))}
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

  def init(c, ctx) do
    font = Text.create_font(ctx, "/home/zambal/dev/vizi/c_src/nanovg/example/Roboto-Light.ttf")
    %{c|state: %{font: font, color: rgba(255, 255, 255, 255)}}
  end

  def draw(ctx, _width, _height, state) do
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
    {:ok, _pid} = Vizi.View.start_link(__MODULE__, nil, redraw_mode: :manual, frame_rate: 60)
  end

  def init(_args) do
    root = TestC1.create(x: 100, y: 100, width: 500, height: 300, children: [
      TestC2.create(x: 100, y: 100, width: 100, height: 100, tags: [:a, :b]),
      TestC3.create(x: 0, y: 0, width: 200, height: 50, tags: [:b, :c])
    ])
    {:ok, root, nil}
  end
end