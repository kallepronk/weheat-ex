defmodule Weheat.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/kallepronk/weheat-ex"

  def project do
    [
      app: :weheat,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Thin client for the WeHeat heat pump third-party API.",
      package: package(),
      docs: [main: "readme", extras: ["README.md", "CHANGELOG.md"], source_url: @source_url],
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Weheat.Application, []}
    ]
  end

  defp deps do
    [
      {:req, "~> 0.5"},
      {:plug, "~> 1.16", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE)
    ]
  end
end
