defmodule Saltpack.Mixfile do
  use Mix.Project

  def project do
    [
      app: :saltpack,
      version: "1.3.0",
      elixir: "~> 1.8",
      name: "saltpack",
      source_url: "https://github.com/mwmiller/saltpack_ex",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:basex, "~> 1.3"},
      {:equivalex, "~> 1.0"},
      {:kcl, "~> 1.3"},
      {:msgpax, "~> 2.2"},
      {:ex_doc, "~> 0.23", only: :dev},
    ]
  end

  defp description do
    """
    pure Elixir saltpack library implementation
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*", "mix.lock"],
      maintainers: ["Matt Miller"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/mwmiller/saltpack_ex",
        "Info" => "https://saltpack.org"
      }
    ]
  end
end
