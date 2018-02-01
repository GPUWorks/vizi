defmodule Vizi do
  use Application


  # Public API

  @spec start() :: {:ok, [Application.app]} | {:error, {Application.app, term}}
  def start do
    Application.ensure_all_started(:vizi)
  end

  @spec start_view(module, term, Vizi.View.options) :: Supervisor.on_start_child()
  def start_view(mod, args, opts) do
    DynamicSupervisor.start_child(:vizi_view_sup, %{
      id: Vizi.View,
      start: {Vizi.View, :start_link, [mod, args, opts]},
      restart: :transient
    })
  end

  @spec reload() :: :ok
  def reload do
    resume_fun = if Application.get_env(:vizi, :reinit_on_reload, true) do
      &Vizi.View.reinit_and_resume/1
    else
      &Vizi.View.resume/1
    end

    Enum.each(get_view_pids(), &Vizi.View.suspend/1)
    Mix.Tasks.Compile.Elixir.run([])
    Enum.each(get_view_pids(), resume_fun)
  end

  @spec reinit_on_reload(boolean) :: :ok
  def reinit_on_reload(reinit) do
    Application.put_env(:vizi, :reinit_on_reload, reinit)
    :ok
  end


  # Application implementation

  def start(_type, _args) do
    children = if Application.get_env(:vizi, :auto_reload, false) do
      [Vizi.Reloader.Supervisor]
    else
      []
    end

    children = [
      {DynamicSupervisor, [name: :vizi_view_sup, strategy: :one_for_one]} | children
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: :vizi_sup)
  end


  # Internal functions

  defp get_view_pids do
    children = DynamicSupervisor.which_children(:vizi_view_sup)
    for {:undefined, pid, _type, _modules} <- children, is_pid(pid), do: pid
  end
end