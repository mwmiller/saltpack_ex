defmodule Saltpack.Mixfile do
  use Mix.Project

  def project do
    [app: :saltpack,
     version: "1.0.3",
     elixir: "~> 1.3",
     name: "saltpack",
     source_url: "https://github.com/mwmiller/saltpack_ex",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description,
     package: package,
     deps: deps]
  end

  def application do
    []
  end

  defp deps do
    [
      {:basex, "~> 0.2"},
      {:equivalex, "~> 0.1"},
      {:kcl, "~> 0.6"},
      {:msgpax, "~> 0.8"},
      {:earmark, "~> 1.0", only: :dev},
      {:ex_doc, "~> 0.13", only: :dev},
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
