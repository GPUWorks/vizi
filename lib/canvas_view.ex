defmodule Vizi.CanvasView do
  use Vizi.View

  # API

  def start_link(opts \\ []) do
    Vizi.View.start_link(__MODULE__, nil, opts)
  end

  def draw(server, params, fun) do
    Vizi.View.cast(server, {:draw, params, fun})
  end

  def animate(server, anim) do
    Vizi.View.cast(server, {:animate, anim})
  end

  def remove_animations(server) do
    Vizi.View.cast(server, :remove_animations)
  end

  # Root node implementation for CanvasView

  defmodule RootNode do
    use Vizi.Node

    def draw(%{fun: nil}, _width, _height, _ctx) do
      :ok
    end
    def draw(%{fun: fun, params: params}, width, height, ctx) do
      fun.(params, width, height, ctx)
    end
  end

  # Vizi.View callbacks

  def init(_args, width, height) do
    {:ok, Vizi.Node.create(RootNode, %{fun: nil, params: nil}, x: 0, y: 0, width: width, height: height), nil}
  end

  def handle_cast({:draw, params, fun}, root, state) do
    {:noreply, Vizi.Node.put_params(root, %{fun: fun, params: params}), state}
  end

  def handle_cast({:animate, anim}, root, state) do
    root = case anim do
             %Vizi.Animation{} ->
               anim
               |> map_params()
               |> Vizi.Animation.into(root)
             _badarg ->
               raise ArgumentError
           end
    {:noreply, root, state}
  end

  def handle_cast(:remove_animations, root, state) do
    {:noreply, Vizi.Animation.remove_all(root), state}
  end

  defp map_params(nil), do: nil
  defp map_params(anim) do
    mapped_values = for {key, value} <- anim.values, into: %{} do
      {{:param, [:params, key]}, value}
    end
    %Vizi.Animation{anim|values: mapped_values, next: map_params(anim.next)}
  end
end