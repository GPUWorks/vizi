defmodule Vizi.Reloader.Supervisor do
  use Supervisor

  @fs_watcher :vizi_fs_watcher

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    children = [
      %{
        id: :fs,
        start: {:fs, :start_link, [@fs_watcher, "lib"]},
        type: :supervisor
      },
      {Vizi.Reloader, @fs_watcher}
    ]
    Supervisor.init(children, strategy: :one_for_all)
  end
end