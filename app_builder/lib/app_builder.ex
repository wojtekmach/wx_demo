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

    if info_plist = options[:info_plist] do
      File.write!(Path.join([app_bundle_path, "Contents", "Info.plist"]), info_plist)
    end

    release
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
