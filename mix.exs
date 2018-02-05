defmodule Vizi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :vizi,
      version: "0.3.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      # Add the make compiler
      compilers: [:make, :elixir, :app],
      # Configure aliases
      aliases: aliases(),
      dialyzer: [plt_add_deps: :app_tree, plt_add_apps: [:mix]],

      # Docs
      name: "Vizi",
      source_url: "https://github.com/zambal/vizi",
      homepage_url: "https://github.com/zambal/vizi",
      docs: [extras: ["README.md"]]
    ]
  end

  def application do
    [
      mod: {Vizi, []},
      extra_applications: [:logger, :fs]
    ]
  end

  defp aliases do
    # Execute the usual mix clean and our Makefile clean task
    [clean: ["clean", "clean.make"]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.16", only: :dev, runtime: false},
      {:fs, "~> 3.4", runtime: false}
    ]
  end
end

defmodule Mix.Tasks.Compile.Make do
  def run(_) do
    {result, _error_code} = System.cmd("make", [], stderr_to_stdout: true)
    Mix.shell().info(result)
    :ok
  end
end

defmodule Mix.Tasks.Clean.Make do
  def run(_) do
    {result, _error_code} = System.cmd("make", ["clean"], stderr_to_stdout: true)
    Mix.shell().info(result)
    :ok
  end
end
