defmodule Vizi.Node do
  alias Vizi.{Node, Events, NIF, Tween}

  defstruct tags: [],
            x: 0.0,
            y: 0.0,
            width: 0.0,
            height: 0.0,
            children: [],
            scale_x: 1.0,
            scale_y: 1.0,
            skew_x: 0.0,
            skew_y: 0.0,
            rotate: 0.0,
            alpha: 1.0,
            mod: nil,
            params: %{},
            initialized: false,
            animations: [],
            updates: [],
            xform: nil

  @type t :: %Node{
          tags: [tag],
          x: number,
          y: number,
          width: number,
          height: number,
          children: [t],
          scale_x: number,
          scale_y: number,
          skew_x: number,
          skew_y: number,
          rotate: number,
          alpha: number,
          mod: module | nil,
          params: params,
          initialized: boolean,
          animations: [tuple],
          updates: [task_fun],
          xform: Vizi.Canvas.Transform.t() | nil
        }

  @type tag :: term

  @type params :: %{optional(atom) => term}

  @type updates :: [{atom, (term -> term)}]

  @type task_fun :: (params, number, number, Vizi.View.context() -> {:ok, params})

  @typedoc "Option values used by `create/3`"
  @type option ::
          {:tags, [tag]}
          | {:x, number}
          | {:y, number}
          | {:width, number}
          | {:height, number}
          | {:children, [t]}
          | {:scale_x, number}
          | {:scale_y, number}
          | {:skew_x, number}
          | {:skew_y, number}
          | {:rotate, number}
          | {:alpha, number}
          | {:mod, module}
          | {:params, params}

  @typedoc "Options used by `create/3`"
  @type options :: [option]

  @type playback_mode :: :forward | :backward | :alternate | :pingpong
  @type update_fun :: (t -> t)

  @type strkey_kv :: [{String.t(), term}]

  @type kv :: strkey_kv | map | Keyword.t()

  @type animate_option ::
          {:mode, playback_mode} | {:update, update_fun} | {:loop, boolean} | {:replace, boolean}
  @type animate_options :: [animate_option]

  @compile {:inline,
            get_step_values: 5,
            get_target_values: 2,
            maybe_call_update_fun: 2,
            set_values: 5,
            map_values: 3,
            get_next: 1}

  @doc """
  Invoked once before receiving any events, or the `draw/4` function is called.

  This function can be used for setting up fonts, images and other resources that are needed for drawing.
  """
  @callback init(node :: Vizi.Node.t(), ctx :: Vizi.View.context()) :: {:ok, new_el}
            when new_el: Vizi.Node.t()

  @doc """
  Invoked after `Vizi.View.redraw/1` has been called when `redraw_mode` is `:manual`, or after agiven interval has passed when `redraw_mode` is `:interval`.

  """
  @callback draw(params :: params, width :: number, height :: number, ctx :: Vizi.View.context()) ::
              term

  @doc """
  Invoked when an event is send to the view.

  The event can be an input event like a mouse button event or a custom event.
  When the callback returns `:cont` or `{:cont, new_view}`, the custom event will be propagated the next node.
  When the callback returns `:done` or `{:done, new_view}` event propagation will stop and no other node will recieve the event anymore.
  """
  @callback handle_event(event :: struct, node :: Vizi.Node.t()) ::
              :cont
              | :done
              | {:done, new_el}
              | {:cont, new_el}
            when new_el: Vizi.Node.t()

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
      def handle_event(_event, _el) do
        :cont
      end

      defoverridable init: 2, draw: 4, handle_event: 2
    end
  end

  # Public interface

  @doc """
  Creates a new node.

  The first argument is a module that has the Node behaviour implemented.
  """
  @spec new(mod :: module, opts :: options) :: t
  def new(mod, opts \\ []) do
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
      params: %{}
    }
  end

  @spec put_front(parent :: t, node :: t) :: t
  def put_front(%Node{children: children} = parent, node) do
    children = List.delete(children, node)
    %Node{parent | children: children ++ [node]}
  end

  @spec put_back(parent :: t, node :: t) :: t
  def put_back(%Node{children: children} = parent, node) do
    children = List.delete(children, node)
    %Node{parent | children: [node | children]}
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
    put_fun =
      case op do
        :before -> fn acc -> [node, member | acc] end
        :after -> fn acc -> [member, node | acc] end
      end

    {_del, put, children} =
      Enum.reduce(parent.children, {false, false, []}, fn x, {del, put, acc} ->
        cond do
          not put and x == member -> {del, true, put_fun.(acc)}
          not del and x == node -> {true, put, acc}
          true -> {del, put, [x | acc]}
        end
      end)

    if put,
      do: %Node{parent | children: Enum.reverse(children)},
      else: parent
  end

  @spec remove(parent :: t, node :: t) :: t
  def remove(%Node{children: children} = parent, node) do
    children = Enum.filter(children, &(&1 != node))
    %Node{parent | children: children}
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
      [] -> nil
      _ -> :error
    end
  end

  @spec update_all(parent :: t, tags :: tag | [tag], function) :: t
  def update_all(%Node{children: children} = parent, tags, fun) do
    tags = List.wrap(tags)

    children =
      for x <- children do
        if Enum.all?(tags, &(&1 in x.tags)), do: fun.(x), else: x
      end

    %Node{parent | children: children}
  end

  @spec update_any(parent :: t, tags :: tag | [tag], function) :: t
  def update_any(%Node{children: children} = parent, tags, fun) do
    tags = List.wrap(tags)

    children =
      for x <- children do
        if Enum.any?(tags, &(&1 in x.tags)), do: fun.(x), else: x
      end

    %Node{parent | children: children}
  end

  @spec put_param(node :: t, key :: atom, value :: term) :: t
  def put_param(%Node{params: params} = node, key, value) do
    %Node{node | params: Map.put(params, key, value)}
  end

  @spec merge_params(node :: t, params :: params) :: t
  def merge_params(%Node{} = node, params) do
    %Node{node | params: Map.merge(node.params, params)}
  end

  @spec update_param(node :: t, key :: atom, initial :: term, fun :: (term -> term)) :: t
  def update_param(%Node{params: params} = node, key, initial, fun) do
    %Node{node | params: Map.update(params, key, initial, fun)}
  end

  @spec update_param!(node :: t, key :: atom, fun :: (term -> term)) :: t
  def update_param!(%Node{params: params} = node, key, fun) do
    %Node{node | params: Map.update!(params, key, fun)}
  end

  @spec update_params!(node :: t, updates) :: t
  def update_params!(%Node{params: params} = node, updates) do
    params =
      Enum.reduce(updates, params, fn {key, fun}, acc ->
        Map.update!(acc, key, fun)
      end)

    %Node{node | params: params}
  end

  @spec update_attributes(node :: t, updates) :: t
  def update_attributes(node, updates) do
    Enum.reduce(updates, node, fn {key, fun}, acc ->
      Map.update!(acc, key, fun)
    end)
  end

  @spec animate(t, Tween.t(), animate_options) :: t
  def animate(node, tween, opts \\ []) do
    anim = to_anim(tween, node, opts)

    tag = Keyword.get(opts, :tag)
    replace = Keyword.get(opts, :replace, true)

    anims =
      if is_nil(tag),
        do: node.animations ++ [anim],
        else: ensure_uniq(node.animations, anim, tag, replace)

    %Node{node | animations: anims}
  end

  @spec remove_animation(t, tag) :: t
  def remove_animation(%Node{animations: anims} = node, tag) do
    anims = Enum.filter(anims, fn {_, {atag, _, _, _}} -> atag != tag end)
    %Node{node | animations: anims}
  end

  @spec remove_all_animations(t) :: t
  def remove_all_animations(node) do
    %Node{node | animations: []}
  end

  @spec add_update(node :: t, task_fun) :: t
  def add_update(node, fun) do
    %Node{node | updates: node.updates ++ [fun]}
  end

  # Internals

  # Update handling

  @doc false
  def update(node, parent_xform, ctx) when is_map(node) do
    %Node{
      width: width,
      height: height,
      params: params,
      mod: mod,
      children: children,
      xform: xform
    } =
      node =
      node
      |> maybe_init(ctx)
      |> maybe_execute_updates(ctx)
      |> step_animations()

    NIF.setup_node(ctx, parent_xform, node)
    mod.draw(params, width, height, ctx)
    children = update(children, xform, ctx)

    %Node{node | children: children}
  end

  def update(els, parent_xform, ctx) do
    Enum.map(els, &update(&1, parent_xform, ctx))
  end

  defp maybe_init(%Node{initialized: false} = node, ctx) do
    case node.mod.init(node, ctx) do
      {:ok, node} ->
        %Node{node | xform: NIF.transform_identity(ctx), initialized: true}

      bad_return ->
        raise "bad return value from #{inspect(node.mod)}.init/2: #{inspect(bad_return)}"
    end
  end

  defp maybe_init(node, _ctx), do: node

  defp maybe_execute_updates(%Node{updates: []} = node, _ctx) do
    node
  end

  defp maybe_execute_updates(%Node{width: width, height: height, updates: updates} = node, ctx) do
    params =
      Enum.reduce(updates, node.params, fn task, acc ->
        case task.(acc, width, height, ctx) do
          {:ok, params} ->
            params

          bad_return ->
            raise "bad return value from task #{inspect(task)}: #{inspect(bad_return)}"
        end
      end)

    %Node{node | params: params, updates: []}
  end

  # Event handling

  @doc false
  def handle_events(events, %Node{} = node, ctx) do
    {node, events} = Enum.reduce(events, {node, []}, &maybe_handle_event/2)
    {children, events} = handle_events(Enum.reverse(events), node.children, ctx)
    {%Node{node | children: children}, events}
  end

  def handle_events(events, els, ctx) when is_list(els) do
    {els, events} =
      Enum.reduce(els, {[], events}, fn node, {els, evs} ->
        {new_el, new_evs} = handle_events(evs, node, ctx)
        {[new_el | els], new_evs}
      end)

    {Enum.reverse(els), events}
  end

  defp maybe_handle_event(%Events.Custom{} = ev, {%Node{initialized: true} = node, acc}) do
    handle_event(node, ev, acc)
  end

  defp maybe_handle_event(%{type: type} = ev, {%Node{initialized: true} = node, acc})
       when type in ~w(button_press button_release key_press key_release motion scroll)a do
    inv_xform = NIF.transform_inverse(node.xform)
    {x, y} = NIF.transform_point(inv_xform, ev.abs_x, ev.abs_y)

    if touches?(node, x, y),
      do: handle_event(%{ev | x: x, y: y}, node, acc),
      else: {node, [ev | acc]}
  end

  defp maybe_handle_event(ev, {node, acc}) do
    {node, [ev | acc]}
  end

  defp handle_event(ev, node, acc) do
    case node.mod.handle_event(ev, node) do
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

  # Animations

  @doc false
  def step_animations(%Node{animations: []} = node) do
    node
  end

  def step_animations(%Node{animations: anims} = node) do
    case anims do
      [anim] ->
        case step_anim(anim) do
          :done ->
            %Node{node | animations: []}

          {attrs, params, anim} ->
            set_values(node, attrs, params, anim, [])
        end

      _anims ->
        Enum.reduce(anims, %Node{node | animations: []}, fn anim, acc ->
          case step_anim(anim) do
            :done ->
              acc

            {attrs, params, anim} ->
              set_values(acc, attrs, params, anim, acc.animations)
          end
        end)
    end
  end

  defp step_anim({{step, {attrs, params, dir, length, fun} = props}, aprops}) do
    if step == length do
      a = get_target_values(attrs, dir)
      p = get_target_values(params, dir)
      {anim, aprops} = get_next(aprops)
      {a, p, {anim, aprops}}
    else
      a = get_step_values(attrs, length, step, fun, dir)
      p = get_step_values(params, length, step, fun, dir)
      {a, p, {{step + 1, props}, aprops}}
    end
  end

  defp step_anim({nil, {_tag, nil, _update_fun, _rest}}), do: :done

  defp step_anim({nil, aprops}) do
    {anim, aprops} =
      aprops
      |> put_elem(3, elem(aprops, 1))
      |> get_next()

    step_anim({anim, aprops})
  end

  defp get_next(aprops) do
    case aprops do
      {_, _, _, [anim | rest]} ->
        {anim, put_elem(aprops, 3, rest)}

      {_, _, _, []} ->
        {nil, aprops}
    end
  end

  defp get_step_values(values, length, step, fun, dir) do
    if values == [] do
      %{}
    else
      step = if dir == :backward, do: length - step, else: step
      for {key, from, delta} <- values, into: %{}, do: {key, fun.(from, delta, length, step)}
    end
  end

  defp get_target_values(values, dir) do
    if values == [] do
      %{}
    else
      if dir == :backward do
        for {key, from, _delta} <- values, into: %{}, do: {key, from}
      else
        for {key, from, delta} <- values, into: %{}, do: {key, from + delta}
      end
    end
  end

  defp set_values(node, attrs, params, anim, anims) do
    node = if attrs == %{}, do: node, else: Map.merge(node, attrs)
    params = if params == %{}, do: node.params, else: Map.merge(node.params, params)
    node = %Node{node | params: params, animations: [anim | anims]}
    maybe_call_update_fun(node, anim)
  end

  defp maybe_call_update_fun(node, anim) do
    case anim do
      {_, {_, _, nil, _}} ->
        node

      {_, {_, _, fun, _}} ->
        fun.(node)
    end
  end

  defp to_anim(tween, node, opts) do
    [anim | rest] =
      build_anim(tween, node)
      |> set_mode(Keyword.get(opts, :mode, :forward))

    tag = Keyword.get(opts, :tag)
    loop = if Keyword.get(opts, :loop), do: [anim | rest]
    update_fun = Keyword.get(opts, :update)

    {anim, {tag, loop, update_fun, rest}}
  end

  defp build_anim(
         %Tween{attrs: attrs, params: params, length: length, easing: easing, next: next},
         node
       ) do
    attrs = map_values(attrs, node, length)
    params = map_values(params, node.params, length)
    node = update_for_next(node, attrs, params)
    length = if length == 0, do: 1, else: length
    [{1, {attrs, params, :forward, length, easing}} | build_anim(next, node)]
  end

  defp build_anim(nil, _node), do: []

  defp map_values(map, values, 0) do
    Enum.map(map, fn
      {key, {:add, x}} ->
        {key, Map.get(values, key, 0) + x, 0}

      {key, {:sub, x}} ->
        {key, Map.get(values, key, 0) - x, 0}

      {key, to} ->
        {key, to, 0}
    end)
  end

  defp map_values(map, values, _length) do
    Enum.map(map, fn
      {key, {:add, x}} ->
        {key, Map.get(values, key, 0), x}

      {key, {:sub, x}} ->
        {key, Map.get(values, key, 0), -x}

      {key, to} ->
        from = Map.get(values, key, 0)
        {key, from, to - from}
    end)
  end

  defp update_for_next(node, attrs, params) do
    node =
      Enum.reduce(attrs, node, fn {key, from, delta}, acc ->
        Map.put(acc, key, from + delta)
      end)

    params =
      Enum.reduce(params, node.params, fn {key, from, delta}, acc ->
        Map.put(acc, key, from + delta)
      end)

    %Node{node | params: params}
  end

  defp set_mode(anim, mode) do
    case mode do
      :forward ->
        set_initial_values(anim)

      :backward ->
        set_anim_backward(anim)

      :pingpong ->
        set_anim_pingpong(anim)

      :alternate ->
        set_anim_alternate(anim)
    end
  end

  defp set_anim_backward(anim) do
    anim
    |> backward()
    |> set_initial_values()
  end

  defp set_anim_pingpong(anim) do
    anim ++ backward(anim)
  end

  defp set_anim_alternate(anim) do
    anim ++ reverse(anim, [])
  end

  defp backward(anim) do
    for {step, props} <- Enum.reverse(anim) do
      {step, put_elem(props, 2, :backward)}
    end
  end

  defp reverse([{step, {attrs, params, dir, length, fun}} | rest], acc) do
    reverse(rest, [{step, {swap_values(attrs), swap_values(params), dir, length, fun}} | acc])
  end

  defp reverse([], acc) do
    acc
  end

  defp swap_values(values) do
    for {key, from, delta} <- values do
      {key, from + delta, -delta}
    end
  end

  defp set_initial_values(anim) do
    {attrs, params} = collect_initial_values(anim, [], [])
    [{1, {attrs, params, :forward, 1, &Vizi.Tween.easing_lin/4}} | anim]
  end

  defp collect_initial_values([{_, {attrs, params, dir, _, _}} | rest], a_acc, p_acc) do
    a_acc = extract_initial_values(a_acc, attrs, dir)
    p_acc = extract_initial_values(p_acc, params, dir)
    collect_initial_values(rest, a_acc, p_acc)
  end

  defp collect_initial_values([], a_acc, p_acc) do
    {a_acc, p_acc}
  end

  defp extract_initial_values(acc, values, :forward) do
    Enum.reduce(values, acc, fn {key, from, _delta}, acc ->
      put_new_value(acc, key, from)
    end)
  end

  defp extract_initial_values(acc, values, :backward) do
    Enum.reduce(values, acc, fn {key, from, delta}, acc ->
      put_new_value(acc, key, from + delta)
    end)
  end

  defp put_new_value(list, key, value) do
    if List.keymember?(list, key, 0),
      do: list,
      else: [{key, value, 0} | list]
  end

  defp ensure_uniq(anims, anim, tag, replace) do
    {flag, anims} =
      Enum.reduce(anims, {replace, []}, fn {_, {atag, _, _, _}} = a, {flag, acc} ->
        cond do
          flag and replace and atag == tag ->
            {!flag, [anim | acc]}

          !(flag or replace) and atag == tag ->
            {!flag, [a | acc]}

          true ->
            {flag, [a | acc]}
        end
      end)

    cond do
      replace and flag ->
        [anim | anims]

      !(replace or flag) ->
        [anim | anims]

      true ->
        anims
    end
    |> Enum.reverse()
  end
end
