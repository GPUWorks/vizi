defmodule Vizi.CanvasView do
  use Vizi.View

  # API

  def start_link(opts \\ []) do
    opts = Keyword.merge(opts, redraw_mode: :interval)
    Vizi.View.start_link(__MODULE__, nil, opts)
  end

  def draw(server, params, fun) do
    Vizi.View.cast(server, {:draw, params, fun})
  end

  # Root element implementation for CanvasView

  defmodule RootElement do
    use Vizi.Element

    def draw(%{fun: nil} = params, _width, _height, _ctx) do
      {:ok, params}
    end
    def draw(%{fun: fun, params: params}, width, height, ctx) do
      params = case fun.(params, width, height, ctx) do
        {:ok, params} ->
          params
        bad_return ->
          raise "bad return value from #{inspect fun}: #{inspect bad_return}"
      end
      {:ok, %{fun: fun, params: params}}
    end
  end

  # Vizi.View callbacks

  def init(_args, width, height) do
    {:ok, Vizi.Element.create(RootElement, %{fun: nil, params: nil}, x: 0, y: 0, width: width, height: height), nil}
  end

  def handle_cast({:draw, params, fun}, root, state) do
    {:noreply, Vizi.Element.put_params(root, %{fun: fun, params: params}), state}
  end
end