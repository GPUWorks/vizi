defmodule Vizi.View do
  use GenServer
  alias Vizi.{Events, NIF}


  defstruct context: nil, root: nil,
            width: 0, height: 0,
            custom_events: [],
            redraw_mode: :manual,
            identity_xform: nil,
            mod: nil, state: nil

  @type context :: <<>>

  @type redraw_mode :: :manual | :interval

  @type view_option :: {:title, String.t} |
                       {:width, integer} |
                       {:height, integer} |
                       {:min_width, integer} |
                       {:min_height, integer} |
                       {:parent, context} |
                       {:resizable, boolean} |
                       {:redraw_mode, redraw_mode} |
                       {:frame_rate, integer} |
                       {:background_color, Vizi.Canvas.Color.t} |
                       {:pixel_ratio, float}

  @type options :: [GenServer.option | view_option]

  @type t :: %Vizi.View{
    context: context,
    root: Vizi.Node.t,
    custom_events: [%Vizi.Events.Custom{}],
    redraw_mode: redraw_mode,
    identity_xform: Vizi.Canvas.Transform.t,
    mod: module, state: term
  }

  @callback init(args :: term, width :: integer, height :: integer) ::
  {:ok, root, state} |
  {:ok, root, state, timeout | :hibernate} |
  :ignore |
  {:stop, reason :: term} when root: Vizi.Node.t, state: term

  @callback handle_event(event :: term, root :: Vizi.Node.t, state :: term) ::
  :cont | :done |
  {:cont, new_root, new_state} |
  {:done, new_root, new_state} when new_root: Vizi.Node.t, new_state: term

  @callback handle_call(request :: term, from :: term, root :: Vizi.Node.t, state :: term) ::
  {:reply, reply, new_root, new_state} |
  {:reply, reply, new_root, new_state, timeout | :hibernate} |
  {:noreply, new_root, new_state} |
  {:noreply, new_root, new_state, timeout | :hibernate} |
  {:stop, reason, reply, new_root, new_state} |
  {:stop, reason, new_root, new_state} when reply: term, new_root: Vizi.Node.t, new_state: term, reason: term

  @callback handle_cast(request :: term, root :: Vizi.Node.t, state :: term) ::
  {:noreply, new_root, new_state} |
  {:noreply, new_root, new_state, timeout | :hibernate} |
  {:stop, reason :: term, new_root, new_state} when new_root: Vizi.Node.t, new_state: term

  @callback handle_info(msg :: :timeout | term, root :: Vizi.Node.t, state :: term) ::
  {:noreply, new_root, new_state} |
  {:noreply, new_root, new_state, timeout | :hibernate} |
  {:stop, reason :: term, new_state} when new_root: Vizi.Node.t, new_state: term

  @callback terminate(reason, root :: Vizi.Node.t, state :: term) ::
  term when reason: :normal | :shutdown | {:shutdown, term} | term

  @callback code_change(old_vsn, root :: Vizi.Node.t, state :: term, extra :: term) ::
  {:ok, new_root :: Vizi.Node.t, new_state :: term} |
  {:error, reason :: term} when old_vsn: term | {:down, term}

  @defaults [
    title: "",
    width: 800,
    height: 600,
    min_width: 0,
    min_height: 0,
    resizable: false,
    background_color: Vizi.Canvas.rgba(0, 0, 0, 0),
    frame_rate: 30,
    pixel_ratio: 1.0
  ]

  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Vizi.View

      @doc false
      def handle_event(_event, _root, _state) do
        :cont
      end

      @doc false
      def handle_call(msg, _from, root, state) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []}   -> self()
            {_, name} -> name
          end

        # We do this to trick Dialyzer to not complain about non-local returns.
        case :erlang.phash2(1, 1) do
          0 -> raise "attempted to call Vizi.View #{inspect proc} but no handle_call/3 clause was provided"
          1 -> {:stop, {:bad_call, msg}, root, state}
        end
      end

      @doc false
      def handle_info(msg, root, state) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []}   -> self()
            {_, name} -> name
          end
        :error_logger.warning_msg('~p ~p received unexpected message in handle_info/2: ~p~n',
                                  [__MODULE__, proc, msg])
        {:noreply, root, state}
      end

      @doc false
      def handle_cast(msg, root, state) do
        proc =
          case Process.info(self(), :registered_name) do
            {_, []}   -> self()
            {_, name} -> name
          end

        # We do this to trick Dialyzer to not complain about non-local returns.
        case :erlang.phash2(1, 1) do
          0 -> raise "attempted to cast Vizi.View #{inspect proc} but no handle_cast/2 clause was provided"
          1 -> {:stop, {:bad_cast, msg}, root, state}
        end
      end

      @doc false
      def terminate(_reason, _root, _state) do
        :ok
      end

      @doc false
      def code_change(_old, root, state, _extra) do
        {:ok, root, state}
      end

      defoverridable [handle_event: 3, handle_call: 4, handle_info: 3,
                      handle_cast: 3, terminate: 3, code_change: 4]
    end
  end

  # Public interface

  @spec start(mod :: module, args :: term, opts :: options) :: GenServer.on_start
  def start(mod, args, opts \\ []) do
    {server_opts, view_opts} = Keyword.split(opts, [:name, :timeout, :debug, :spawn_opt])
    GenServer.start(__MODULE__, {mod, args, view_opts}, server_opts)
  end

  @spec start_link(mod :: module, args :: term, opts :: options) :: GenServer.on_start
  def start_link(mod, args, opts \\ []) do
    {server_opts, view_opts} = Keyword.split(opts, [:name, :timeout, :debug, :spawn_opt])
    GenServer.start_link(__MODULE__, {mod, args, view_opts}, server_opts)
  end

  @spec call(server :: GenServer.server, request :: term, timeout :: integer) :: term
  def call(server, request, timeout \\ 5000) do
    GenServer.call(server, {:vz_view_call, request}, timeout)
  end

  @spec cast(server :: GenServer.server, request :: term) :: :ok
  def cast(server, request) do
    GenServer.cast(server, {:vz_view_cast, request})
  end

  @spec send_event(server :: GenServer.server, type :: atom, params :: term) :: :ok
  def send_event(server, type, params) do
    {mega, sec, micro} = :os.timestamp
    time = (mega * 1_000_000 + sec) * 1000 + div(micro, 1000)
    GenServer.cast(server, %Events.Custom{type: type, params: params, time: time})
  end

  @spec send_event(type :: atom, params :: term) :: :ok
  def send_event(type, params) do
    send_event(self(), type, params)
  end

  @spec redraw(server :: GenServer.server) :: :ok
  def redraw(server) do
    GenServer.cast(server, :vz_redraw)
  end

  @spec redraw() :: :ok
  def redraw() do
    GenServer.cast(self(), :vz_redraw)
  end

  # GenServer implementation

  @doc false
  def init({mod, args, opts}) do
    opts = Keyword.merge(@defaults, opts)
    case NIF.create_view(opts) do
      {:ok, ctx} ->
        wait_until_initialized()
        xform = Vizi.Canvas.Transform.identity()
        redraw_mode = Keyword.get(opts, :redraw_mode, :manual)
        state = %Vizi.View{context: ctx, redraw_mode: redraw_mode, mod: mod, identity_xform: xform}
        Process.put(:vz_frame_rate, opts[:frame_rate])
        callback_init(mod, args, opts[:width], opts[:height], state)
      {:error, e} ->
        {:stop, e}
    end
  end

  @doc false
  def handle_call({:vz_view_call, request}, from, state) do
    callback_call(request, from, state)
  end

  @doc false
  def handle_cast({:vz_view_cast, request}, state) do
    callback_cast(request, state)
  end

  def handle_cast(%Events.Custom{} = ev, state) do
    NIF.force_send_events(state.context)
    if state.redraw_mode == :manual do
        NIF.redraw(state.context)
    end
    {:noreply, %{state|custom_events: [ev | state.custom_events]}}
  end

  def handle_cast(:vz_redraw, state) do
    NIF.redraw(state.context)
    {:noreply, state}
  end

  @doc false
  def handle_info({:vz_update, _ts}, state) do
    root = Vizi.Node.update(state.root, state.identity_xform, state.context)
    Vizi.NIF.ready(state.context)
    {:noreply, %{state|root: root}}
  end

  def handle_info({:vz_event, events}, state) when is_list(events) do
    state = handle_events(state.custom_events ++ events, state)
    {:noreply, state}
  end

  def handle_info(:vz_shutdown, state) do
    {:stop, {:shutdown, :vz_shutdown_event}, state}
  end

  def handle_info(msg, state) do
    callback_info(msg, state)
  end

  @doc false
  def terminate(reason, state) do
    case reason do
      {:shutdown, :vz_shutdown_event} ->
        :ok
      _ ->
        NIF.shutdown(state.context)
    end
    callback_terminate(reason, state)
  end

  @doc false
  def code_change(old_vsn, state, extra) do
    callback_code_change(old_vsn, state, extra)
  end


  defp callback_init(mod, args, width, height, state) do
    case mod.init(args, width, height) do
      {:ok, root, mod_state} ->
        {:ok, %{state|root: root, state: mod_state}}
      {:ok, root, mod_state, timeout} ->
        {:ok, %{state|root: root, state: mod_state}, timeout}
      :ignore ->
        :ignore
      {:stop, reason} ->
        {:stop, reason}
      bad_return ->
        raise "bad return value from #{inspect state.mod}.init/1: #{inspect bad_return}"
      end
  end

  defp callback_call(request, from, state) do
    case state.mod.handle_call(request, from, state.root, state.state) do
      {:reply, reply, new_root, new_state} ->
        {:reply, reply, %{state|root: new_root, state: new_state}}
      {:reply, reply, new_root, new_state, timeout} ->
        {:reply, reply, %{state|root: new_root, state: new_state}, timeout}
      {:noreply, new_root, new_state} ->
        {:noreply, %{state|root: new_root, state: new_state}}
      {:noreply, new_root, new_state, timeout} ->
        {:noreply, %{state|root: new_root, state: new_state}, timeout}
      {:stop, reason, reply, new_root, new_state} ->
        {:stop, reason, reply, %{state|root: new_root, state: new_state}}
      {:stop, reason, new_root, new_state} ->
        {:stop, reason, %{state|root: new_root, state: new_state}}
      bad_return ->
        raise "bad return value from #{inspect state.mod}.handle_call/4: #{inspect bad_return}"
      end
  end

  defp callback_cast(request, state) do
    case state.mod.handle_cast(request, state.root, state.state) do
      {:noreply, new_root, new_state} ->
        {:noreply, %{state|root: new_root, state: new_state}}
      {:noreply, new_root, new_state, timeout} ->
        {:noreply, %{state|root: new_root, state: new_state}, timeout}
      {:stop, reason, new_root, new_state} ->
        {:stop, reason, %{state|root: new_root, state: new_state}}
      bad_return ->
      raise "bad return value from #{inspect state.mod}.handle_cast/3: #{inspect bad_return}"
      bad_return
      end
  end

  defp callback_info(msg, state) do
    case state.mod.handle_info(msg, state.root, state.state) do
      {:noreply, new_root, new_state} ->
        {:noreply, %{state|root: new_root, state: new_state}}
      {:noreply, new_root, new_state, timeout} ->
        {:noreply, %{state|root: new_root, state: new_state}, timeout}
      {:stop, reason, new_root, new_state} ->
        {:stop, reason, %{state|root: new_root, state: new_state}}
      bad_return ->
        raise "bad return value from #{inspect state.mod}.handle_info/3: #{inspect bad_return}"
      end
  end

  defp callback_terminate(reason, state) do
    state.mod.terminate(reason, state.root, state.state)
  end

  defp callback_code_change(old_vsn, state, extra) do
    case state.mod.code_change(old_vsn, state.root, state.state, extra) do
      {:ok, new_root, new_state} ->
        {:ok, %{state|root: new_root, state: new_state}}
      {:error, reason} ->
        {:error, reason}
      bad_return ->
        raise "bad return value from #{inspect state.mod}.code_change/4: #{inspect bad_return}"
    end
  end

  defp handle_events(events, %{root: root, context: ctx} = state) do
    {events, root, mod_state, state} = Enum.reduce(events, {[], root, state.state, state}, &do_handle_event/2)
    {root, _} = Vizi.Node.handle_events(root, Enum.reverse(events), ctx)
    %{state|root: root, custom_events: [], state: mod_state}
  end

  defp do_handle_event(%Events.Configure{} = ev, {evs, root, mod_state, state}) do
    new_state = handle_configure(ev, state)
    {evs, root, mod_state, new_state}
  end
  defp do_handle_event(ev, {evs, root, mod_state, state}) do
    case state.mod.handle_event(ev, root, mod_state) do
      :cont ->
        {[ev|evs], root, mod_state, state}
      :done ->
        {evs, root, mod_state, state}
      {:cont, new_root, new_state} ->
        {[ev|evs], new_root, new_state, state}
      {:done, new_root, new_state} ->
        {evs, new_root, new_state, state}
      bad_return ->
        raise RuntimeError, message: "bad return value from #{inspect state.mod}.handle_event/3: #{inspect bad_return}"
    end
  end

  defp handle_configure(ev, state) do
    %{state|identity_xform: ev.xform, width: ev.width, height: ev.height}
  end

  defp wait_until_initialized do
    receive do
      :vz_initialized ->
        :ok
    end
  end
end