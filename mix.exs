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
    [
      mac_app: [
        include_executables_for: [:unix],
        steps: [
          :assemble,
          &AppBuilder.create_mac_app(&1,
            name: "WxDemo",
            info_plist: """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>CFBundlePackageType</key>
              <string>APPL</string>
              <key>CFBundleName</key>
              <string>WxDemo</string>
              <key>CFBundleDisplayName</key>
              <string>WxDemo</string>
              <key>CFBundleIconFile</key>
              <string>AppIcon</string>
              <key>CFBundleIconName</key>
              <string>AppIcon</string>
              <key>CFBundleURLTypes</key>
              <array>
                <dict>
                  <key>CFBundleURLName</key>
                  <string>wxdemo</string>
                  <key>CFBundleURLSchemes</key>
                  <array>
                    <string>wxdemo</string>
                  </array>
                </dict>
              </array>
            </dict>
            </plist>
            """
          )
        ]
      ]
    ]
  end
end
