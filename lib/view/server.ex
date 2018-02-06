defmodule Vizi.View.Server do
  use GenServer

  alias Vizi.{
    Canvas,
    Events,
    NIF,
    Node,
    View
  }

  @defaults [
    title: "",
    width: 800,
    height: 600,
    min_width: 0,
    min_height: 0,
    resizable: false,
    background_color: Canvas.rgba(0, 0, 0, 0),
    frame_rate: :vsync,
    pixel_ratio: 1.0
  ]

  @doc false
  def init({mod, params, opts}) do
    opts = Keyword.merge(@defaults, opts)

    opts =
      Keyword.update!(opts, :frame_rate, fn
        :vsync -> -1
        n -> n
      end)

    case NIF.create_view(opts) do
      {:ok, ctx} ->
        wait_until_initialized(ctx)

        xform = Canvas.Transform.identity(ctx)
        redraw_mode = Keyword.get(opts, :redraw_mode, :manual)
        frame_rate = NIF.get_frame_rate(ctx)

        Process.put(:vz_frame_rate, frame_rate)
        Vizi.register()

        handle_init(mod, %View{
          context: ctx,
          redraw_mode: redraw_mode,
          mod: mod,
          params: params,
          init_params: params,
          identity_xform: xform,
          width: opts[:width],
          height: opts[:height]
        })

      {:error, e} ->
        {:stop, e}
    end
  end

  @doc false
  def handle_call(:vz_suspend, _from, view) do
    view =
      case view.suspend do
        :off ->
          NIF.suspend(view.context)
          %{view | suspend: :requested}

        _ ->
          view
      end

    {:reply, :ok, view}
  end

  def handle_call(:vz_wait_until_suspended, _from, view) do
    case view.suspend do
      :requested ->
        wait_until_suspended()
        {:reply, :ok, %{view | suspend: :on}}

      :on ->
        {:reply, :ok, view}

      :off ->
        {:reply, :error, view}
    end
  end

  def handle_call({:vz_view_call, request}, from, view) do
    view.mod.handle_call(request, from, view)
  end

  @doc false
  def handle_cast(:vz_redraw, view) do
    NIF.redraw(view.context)
    {:noreply, view}
  end

  def handle_cast(:vz_resume, view) do
    case view.suspend do
      :on ->
        NIF.resume(view.context)
        {:noreply, %{view | suspend: :off}}

      _ ->
        {:noreply, view}
    end
  end

  def handle_cast(:vz_reinit_and_resume, view) do
    case view.suspend do
      :on ->
        view.mod.terminate(:reload, view)
        NIF.resume(view.context)

        case handle_init(view.mod, %View{view | params: view.init_params}) do
          {:ok, view} ->
            {:noreply, %{view | suspend: :off}}

          :ignore ->
            {:stop, :normal, view}

          {:stop, reason} ->
            {:stop, reason, view}
        end

      _ ->
        {:noreply, view}
    end
  end

  def handle_cast(:vz_shutdown, view) do
    {:stop, :shutdown, view}
  end

  def handle_cast(%Events.Custom{} = ev, view) do
    NIF.force_send_events(view.context)

    if view.redraw_mode == :manual do
      NIF.redraw(view.context)
    end

    {:noreply, %{view | custom_events: [ev | view.custom_events]}}
  end

  def handle_cast({:vz_view_cast, request}, view) do
    view.mod.handle_cast(request, view)
  end

  @doc false
  def handle_info(:vz_update, view) do
    root = Node.update(view.root, view.identity_xform, view.context)
    NIF.ready(view.context)
    {:noreply, %{view | root: root}}
  end

  def handle_info(:vz_shutdown, view) do
    {:stop, {:shutdown, :request_from_thread}, view}
  end

  def handle_info(:vz_suspended, view) do
    {:noreply, %{view | suspend: :on}}
  end

  def handle_info({:vz_event, events}, view) when is_list(events) do
    view = handle_events(view.custom_events ++ events, view)
    {:noreply, view}
  end

  def handle_info(msg, view) do
    view.mod.handle_info(msg, view)
  end

  @doc false
  def terminate({:shutdown, :request_from_thread} = reason, view) do
    view.mod.terminate(reason, view)
  end

  def terminate(reason, view) do
    NIF.shutdown(view.context)
    wait_until_shutdown()
    view.mod.terminate(reason, view)
  end

  @doc false
  def code_change(old_vsn, view, extra) do
    view.mod.code_change(old_vsn, view, extra)
  end

  # Internal functions

  defp handle_init(mod, view) do
    case mod.init(view) do
      {:ok, root} ->
        {:ok, View.put_root(view, root)}

      other ->
        other
    end
  end

  defp handle_events(events, %View{root: root, context: ctx} = view) do
    {events, view} = Enum.reduce(events, {[], view}, &do_handle_event/2)
    {root, _} = Node.handle_events(Enum.reverse(events), root, ctx)
    %{view | root: root, custom_events: []}
  end

  defp do_handle_event(%Events.Configure{} = ev, {evs, view}) do
    view = handle_configure(ev, view)
    {evs, view}
  end

  defp do_handle_event(ev, {evs, view}) do
    case view.mod.handle_event(ev, view) do
      :cont ->
        {[ev | evs], view}

      :done ->
        {evs, view}

      {:cont, view} ->
        {[ev | evs], view}

      {:done, view} ->
        {evs, view}

      bad_return ->
        raise RuntimeError,
          message:
            "bad return value from #{inspect(view.mod)}.handle_event/3: #{inspect(bad_return)}"
    end
  end

  defp handle_configure(ev, state) do
    %{state | identity_xform: ev.xform, width: ev.width, height: ev.height}
  end

  defp wait_until_suspended do
    receive do
      :vz_suspended ->
        :ok
    after
      5_000 ->
        raise "failed to suspend view thread"
    end
  end

  defp wait_until_initialized(context) do
    receive do
      :vz_initialized ->
        :ok
    after
      5_000 ->
        NIF.shutdown(context)
        raise "failed to initialize view thread"
    end
  end

  defp wait_until_shutdown do
    receive do
      :vz_shutdown ->
        :ok
    after
      5_000 ->
        :ok
    end
  end
end
