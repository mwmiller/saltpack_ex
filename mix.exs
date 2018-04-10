defmodule Saltpack.Mixfile do
  use Mix.Project

  def project do
    [app: :saltpack,
     version: "1.1.5",
     elixir: "~> 1.4",
     name: "saltpack",
     source_url: "https://github.com/mwmiller/saltpack_ex",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     deps: deps()]
  end

  def application do
    []
  end

  defp deps do
    [
      {:basex, "~> 1.0"},
      {:equivalex, "~> 1.0"},
      {:kcl, ">= 1.1.0"},
      {:msgpax, "~> 2.0"},
      {:earmark, "~> 1.1", only: :dev},
      {:ex_doc, "~> 0.14", only: :dev},
      {:credo, "~> 0.8", only: [:dev, :test]},
    ]
  end

  defp description do
    """
    pure Elixir saltpack library implementation
    """
  end

  defp package do
    [
     files: ["lib", "mix.exs", "README*", "LICENSE*", ],
     maintainers: ["Matt Miller"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/mwmiller/saltpack_ex",
              "Info"   => "https://saltpack.org",
             }
    ]
  end

end
