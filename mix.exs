defmodule WxDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :wx_demo,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :wx],
      mod: {WxDemo.Application, []}
    ]
  end

  defp deps do
    [
      {:app_builder, path: "./app_builder"}
    ]
  end

  defp releases do
    app_builder_options = [
      name: "WxDemo",
      url_scheme: "wxdemo"
    ]

    [
      mac_app: [
        include_executables_for: [:unix],
        steps: [:assemble, &AppBuilder.create_mac_app(&1, app_builder_options)]
      ],
      mac_app_dmg: [
        include_executables_for: [:unix],
        steps: [:assemble, &AppBuilder.create_mac_app_dmg(&1, app_builder_options)]
      ],
      windows_installer: [
        include_executables_for: [:windows],
        steps: [:assemble, &AppBuilder.create_windows_installer(&1, app_builder_options)]
      ]
    ]
  end
end
