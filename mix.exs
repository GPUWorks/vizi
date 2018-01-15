defmodule Mix.Tasks.Compile.Make do
  def run(_) do
    {result, _error_code} = System.cmd("make", [], stderr_to_stdout: true)
    Mix.shell.info(result)
    :ok
  end
end

defmodule Mix.Tasks.Clean.Make do
  def run(_) do
    {result, _error_code} = System.cmd("make", ['clean'], stderr_to_stdout: true)
    Mix.shell.info(result)
    :ok
  end
end

defmodule Vizi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :vizi,
      version: "0.1.0",
      elixir: "~> 1.4",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      compilers: [:make, :elixir, :app], # Add the make compiler
      aliases: aliases(), # Configure aliases

      # Docs
      name: "Vizi",
      source_url: "https://github.com/zambal/vizi",
      homepage_url: "https://github.com/zambal/vizi",
      docs: [extras: ["README.md"]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do    # Execute the usual mix clean and our Makefile clean task
    [clean: ["clean", "clean.make"]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.16", only: :dev, runtime: false}
    ]
  end
end
