defmodule Vizi.CanvasView do
  use Vizi.View


  # API

  def start_link(opts \\ []) do
    Vizi.View.start_link(__MODULE__, nil, opts)
  end

  def draw(server, params, fun) when is_function(fun, 4) do
    Vizi.View.cast(server, {:draw, params, fun})
  end

  def animate(server, fun) when is_function(fun, 0) do
    Vizi.View.cast(server, {:animate, fun})
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
    root = root
    |> Vizi.Animation.remove_all()
    |> Vizi.Node.put_params(%{fun: fun, params: params})

    {:noreply, root, state}
  end

  def handle_cast({:animate, fun}, root, state) do
    anim = case fun.() do
      %Vizi.Animation{} = anim ->
        anim
      _bad_return ->
        raise "bad return value from #{inspect fun}, expected an animation"
    end
    root = anim
    |> map_params()
    |> Vizi.Animation.into(root)

    {:noreply, root, state}
  end

  def handle_cast(:remove_animations, root, state) do
    {:noreply, Vizi.Animation.remove_all(root), state}
  end


  # Internal functions

  defp map_params(nil), do: nil
  defp map_params(anim) do
    mapped_values = for {key, value} <- anim.values, into: %{} do
      {{:param, [:params, key]}, value}
    end
    %Vizi.Animation{anim|values: mapped_values, next: map_params(anim.next)}
  end
end