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
            put_param: 3,
            put_params: 2,
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

  @callback init(t) ::
              {:ok, t}
              | :ignore
              | {:stop, reason :: term}

  @callback handle_event(event :: term, t) ::
              :cont
              | :done
              | {:cont, t}
              | {:done, t}

  @callback handle_call(request :: term, from :: term, t) ::
              {:reply, reply, t}
              | {:reply, reply, t, timeout | :hibernate}
              | {:noreply, t}
              | {:noreply, t, timeout | :hibernate}
              | {:stop, reason, reply, t}
              | {:stop, reason, t}
            when reply: term, reason: term

  @callback handle_cast(request :: term, t) ::
              {:noreply, t}
              | {:noreply, t, timeout | :hibernate}
              | {:stop, reason :: term, t}

  @callback handle_info(msg :: :timeout | term, t) ::
              {:noreply, t}
              | {:noreply, t, timeout | :hibernate}
              | {:stop, reason :: term, t}

  @callback terminate(reason, t) :: term
            when reason: :normal | :shutdown | {:shutdown, term} | term

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

  The second argument is an optional params map that can be retrieved in every Vizi.View callback functions.

  The last argument are the view's options, mostly used in the view's initalize phase. The following options are available:

  * `:width` - The view's width in pixels (default: 800)
  * `:height` - The view's height in pixels (default: 600)
  * `:pixel_ratio` -


  """
  @spec start(module, params, options) :: GenServer.on_start()
  def start(mod, params, opts \\ []) do
    {server_opts, view_opts} = Keyword.split(opts, [:name, :timeout, :debug, :spawn_opt])
    GenServer.start(View.Server, {mod, params, view_opts}, server_opts)
  end

  @spec start_link(module, params, options) :: GenServer.on_start()
  def start_link(mod, params, opts \\ []) do
    {server_opts, view_opts} = Keyword.split(opts, [:name, :timeout, :debug, :spawn_opt])
    GenServer.start_link(View.Server, {mod, params, view_opts}, server_opts)
  end

  @spec call(server, request :: term, timeout :: integer) :: term
  def call(server, request, timeout \\ 5000) do
    GenServer.call(get_server(server), {:vz_view_call, request}, timeout)
  end

  @spec cast(server, request :: term) :: :ok
  def cast(server, request) do
    GenServer.cast(get_server(server), {:vz_view_cast, request})
  end

  @spec send_event(server, type :: atom, params :: term) :: :ok
  def send_event(server, type, params) do
    {mega, sec, micro} = :os.timestamp()
    time = (mega * 1_000_000 + sec) * 1000 + div(micro, 1000)
    GenServer.cast(get_server(server), %Events.Custom{type: type, params: params, time: time})
  end

  @spec redraw(server) :: :ok
  def redraw(server) do
    GenServer.cast(get_server(server), :vz_redraw)
  end

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
    GenServer.cast(server, :vz_reinit_and_resume)
    :sys.resume(server)
  end

  # View interface

  @spec put_root(t, Node.t()) :: t
  def put_root(view, node) do
    %View{view | root: node}
  end

  @spec update_root(t, (Node.t() | nil -> Node.t())) :: t
  def update_root(view, fun) do
    %View{view | root: fun.(view.root)}
  end

  @spec put_param(t, key :: atom, value :: term) :: t
  def put_param(view, key, value) do
    %View{view | params: Map.put(view.params, key, value)}
  end

  @spec put_params(t, params) :: t
  def put_params(view, params) do
    %View{view | params: Map.merge(view.params, params)}
  end

  @spec update_param(t, key :: atom, initial :: term, fun :: (term -> term)) :: t
  def update_param(view, key, initial, fun) do
    %View{view | params: Map.update(view.params, key, initial, fun)}
  end

  @spec update_param!(t, key :: atom, fun :: (term -> term)) :: t
  def update_param!(view, key, fun) do
    %View{view | params: Map.update!(view.params, key, fun)}
  end

  @spec update_params!(t, updates) :: t
  def update_params!(view, updates) do
    params =
      Enum.reduce(updates, view.params, fn {key, fun}, acc ->
        Map.update!(acc, key, fun)
      end)

    %View{view | params: params}
  end

  @spec send_event(type :: atom, params :: term) :: :ok
  def send_event(type, params) do
    View.send_event(self(), type, params)
  end

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
