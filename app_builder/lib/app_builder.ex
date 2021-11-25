defmodule AppBuilder do
  def create_mac_app(release, options) do
    app_name = Keyword.fetch!(options, :name)

    app_bundle_path = Path.join([Mix.Project.build_path(), "rel", "#{app_name}.app"])

    File.mkdir_p!(Path.join([app_bundle_path, "Contents", "Resources"]))
    File.cp_r!(release.path, Path.join([app_bundle_path, "Contents", "Resources", "rel"]))

    File.mkdir_p!(Path.join([app_bundle_path, "Contents", "MacOS"]))

    File.write!(Path.join([app_bundle_path, "Contents", "MacOS", app_name]), """
    #!/bin/sh
    set -e
    root=$(dirname $(dirname "$0"))
    $root/Resources/rel/bin/#{release.name} start \
      1>> ~/Library/Logs/#{app_name}.stdout.log \
      2>> ~/Library/Logs/#{app_name}.stderr.log
    """)

    File.chmod!(Path.join([app_bundle_path, "Contents", "MacOS", app_name]), 0o700)

    logo_path = options[:logo_path] || Application.app_dir(:wx, "examples/demo/erlang.png")
    create_logo(app_bundle_path, logo_path)

    info_plist = options[:info_plist] || build_info_plist(options)
    File.write!(Path.join([app_bundle_path, "Contents", "Info.plist"]), info_plist)

    release
  end

  defp build_info_plist(options) do
    app_name = Keyword.fetch!(options, :name)

    url_scheme =
      if scheme = options[:url_scheme] do
        """
        \n<key>CFBundleURLTypes</key>
        <array>
        <dict>
          <key>CFBundleURLName</key>
          <string>#{app_name}</string>
          <key>CFBundleURLSchemes</key>
          <array>
            <string>#{scheme}</string>
          </array>
        </dict>
        </array>\
        """
      end

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleName</key>
    <string>#{app_name}</string>
    <key>CFBundleDisplayName</key>
    <string>#{app_name}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>#{url_scheme}
    </dict>
    </plist>
    """
  end

  defp create_logo(app_bundle_path, logo_source_path) do
    logo_dest_path = Path.join([app_bundle_path, "Contents", "Resources", "AppIcon.icns"])

    logo_dest_tmp_path = "tmp/AppIcon.iconset"
    File.rm_rf!(logo_dest_tmp_path)
    File.mkdir_p!(logo_dest_tmp_path)

    sizes = for(i <- [16, 32, 64, 128], j <- [1, 2], do: {i, j}) ++ [{512, 1}]

    for {size, scale} <- sizes do
      suffix =
        case scale do
          1 -> ""
          2 -> "@2x"
        end

      size = size * scale
      out = "#{logo_dest_tmp_path}/icon_#{size}x#{size}#{suffix}.png"
      cmd!("sips", ~w(-z #{size} #{size} #{logo_source_path} --out #{out}))
    end

    cmd!("iconutil", ~w(-c icns #{logo_dest_tmp_path} -o #{logo_dest_path}))
    File.rm_rf!(logo_dest_tmp_path)
  end

  defp cmd!(bin, args, opts \\ []) do
    {_, 0} = System.cmd(bin, args, [into: IO.stream()] ++ opts)
  end
end
