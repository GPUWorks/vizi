defmodule Vizi.CanvasView do
  use Vizi.View


  # API

  def start_link(opts \\ []) do
    Vizi.View.start_link(__MODULE__, nil, opts)
  end

  def draw(server, params, fun) when is_function(fun, 4) do
    Vizi.View.cast(server, {:draw, params, fun})
  end

  def animate(server, mode \\ :once, fun) when is_function(fun, 0) do
    Vizi.View.cast(server, {:animate, mode, fun})
  end

  def remove_animations(server) do
    Vizi.View.cast(server, :remove_animations)
  end


  # Root node implementation for CanvasView

  defmodule RootNode do
    use Vizi.Node

    def draw(%{__draw_fun__: nil}, _width, _height, _ctx) do
      :ok
    end
    def draw(params, width, height, ctx) do
      {fun, params} = Map.pop(params, :__draw_fun__)
      fun.(params, width, height, ctx)
    end
  end


  # Vizi.View callbacks

  def init(_args, width, height) do
    {:ok, Vizi.Node.create(RootNode, %{__draw_fun__: nil}, x: 0, y: 0, width: width, height: height), nil}
  end

  def handle_cast({:draw, params, fun}, root, state) do
    root = Vizi.Node.remove_animations(root)

    {:noreply, %Vizi.Node{root|params: Map.put(params, :__draw_fun__, fun)}, state}
  end

  def handle_cast({:animate, mode, fun}, root, state) do
    root = case fun.() do
      %Vizi.Tween{} = tween ->
        Vizi.Node.animate(root, tween, mode: mode)
      _bad_return ->
        raise "bad return from #{inspect fun}, expected a tween."
    end
    {:noreply, root, state}
  end

  def handle_cast(:remove_animations, root, state) do
    {:noreply, Vizi.Node.remove_animations(root), state}
  end
end