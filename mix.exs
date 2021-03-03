defmodule ExtraEnum.MixProject do
  use Mix.Project

  @version "0.1.1"

  def project do
    [
      app: :extra_enum,
      version: @version,
      elixir: "~> 1.11.1",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: false,
      deps: deps(),
      name: "ExtraEnum",
      description: "Provides useful extra enumerable types for Elixir.",
      source_url: "https://github.com/jvantuyl/extra_enum",
      package: package(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs"
      ],
      docs: docs()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # doc
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      # testing / quality
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp package() do
    [licenses: ["MIT"], links: %{"GitHub" => "https://github.com/jvantuyl/extra_enum"}]
  end

  defp docs() do
    [
      main: "readme",
      api_reference: false,
      extras: ["README.md": [title: "Overview"], "LICENSE.md": [title: "License"]],
      authors: ["Jayson Vantuyl"],
      source_ref: "v#{@version}"
    ]
  end
end
