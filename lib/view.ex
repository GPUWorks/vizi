defmodule Vizi.View do
  alias Vizi.{
    Canvas,
    Events,
    Node,
    View
  }

  @compile {:inline,
            put_root: 2,
            update_root: 2,
            get_param: 2,
            get_param: 3,
            put_param: 3,
            merge_params: 2,
            update_param: 4,
            update_param!: 3,
            send_event: 2,
            redraw: 0}

  defstruct name: nil,
            context: nil,
            root: nil,
            width: 0,
            height: 0,
            custom_events: [],
            redraw_mode: :interval,
            identity_xform: nil,
            mod: nil,
            params: %{},
            init_params: nil,
            suspend: :off

  @type name :: term

  @type server :: name | pid

  @type context :: <<>>

  @type redraw_mode :: :manual | :interval

  @type suspend_state :: :off | :requested | :on

  @type params :: %{optional(atom) => term}

  @type updates :: [{atom, (term -> term)}]

  @type t :: %View{
          name: name,
          context: context,
          root: Node.t(),
          width: integer,
          height: integer,
          custom_events: [%Events.Custom{}],
          redraw_mode: redraw_mode,
          identity_xform: Canvas.Transform.t(),
          mod: module,
          params: params,
          init_params: term,
          suspend: suspend_state
        }

  @doc """
  The view's init callback function is invoked after a windows has been succesfully created and the background thread is initialized,
  but before any drawing or events are handled. `start_link/3` or `start/3` will block until it returns.

  It is primarily meant to setup the view's root node.

  See `GenServer.init/1` for more info about the `:ignore` and `{:stop, reason}` return values.
  """
  @callback init(t) ::
              {:ok, Node.t}
              | :ignore
              | {:stop, reason :: term}

  @doc """
  Invoked when an event is send to the view.

  The event can be an input event like a mouse button event or a custom event.

  When the callback returns `:cont` or `{:cont, new_view}`, the custom event will be propagated through all nodes,
  starting at the root node, until a node returns `:done` or `{:done, new_node}`.

  When the callback returns `:done` or `{:done, new_view}` event propagation will stop and no node will recieve the event.
  """
  @callback handle_event(event :: term, t) ::
              :cont
              | :done
              | {:cont, t}
              | {:done, t}

  @doc """
  Invoked to handle synchronous `call/3` messages.

  See `GenServer.handle_call/3` for more info.
  """
  @callback handle_call(request :: term, from :: term, t) ::
              {:reply, reply, t}
              | {:reply, reply, t, timeout | :hibernate}
              | {:noreply, t}
              | {:noreply, t, timeout | :hibernate}
              | {:stop, reason, reply, t}
              | {:stop, reason, t}
            when reply: term, reason: term

  @doc """
  Invoked to handle asynchronous cast/2 messages.

  See `GenServer.handle_cast/2` for more info.
  """
  @callback handle_cast(request :: term, t) ::
              {:noreply, t}
              | {:noreply, t, timeout | :hibernate}
              | {:stop, reason :: term, t}

  @doc """
  Invoked to handle all other messages.

  See `GenServer.handle_info/2` for more info.
  """
  @callback handle_info(msg :: :timeout | term, t) ::
              {:noreply, t}
              | {:noreply, t, timeout | :hibernate}
              | {:stop, reason :: term, t}

  @doc """
  Invoked when the view is about to shutdown. It should do any cleanup required.

  See `GenServer.terminate/2` for more info.
  """
  @callback terminate(reason, t) :: term
            when reason: :normal | :shutdown | {:shutdown, term} | term

  @doc """
  Invoked to change the state of the GenServer when a different version of a module is loaded (hot code swapping)
  and the state’s term structure should be changed.

  See 'GenServer.code_change/3' for more info.

  Note that when using `Vizi.reload/0` or the live reload feature, this callback will NOT be invoked.
  """
  @callback code_change(old_vsn, t, extra :: term) ::
              {:ok, t}
              | {:error, reason :: term}
            when old_vsn: term | {:down, term}

  @type option ::
          {:title, String.t()}
          | {:width, integer}
          | {:height, integer}
          | {:min_width, integer}
          | {:min_height, integer}
          | {:parent, context}
          | {:resizable, boolean}
          | {:redraw_mode, redraw_mode}
          | {:frame_rate, integer}
          | {:background_color, Canvas.Color.t()}
          | {:pixel_ratio, float}

  @type options :: [GenServer.option() | option]

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Vizi.View

      @doc false
      def handle_event(_event, _view) do
        :cont
      end

      @doc false
      def handle_call(msg, _from, view) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []} -> self()
            {_, name} -> name
          end

        # We do this to trick Dialyzer to not complain about non-local returns.
        case :erlang.phash2(1, 1) do
          0 ->
            raise "attempted to call Vizi.View #{inspect(proc)} but no handle_call/3 clause was provided"

          1 ->
            {:stop, {:bad_call, msg}, view}
        end
      end

      @doc false
      def handle_info(msg, view) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []} -> self()
            {_, name} -> name
          end

        :error_logger.warning_msg('~p ~p received unexpected message in handle_info/2: ~p~n', [
          __MODULE__,
          proc,
          msg
        ])

        {:noreply, view}
      end

      @doc false
      def handle_cast(msg, view) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []} -> self()
            {_, name} -> name
          end

        # We do this to trick Dialyzer to not complain about non-local returns.
        case :erlang.phash2(1, 1) do
          0 ->
            raise "attempted to cast Vizi.View #{inspect(proc)} but no handle_cast/2 clause was provided"

          1 ->
            {:stop, {:bad_cast, msg}, view}
        end
      end

      @doc false
      def terminate(_reason, _view) do
        :ok
      end

      @doc false
      def code_change(_old, view, _extra) do
        {:ok, view}
      end

      defoverridable handle_event: 2,
                     handle_call: 3,
                     handle_info: 2,
                     handle_cast: 2,
                     terminate: 2,
                     code_change: 3
    end
  end

  # Server interface

  @doc """
  Starts a new view

  The first argument is the view's callback module. See `Vizi.View` for more info about its behaviour and callbacks.

  The optional second argument is an params map that can be retrieved in all Vizi.View callback functions.

  The last argument are the view's options, mostly used in the view's initalize phase. The following options are available:

  * `:title` - the view's window title (default: `""`)
  * `:width` - the view's width in pixels (default: `800`)
  * `:height` - the view's height in pixels (default: `600`)
  * `:resizable` - make the view's windows resizable (default: `false`)
  * `:min_width` - the view's window minimum width if resizable is `true` (default: `0`)
  * `:min_height` - the view's window minimum height if resizable is `true` (default: `0`)
  * `:redraw_mode` - can be either `:manual`, or `:interval` (default: `:interval`)
  * `:frame_rate` - sets how many times per second the view will be redrawn when the redraw mode is `:interval` (default: `:vsync`)
  * `:pixel_ratio` - device pixel ration allows to control the rendering on Hi-DPI devices (default: `1.0`)
  * `:background_color` - sets the view's background color (default: `rgba(0, 0, 0, 0)`)
  """
  @spec start(module, params, options) :: GenServer.on_start()
  def start(mod, params, opts \\ []) do
    {server_opts, view_opts} = Keyword.split(opts, [:name, :timeout, :debug, :spawn_opt])
    GenServer.start(View.Server, {mod, params, view_opts}, server_opts)
  end

  @doc """
  Starts a new view and link it to the calling process. See `Vizi.View.start/3` for more info about its arguments.
  """
  @spec start_link(module, params, options) :: GenServer.on_start()
  def start_link(mod, params, opts \\ []) do
    {server_opts, view_opts} = Keyword.split(opts, [:name, :timeout, :debug, :spawn_opt])
    GenServer.start_link(View.Server, {mod, params, view_opts}, server_opts)
  end

  @doc """
  Send a message to the view process and wait for a reply. See `GenServer.call/3` for more info.
  """
  @spec call(server, request :: term, timeout :: integer) :: term
  def call(server, request, timeout \\ 5000) do
    GenServer.call(get_server(server), {:vz_view_call, request}, timeout)
  end

  @doc """
  Send a message to the view process. See `GenServer.cast/2` for more info.
  """
  @spec cast(server, request :: term) :: :ok
  def cast(server, request) do
    GenServer.cast(get_server(server), {:vz_view_cast, request})
  end

  @doc """
  Send a custom event to the view process. If not handled by the view, the event will be passed to all the view's nodes.
  """
  @spec send_event(server, type :: atom, params :: term) :: :ok
  def send_event(server, type, params) do
    {mega, sec, micro} = :os.timestamp()
    time = (mega * 1_000_000 + sec) * 1000 + div(micro, 1000)
    GenServer.cast(get_server(server), %Events.Custom{type: type, params: params, time: time})
  end

  @doc """
  Redraw all nodes in a view. This function should normally only be used when the view's redraw mode is set to manual.
  """
  @spec redraw(server) :: :ok
  def redraw(server) do
    GenServer.cast(get_server(server), :vz_redraw)
  end

  @doc """
  Shutdown a view. Shutting down will close the view's window and terminate the process.
  """
  @spec shutdown(server) :: :ok
  def shutdown(server) do
    GenServer.cast(get_server(server), :vz_shutdown)
  end

  @doc false
  def suspend(server) do
    server = get_server(server)
    :ok = GenServer.call(server, :vz_suspend)
    :ok = GenServer.call(server, :vz_wait_until_suspended)
    :sys.suspend(server)
  end

  @doc false
  def resume(server) do
    server = get_server(server)
    GenServer.cast(server, :vz_resume)
    :sys.resume(server)
  end

  @doc false
  def reinit_and_resume(server) do
    server = get_server(server)
    GenServer.cast(server, :vz_resume_and_reinit)
    :sys.resume(server)
  end

  # View interface

  @doc """
  Makes the given node the new root node of the view
  """
  @spec put_root(t, Node.t()) :: t
  def put_root(view, node) do
    %View{view | root: node}
  end

  @doc """
  Updates the view's root node.

  ## Examples
      fun = &Vizi.Node.put_param(&1, :bg_color, %Vizi.Color{r: 1.0})
      Vizi.View.update_root(view, fun)

  """
  @spec update_root(t, (Node.t() | nil -> Node.t())) :: t
  def update_root(view, fun) do
    %View{view | root: fun.(view.root)}
  end

  @doc """
  Gets the value for a specific key in the view's params map.

  ## Examples

      Vizi.View.get_param(view, :bg_color)
      #=> %Vizi.Color{r: 1.0, g: 0.0, b: 0.0, a: 1.0}

      Vizi.View.get_param(view, :undefined_key, 1.0)
      #=> 1.0

  """
  @spec get_param(t, key :: atom, default :: term) :: term
  def get_param(view, key, default \\ nil) do
    Map.get(view.params, key, default)
  end

  @doc """
  Puts the given `value` under `key` in the view's params map.

  ## Examples

      Vizi.View.put_param(view, :bg_color, %Vizi.Color{r: 1.0})

  """
  @spec put_param(t, key :: atom, value :: term) :: t
  def put_param(view, key, value) do
    %View{view | params: Map.put(view.params, key, value)}
  end

  @doc """
  Merges the given params map with the view's params map.

  See `Map.merge/2` for more info about its semantics.
  """
  @spec merge_params(t, params) :: t
  def merge_params(view, params) do
    %View{view | params: Map.merge(view.params, params)}
  end

  @doc """
  Updates the key in the view's params map with the given function.

  See `Map.update/4` for more info about its semantics.
  """
  @spec update_param(t, key :: atom, initial :: term, fun :: (term -> term)) :: t
  def update_param(view, key, initial, fun) do
    %View{view | params: Map.update(view.params, key, initial, fun)}
  end

  @doc """
  Updates key with the given function.

  See `Map.update!/3` for more info about its semantics.
  """
  @spec update_param!(t, key :: atom, fun :: (term -> term)) :: t
  def update_param!(view, key, fun) do
    %View{view | params: Map.update!(view.params, key, fun)}
  end

  @doc """
  Updates multiple keys with a function.

  ## Examples

      Vizi.View.put_param(view, :a, 1)
      Vizi.View.put_param(view, :b, 2)

      Vizi.View.update_params!(view, a: &(&1 + 1), b: &(&1 * 2))

      Vizi.View.get_param(view, :a)
      #=> 2

      Vizi.View.get_param(view, :b)
      #=> 4

  """
  @spec update_params!(t, updates) :: t
  def update_params!(view, updates) do
    params =
      Enum.reduce(updates, view.params, fn {key, fun}, acc ->
        Map.update!(acc, key, fun)
      end)

    %View{view | params: params}
  end


  @doc """
  Sends a custom event. This function is meant to be called from view or node callback functions.
  """
  @spec send_event(type :: atom, params :: term) :: :ok
  def send_event(type, params) do
    View.send_event(self(), type, params)
  end

  @doc """
  Redraws the view. This function is meant to be called from view or node callback functions.
  """
  @spec redraw() :: :ok
  def redraw() do
    GenServer.cast(self(), :vz_redraw)
  end

  # Internal functions

  defp get_server(pid) when is_pid(pid) do
    pid
  end

  defp get_server(name) do
    {:via, Registry, {Registry.Vizi, name}}
  end
end
