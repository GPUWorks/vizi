alias Vizi.Events

defmodule TestC1 do
  @moduledoc false
  use Vizi.Element
  use Vizi.Canvas

  def create(opts) do
    Vizi.Element.create(__MODULE__, %{img: nil, bm: nil, cnt: 1}, opts)
  end

  def init(ctx, state) do
    bm = Bitmap.create(500, 300)
    Enum.each(0..(Bitmap.size(bm) - 1), fn n ->
      Bitmap.put(bm, n, rem(n, 256), 255 - rem(n, 256), 0, 255)
    end)
    img = Image.from_bitmap(ctx, bm)
    state = put_in(state.img, img)
    {:ok, put_in(state.bm, bm)}
  end

  def draw(ctx, width, height, state) do
    img = Image.create(ctx, "c_src/nanovg/example/images/image#{state.cnt}.jpg", [:repeat_x, :repeat_y])
    paint = Paint.image_pattern(ctx, 0, 0, 100, 100, 45, img)

    ctx
    |> begin_path()
    |> rect(0, 0, width, height)
    |> fill_paint(paint)
    |> fill()
    {:ok, state}
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
    |> fill_color(rgba(state.angle, 255, 255))
    |> fill()
    |> translate(50, 50)
    |> rotate(deg_to_rad(state.angle))
    |> translate(-50, -50)
    |> begin_path()
    |> rect(40, 40, 20, 20)
    |> fill_color(rgba(0, 0, 255))
    |> fill()

    state = update_in(state.angle, fn a -> if a == 359, do: 0, else: a + 1 end)
    {:ok, state}
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

  def init(ctx, _state) do
    font = Text.create_font(ctx, "/home/zambal/dev/vizi/c_src/nanovg/example/Roboto-Light.ttf")
    {:ok, %{font: font, color: rgba(255, 0, 0, 255)}}
  end

  def draw(ctx, _width, _height, state) do
    ctx
    |> font_face(state.font)
    |> font_size(48.0)
    |> fill_color(state.color)
    |> text(0, 40, "Hello World!")

    {:ok, state}
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
    root = TestC1.create(x: 100, y: 100, width: 500, height: 300, children:
      for n <- 1..100 do
        TestC2.create(x: n + 100, y: n + 100, width: 100, height: 100, alpha: 0.3, tags: [:a, :b])
      end
    )
    {:ok, root, nil}
  end
end