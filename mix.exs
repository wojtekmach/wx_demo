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
    options = [
      name: "WxDemo",
      url_scheme: "wxdemo"
    ]

    mac_app_dmg_options =
      [
        codesign: [
          identity: System.fetch_env!("DEVELOPER_ID")
        ]
      ] ++ options

    [
      mac_app: [
        include_executables_for: [:unix],
        steps: [:assemble, &AppBuilder.create_mac_app(&1, options)]
      ],
      mac_app_dmg: [
        include_executables_for: [:unix],
        steps: [:assemble, &AppBuilder.create_mac_app_dmg(&1, mac_app_dmg_options)]
      ],
      windows_installer: [
        include_executables_for: [:windows],
        steps: [:assemble, &AppBuilder.create_windows_installer(&1, options)]
      ]
    ]
  end
end
