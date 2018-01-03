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
      def init( el, _ctx) do
        el
      end

      @doc false
      def draw(_ctx, _width, _height, _state) do
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
    %Element{parent|children: children ++ [el]}
  end

  @spec put_back(parent :: t, el :: t) :: t
  def put_back(%Element{children: children} = parent, el) do
    %Element{parent|children: [el | children]}
  end

  @spec put_before(parent :: t, member :: t, el :: t) :: t
  def put_before(%Element{children: children} = parent, member, el) do
    children = Enum.reduce(children, [], fn x, acc ->
      if x == member, do: [el, x | acc], else: [x | acc]
    end)
    %Element{parent|children: Enum.reverse(children)}
  end

  @spec put_after(parent :: t, member :: t, el :: t) :: t
  def put_after(%Element{children: children} = parent, member, el) do
    children = Enum.reduce(children, [], fn x, acc ->
      if x == member, do: [x, el | acc], else: [x | acc]
    end)
    %Element{parent|children: Enum.reverse(children)}
  end

  @spec move_front(parent :: t, el :: t) :: t
  def move_front(%Element{children: children} = parent, el) do
    children = List.delete(children, el)
    %Element{parent|children: children ++ [el]}
  end

  @spec move_back(parent :: t, el :: t) :: t
  def move_back(%Element{children: children} = parent, el) do
    children = List.delete(children, el)
    %Element{parent|children: [el | children]}
  end

  @spec move_before(parent :: t, member :: t, el :: t) :: t
  def move_before(%Element{children: children} = parent, member, el) do
    children = Enum.reduce(children, [], fn x, acc ->
      cond do
        x == member -> [el, x | acc]
        x == el     -> acc
        true        -> [x | acc]
      end
    end)
    %Element{parent|children: Enum.reverse(children)}
  end

  @spec move_after(parent :: t, member :: t, el :: t) :: t
  def move_after(%Element{children: children} = parent, member, el) do
    children = Enum.reduce(children, [], fn x, acc ->
      cond do
        x == member -> [x, el | acc]
        x == el     -> acc
        true        -> [x | acc]
      end
    end)
    %Element{parent|children: Enum.reverse(children)}
  end

  @spec remove(parent :: t, el :: t) :: t
  def remove(%Element{children: children} = parent, el) do
    List.delete(children, el)
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


  # Internals

  @doc false
  def draw(%Element{mod: mod, children: children, width: width, height: height} = el, ctx) do
    _ = ctx
    |> NIF.save()
    |> NIF.setup_element(el)
    |> mod.draw(width, height, el.state)
    _ = draw(children, ctx)
    NIF.restore(ctx)
  end
  def draw(els, ctx) when is_list(els) do
    Enum.map(els, &draw(&1, ctx))
  end

  @doc false
  def handle_events(%Element{children: children} = el, events, ctx) do
    {children, events} = children
    |> Enum.reverse()
    |> handle_events(events, ctx)

    el = %Element{el | children: children}
    el = if el.initialized do
      el
    else
      el = el.mod.init(el, ctx)
      %Element{el|xform: NIF.transform_translate(0, 0), initialized: true}
    end
    {el, events} = Enum.reduce(events, {el, []}, &maybe_apply_event/2)
    {el, Enum.reverse(events)}
  end
  def handle_events(els, events, ctx) when is_list(els) do
    Enum.reduce(els, {[], events}, fn el, {els, evs} ->
      {new_el, new_evs} = handle_events(el, evs, ctx)
      {[new_el | els], new_evs}
    end)
  end

  defp maybe_apply_event(ev, {el, acc}) do
    cond do
      ev.type in ~w(button_press button_release key_press key_release motion scroll)a ->
        inv_xform = NIF.transform_inverse(el.xform)
        {x, y} = NIF.transform_point(inv_xform, ev.abs_x, ev.abs_y)
        if touches?(el, x, y) do
          apply_event(el, %{ev|x: x, y: y}, acc)
        else
          {el, [ev | acc]}
        end

      match?(%Events.Update{}, ev) ->
        apply_event(el, ev, acc)

      match?(%Events.Custom{}, ev) ->
        apply_event(el, ev, acc)

      true ->
        {el, [ev | acc]}
    end
  end

  defp apply_event(el, %Events.Update{} = ev, acc) do
    case el.mod.handle_event(el, ev) do
      :cont ->
        {el, [ev | acc]}
      {:done, new_el} ->
        {new_el, [ev | acc]}
      {:cont, new_el} ->
        {new_el, [ev | acc]}
      :done ->
        {el, [ev | acc]}
        end
  end
  defp apply_event(el, ev, acc) do
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