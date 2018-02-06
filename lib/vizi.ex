defmodule Vizi do
  use Application

  # Public API

  @doc """
  Starts the `:vizi` application.

  Calling this function shouldn't be needed in most cases, as the preferred way of starting Vizi is
  including `:vizi` as application in your project's mix file.
  """
  @spec start() :: {:ok, [Application.app()]} | {:error, {Application.app(), term}}
  def start do
    Application.ensure_all_started(:vizi)
  end

  @spec reload() :: :ok
  def reload do
    resume_fun =
      if Application.get_env(:vizi, :reinit_on_reload, true),
        do: &Vizi.View.reinit_and_resume/1,
        else: &Vizi.View.resume/1

    pids = get_view_pids()

    Enum.each(pids, &Vizi.View.suspend/1)
    Mix.Tasks.Compile.Elixir.run([])
    Enum.each(pids, resume_fun)
  end

  @spec reinit_on_reload(boolean) :: :ok
  def reinit_on_reload(reinit) do
    Application.put_env(:vizi, :reinit_on_reload, reinit)
    :ok
  end

  @doc false
  def register() do
    Registry.register(Vizi.Registry, :views, nil)
  end

  # Application implementation

  def start(_type, _args) do
    children =
      if Application.get_env(:vizi, :live_reload, false),
        do: [Vizi.Reloader.Supervisor],
        else: []

    children = [
      {Registry, keys: :duplicate, name: Vizi.Registry}
      | children
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Vizi.Supervisor)
  end

  # Internal functions

  defp get_view_pids do
    views = Registry.lookup(Vizi.Registry, :views)
    for {pid, _value} <- views, do: pid
  end
end
