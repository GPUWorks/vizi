defmodule Vizi.Node do
  alias Vizi.{Node, Events, NIF}

  defstruct tags: [],
            x: 0.0, y: 0.0,
            width: 0.0, height: 0.0,
            children: [],
            scale_x: 1.0, scale_y: 1.0,
            skew_x: 0.0, skew_y: 0.0,
            rotate: 0.0, alpha: 1.0,
            mod: nil, params: %{},
            initialized: false,
            animations: [],
            tasks: [],
            xform: nil

  @type t :: %Vizi.Node{
    tags: [tag],
    x: number, y: number,
    width: number, height: number,
    children: [t],
    scale_x: number, scale_y: number,
    skew_x: number, skew_y: number,
    rotate: number, alpha: number,
    mod: module | nil, params: params,
    initialized: boolean,
    animations: [Vizi.Animation.t],
    tasks: [task_fun],
    xform: Vizi.Canvas.Transform.t | nil
  }

  @type tag :: term

  @type params :: %{optional(atom) => term}

  @type updates :: [{atom, (term -> term)}]

  @type task_fun :: (params, number, number, Vizi.View.context -> {:ok, params})

  @typedoc "Option values used by `create/3`"
  @type option :: {:tags, [tag]} |
                  {:x, number} |
                  {:y, number} |
                  {:width, number} |
                  {:height, number} |
                  {:children, [t]} |
                  {:scale_x, number} |
                  {:scale_y, number} |
                  {:skew_x, number} |
                  {:skew_y, number} |
                  {:rotate, number} |
                  {:alpha, number} |
                  {:mod, module} |
                  {:params, params}



  @typedoc "Options used by `create/3`"
  @type options :: [option]

  @doc """
  Invoked once before receiving any events, or the `draw/4` function is called.

  This function can be used for setting up fonts, images and other resources that are needed for drawing.
  """
  @callback init(node :: Vizi.Node.t, ctx :: Vizi.View.context) ::
  {:ok, new_el} when new_el: Vizi.Node.t

  @doc """
  Invoked after `Vizi.View.redraw/1` has been called when `redraw_mode` is `:manual`, or automatically when `redraw_mode` is `:interval`.

  """
  @callback draw(params :: params, width :: number, height :: number, ctx :: Vizi.View.context) :: term

  @callback handle_event(node :: Vizi.Node.t, event :: struct) ::
  :cont | :done |
  {:done, new_el} |
  {:cont, new_el} when new_el: Vizi.Node.t

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Vizi.Node

      @doc false
      def init(node, _ctx) do
        {:ok, node}
      end

      @doc false
      def draw(_params, _width, _height, _ctx) do
        :ok
      end

      @doc false
      def handle_event(_el, _event) do
        :cont
      end

      defoverridable [init: 2, draw: 4, handle_event: 2]
    end
  end


  # Public interface

  @spec create(mod :: module, params :: params, opts :: options) :: t
  def create(mod, params, opts \\ []) do
    %Node{
      tags: Keyword.get(opts, :tags, []),
      x: Keyword.get(opts, :x, 0.0),
      y: Keyword.get(opts, :y, 0.0),
      width: Keyword.get(opts, :width, 0.0),
      height: Keyword.get(opts, :height, 0.0),
      children: Keyword.get(opts, :children, []),
      scale_x: Keyword.get(opts, :scale_x, 1.0),
      scale_y: Keyword.get(opts, :scale_y, 1.0),
      skew_x: Keyword.get(opts, :skew_x, 0.0),
      skew_y: Keyword.get(opts, :skew_y, 0.0),
      rotate: Keyword.get(opts, :rotate, 0.0),
      alpha: Keyword.get(opts, :alpha, 1.0),
      mod: mod,
      params: params
    }
  end

  @spec put_front(parent :: t, node :: t) :: t
  def put_front(%Node{children: children} = parent, node) do
    children = List.delete(children, node)
    %Node{parent|children: children ++ [node]}
  end

  @spec put_back(parent :: t, node :: t) :: t
  def put_back(%Node{children: children} = parent, node) do
    children = List.delete(children, node)
    %Node{parent|children: [node | children]}
  end

  @spec put_before(parent :: t, member :: t, node :: t) :: t
  def put_before(%Node{} = parent, member, node) do
    put_ba(parent, :before, member, node)
  end

  @spec put_after(parent :: t, member :: t, node :: t) :: t
  def put_after(%Node{} = parent, member, node) do
    put_ba(parent, :after, member, node)
  end

  defp put_ba(parent, op, member, node) do
    put_fun = case op do
      :before -> fn acc -> [node, member | acc] end
      :after  -> fn acc -> [member, node | acc] end
    end

    {_del, put, children} = Enum.reduce(parent.children, {false, false, []}, fn x, {del, put, acc} ->
      cond do
        not put and x == member -> {del, true, put_fun.(acc)}
        not del and x == node     -> {true, put, acc}
        true                    -> {del, put, [x | acc]}
      end
    end)

    if put do
      %Node{parent|children: Enum.reverse(children)}
    else
      parent
    end
  end

  @spec remove(parent :: t, node :: t) :: t
  def remove(%Node{children: children} = parent, node) do
    children = Enum.filter(children, &(&1 != node))
    %Node{parent|children: children}
  end

  @spec all(parent :: t, tags :: tag | [tag]) :: [t]
  def all(%Node{children: children}, tags) do
    tags = List.wrap(tags)
    Enum.filter(children, fn x ->
      Enum.all?(tags, &(&1 in x.tags))
    end)
  end

  @spec any(parent :: t, tags :: tag | [tag]) :: [t]
  def any(%Node{children: children}, tags) do
    tags = List.wrap(tags)
    Enum.filter(children, fn x ->
      Enum.any?(tags, &(&1 in x.tags))
    end)
  end

  @spec one(parent :: t, tags :: tag | [tag]) :: {:ok, t} | nil | :error
  def one(%Node{} = parent, tags) do
    case all(parent, tags) do
      [node] -> {:ok, node}
      []   -> nil
      _    -> :error
    end
  end

  @spec update_all(parent :: t, tags :: tag | [tag], function) :: t
  def update_all(%Node{children: children} = parent, tags, fun) do
    tags = List.wrap(tags)
    children = for x <- children do
      if Enum.all?(tags, &(&1 in x.tags)) do
        fun.(x)
      else
        x
      end
    end
    %Node{parent|children: children}
  end

  @spec update_any(parent :: t, tags :: tag | [tag,], function) :: t
  def update_any(%Node{children: children} = parent, tags, fun) do
    tags = List.wrap(tags)
    children = for x <- children do
      if Enum.any?(tags, &(&1 in x.tags)) do
        fun.(x)
      else
        x
      end
    end
    %Node{parent|children: children}
  end

  @spec put_param(node :: t, key :: atom, value :: term) :: t
  def put_param(%Node{params: params} = node, key, value) do
    %Node{node|params: Map.put(params, key, value)}
  end

  @spec put_params(node :: t, params :: params) :: t
  def put_params(%Node{} = node, params) do
    %Node{node|params: Map.merge(node.params, params)}
  end

  @spec update_param(node :: t, key :: atom, initial :: term, fun :: (term -> term)) :: t
  def update_param(%Node{params: params} = node, key, initial, fun) do
    %Node{node|params: Map.update(params, key, initial, fun)}
  end

  @spec update_param!(node :: t, key :: atom, fun :: (term -> term)) :: t
  def update_param!(%Node{params: params} = node, key, fun) do
    %Node{node|params: Map.update!(params, key, fun)}
  end

  @spec update_params!(node :: t, updates) :: t
  def update_params!(%Node{params: params} = node, updates) do
    params = Enum.reduce(updates, params, fn {key, fun}, acc ->
      Map.update!(acc, key, fun)
    end)
    %Node{node|params: params}
  end

  @spec update_attributes(node :: t, updates) :: t
  def update_attributes(node, updates) do
    Enum.reduce(updates, node, fn {key, fun}, acc ->
      Map.update!(acc, key, fun)
    end)
  end

  @spec add_task(node :: t, task_fun) :: t
  def add_task(node, fun) do
    %Node{node|tasks: node.tasks ++ [fun]}
  end

  # Internals

  @doc false
  def update(%Node{mod: mod} = node, ctx) do
    NIF.save(ctx)

    node = node
    |> maybe_init(ctx)
    |> maybe_execute_tasks(ctx)
    |> maybe_animate()

    NIF.setup_node(ctx, node)
    mod.draw(node.params, node.width, node.height, ctx)
    children = update(node.children, ctx)

    NIF.restore(ctx)

    %Node{node|children: children}
  end
  def update(els, ctx) when is_list(els) do
    Enum.map(els, &update(&1, ctx))
  end

  defp maybe_init(%Node{initialized: false} = node, ctx) do
    case node.mod.init(node, ctx) do
      {:ok, node} ->
        %Node{node|xform: NIF.transform_translate(0, 0), initialized: true}
      bad_return ->
        raise "bad return value from #{inspect node.mod}.init/2: #{inspect bad_return}"
    end
  end
  defp maybe_init(node, _ctx), do: node

  defp maybe_execute_tasks(%Node{tasks: []} = node, _ctx) do
    node
  end
  defp maybe_execute_tasks(%Node{width: width, height: height, tasks: tasks} = node, ctx) do
    params = Enum.reduce(tasks, node.params, fn task, acc ->
      case task.(acc, width, height, ctx) do
        {:ok, params} ->
          params
        bad_return ->
          raise "bad return value from task #{inspect task}: #{inspect bad_return}"
      end
    end)
    %Node{node|params: params, tasks: []}
  end

  defp maybe_animate(%Node{animations: []} = node) do
    node
  end
  defp maybe_animate(node) do
    Vizi.Animation.step(node)
  end

  @doc false
  def handle_events(%Node{} = node, events, ctx) do

    {node, events} = Enum.reduce(events, {node, []}, &maybe_handle_event/2)
    {children, events} = handle_events(node.children, Enum.reverse(events), ctx)
    {%Node{node | children: children}, events}
  end
  def handle_events(els, events, ctx) when is_list(els) do
    {els, events} = Enum.reduce(els, {[], events}, fn node, {els, evs} ->
      {new_el, new_evs} = handle_events(node, evs, ctx)
      {[new_el | els], new_evs}
    end)
    {Enum.reverse(els), events}
  end

  defp maybe_handle_event(%Events.Custom{} = ev, {node, acc}) do
    handle_event(node, ev, acc)
  end
  defp maybe_handle_event(%{type: type} = ev, {node, acc})
  when type in ~w(button_press button_release key_press key_release motion scroll)a do
    inv_xform = NIF.transform_inverse(node.xform)
    {x, y} = NIF.transform_point(inv_xform, ev.abs_x, ev.abs_y)
    if touches?(node, x, y) do
      handle_event(node, %{ev|x: x, y: y}, acc)
    else
      {node, [ev | acc]}
    end
  end
  defp maybe_handle_event(ev, {node, acc}) do
    {node, [ev | acc]}
  end

  defp handle_event(node, ev, acc) do
    case node.mod.handle_event(node, ev) do
      :cont ->
        {node, [ev | acc]}
      {:done, new_el} ->
        {new_el, acc}
      {:cont, new_el} ->
        {new_el, [ev | acc]}
      :done ->
        {node, acc}
    end
  end

  defp touches?(%Node{width: width, height: height}, x, y) do
    x >= 0 and x <= width and y >= 0 and y <= height
  end
end