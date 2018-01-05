defmodule Vizi.Element do
  alias Vizi.{Element, Events, NIF}

  defstruct tags: [],
            x: 0.0, y: 0.0,
            width: 0.0, height: 0.0,
            children: [],
            scale_x: 1.0, scale_y: 1.0,
            skew_x: 0.0, skew_y: 0.0,
            rotate: 0.0, alpha: 1.0,
            mod: nil, state: nil,
            initialized: false,
            xform: nil

  @type t :: %Vizi.Element{
    tags: [tag],
    x: number, y: number,
    width: number, height: number,
    children: [t],
    scale_x: number, scale_y: number,
    skew_x: number, skew_y: number,
    rotate: number, alpha: number,
    mod: module | nil, state: term,
    initialized: boolean,
    xform: Vizi.Canvas.Transform.t | nil
  }

  @type tag :: term

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
                  {:x, number} |
                  {:mod, module} |
                  {:state, term}



  @typedoc "Options used by `create/3`"
  @type options :: [option]

  @doc """
  Invoked once before receiving any events, or the `draw/4` function is called.

  This function can be used for setting up fonts, images and other resources that are needed for drawing.
  """
  @callback init(el :: Vizi.Element.t, ctx :: Vizi.View.context) ::
  new_el when new_el: Vizi.Element.t

  @doc """
  Invoked after `Vizi.View.redraw/1` has been called when `redraw_mode` is `:manual`, or automatically when `redraw_mode` is `:interval`.


  """
  @callback draw(ctx :: Vizi.View.context, width :: number, height :: number, state :: term) :: term

  @callback handle_event(el :: Vizi.Element.t, event :: struct) ::
  :cont | :done |
  {:done, new_el} |
  {:cont, new_el} when new_el: Vizi.Element.t

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Vizi.Element

      @doc false
      def init(_ctx, state) do
        {:ok, state}
      end

      @doc false
      def draw(_ctx, _width, _height, state) do
        {:ok, state}
      end

      @doc false
      def handle_event(_el, _event) do
        :cont
      end

      defoverridable [init: 2, draw: 4, handle_event: 2]
    end
  end


  # Public interface

  @spec create(mod :: module, state :: term, opts :: options) :: t
  def create(mod, state, opts \\ []) do
    %Element{
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
      state: state
    }
  end

  @spec put_front(parent :: t, el :: t) :: t
  def put_front(%Element{children: children} = parent, el) do
    children = List.delete(children, el)
    %Element{parent|children: children ++ [el]}
  end

  @spec put_back(parent :: t, el :: t) :: t
  def put_back(%Element{children: children} = parent, el) do
    children = List.delete(children, el)
    %Element{parent|children: [el | children]}
  end

  @spec put_before(parent :: t, member :: t, el :: t) :: t
  def put_before(%Element{} = parent, member, el) do
    put_ba(parent, :before, member, el)
  end

  @spec put_after(parent :: t, member :: t, el :: t) :: t
  def put_after(%Element{} = parent, member, el) do
    put_ba(parent, :after, member, el)
  end

  defp put_ba(parent, op, member, el) do
    put_fun = case op do
      :before -> fn acc -> [el, member | acc] end
      :after  -> fn acc -> [member, el | acc] end
    end

    {_del, put, children} = Enum.reduce(parent.children, {false, false, []}, fn x, {del, put, acc} ->
      cond do
        not put and x == member -> {del, true, put_fun.(acc)}
        not del and x == el     -> {true, put, acc}
        true                    -> {del, put, [x | acc]}
      end
    end)

    if put do
      %Element{parent|children: Enum.reverse(children)}
    else
      parent
    end
  end

  @spec remove(parent :: t, el :: t) :: t
  def remove(%Element{children: children} = parent, el) do
    children = Enum.filter(children, &(&1 != el))
    %Element{parent|children: children}
  end

  @spec all(parent :: t, tags :: tag | [tag]) :: [t]
  def all(%Element{children: children}, tags) do
    tags = List.wrap(tags)
    Enum.filter(children, fn x ->
      Enum.all?(tags, &(&1 in x.tags))
    end)
  end

  @spec any(parent :: t, tags :: tag | [tag]) :: [t]
  def any(%Element{children: children}, tags) do
    tags = List.wrap(tags)
    Enum.filter(children, fn x ->
      Enum.any?(tags, &(&1 in x.tags))
    end)
  end

  @spec one(parent :: t, tags :: tag | [tag]) :: {:ok, t} | nil | :error
  def one(%Element{} = parent, tags) do
    case all(parent, tags) do
      [el] -> {:ok, el}
      []   -> nil
      _    -> :error
    end
  end

  @spec update_all(parent :: t, tags :: tag | [tag], function) :: [t]
  def update_all(%Element{children: children}, tags, fun) do
    tags = List.wrap(tags)
    for x <- children do
      if Enum.all?(tags, &(&1 in x.tags)) do
        fun.(x)
      else
        x
      end
    end
  end

  @spec update_any(parent :: t, tags :: tag | [tag,], function) :: [t]
  def update_any(%Element{children: children}, tags, fun) do
    tags = List.wrap(tags)
    for x <- children do
      if Enum.any?(tags, &(&1 in x.tags)) do
        fun.(x)
      end
    end
  end

  # Internals

  @doc false
  def draw(%Element{mod: mod, children: children, width: width, height: height} = el, ctx) do
    el = maybe_init(el, ctx)
    state = ctx
    |> NIF.save()
    |> NIF.setup_element(el)
    |> mod.draw(width, height, el.state)
    |> case do
      {:ok, state} ->
        state
      bad_return ->
        raise "bad return value from #{inspect el.mod}.draw/4: #{inspect bad_return}"
    end
    children = draw(children, ctx)
    NIF.restore(ctx)
    %Element{el|children: children, state: state}
  end
  def draw(els, ctx) when is_list(els) do
    Enum.map(els, &draw(&1, ctx))
  end

  defp maybe_init(%Element{initialized: false} = el, ctx) do
    case el.mod.init(ctx, el.state) do
      {:ok, state} ->
        %Element{el|state: state, xform: NIF.transform_translate(0, 0), initialized: true}
      bad_return ->
        raise "bad return value from #{inspect el.mod}.init/2: #{inspect bad_return}"
    end
  end
  defp maybe_init(el, _ctx), do: el

  @doc false
  def handle_events(%Element{} = el, events, ctx) do

    {el, events} = Enum.reduce(events, {el, []}, &maybe_handle_event/2)
    {children, events} = handle_events(el.children, Enum.reverse(events), ctx)
    {%Element{el | children: children}, events}
  end
  def handle_events(els, events, ctx) when is_list(els) do
    {els, events} = Enum.reduce(els, {[], events}, fn el, {els, evs} ->
      {new_el, new_evs} = handle_events(el, evs, ctx)
      {[new_el | els], new_evs}
    end)
    {Enum.reverse(els), events}
  end

  defp maybe_handle_event(ev, {el, acc}) do
    cond do
      ev.type in ~w(button_press button_release key_press key_release motion scroll)a ->
        inv_xform = NIF.transform_inverse(el.xform)
        {x, y} = NIF.transform_point(inv_xform, ev.abs_x, ev.abs_y)
        if touches?(el, x, y) do
          handle_event(el, %{ev|x: x, y: y}, acc)
        else
          {el, [ev | acc]}
        end

      match?(%Events.Custom{}, ev) ->
        handle_event(el, ev, acc)

      true ->
        {el, [ev | acc]}
    end
  end

  defp handle_event(el, ev, acc) do
    case el.mod.handle_event(el, ev) do
      :cont ->
        {el, [ev | acc]}
      {:done, new_el} ->
        {new_el, acc}
      {:cont, new_el} ->
        {new_el, [ev | acc]}
      :done ->
        {el, acc}
    end
  end

  defp touches?(%Element{width: width, height: height}, x, y) do
    x >= 0 and x <= width and y >= 0 and y <= height
  end
end