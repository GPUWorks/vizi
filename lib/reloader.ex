defmodule Vizi.Reloader do
  use GenServer

  def start_link(watcher) do
    GenServer.start_link(__MODULE__, watcher)
  end

  def init(watcher) do
    :fs.subscribe(watcher)

    {:ok, watcher}
  end

  def handle_info({_pid, {:fs, :file_event}, {_path, _flags}}, watcher) do
    Vizi.reload()
    {:noreply, watcher}
  end
end
