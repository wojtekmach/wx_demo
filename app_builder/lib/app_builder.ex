defmodule AppBuilder do
  def create_mac_app_dmg(release, options) do
    release = create_mac_app(release, options)

    app_name = Keyword.fetch!(options, :name)
    File.rm_rf!("tmp/dmg")
    File.mkdir_p!("tmp/dmg")
    File.ln_s!("/Applications", "tmp/dmg/Applications")
    arch = :erlang.system_info(:system_architecture) |> to_string |> String.split("-") |> hd()
    vsn = release.version
    basename = "#{app_name}-#{vsn}-#{arch}.dmg"
    IO.puts(">> creating tmp/dmg/#{basename}")

    cmd!(
      "hdiutil",
      ~w(create tmp/#{app_name}.dmg -ov -volname #{app_name}Install -fs HFS+ -srcfolder tmp/dmg)
    )

    File.rm!("#{Mix.Project.build_path()}/rel/#{basename}")

    cmd!(
      "hdiutil",
      ~w(convert tmp/#{app_name}.dmg -format UDZO -o #{Mix.Project.build_path()}/rel/#{basename})
    )

    File.rm!("tmp/#{app_name}.dmg")
    release
  end

  def create_mac_app(release, options) do
    options =
      keyword_validate!(options, [
        :name,
        :launcher_script,
        :logo_path,
        :info_plist,
        :url_scheme
      ])

    app_name = Keyword.fetch!(options, :name)

    app_bundle_path = Path.join([Mix.Project.build_path(), "rel", "#{app_name}.app"])
    File.rm_rf!(app_bundle_path)
    File.mkdir_p!(Path.join([app_bundle_path, "Contents", "Resources"]))
    File.rename!(release.path, Path.join([app_bundle_path, "Contents", "Resources", "rel"]))

    launcher_script = options[:launcher_script] || launcher_script(release.name, app_name)
    launcher_script_path = Path.join([app_bundle_path, "Contents", "MacOS", app_name])
    File.mkdir_p!(Path.dirname(launcher_script_path))
    File.write!(launcher_script_path, launcher_script)
    File.chmod!(launcher_script_path, 0o700)

    logo_path = options[:logo_path] || Application.app_dir(:wx, "examples/demo/erlang.png")
    create_logo(app_bundle_path, logo_path)

    info_plist = options[:info_plist] || build_info_plist(options)
    File.write!(Path.join([app_bundle_path, "Contents", "Info.plist"]), info_plist)

    release
  end

  defp launcher_script(release_name, app_name) do
    """
    #!/bin/sh
    set -e
    root=$(dirname $(dirname "$0"))
    $root/Resources/rel/bin/#{release_name} start \
      1>> ~/Library/Logs/#{app_name}.stdout.log \
      2>> ~/Library/Logs/#{app_name}.stderr.log
    """
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

  @doc """
  Creates a Windows installer.
  """
  def create_windows_installer(release, options) do
    options =
      keyword_validate!(options, [
        :name,
        :url_scheme
      ])

    app_name = Keyword.fetch!(options, :name)
    url_scheme = Keyword.get(options, :url_scheme)

    File.rm_rf!("tmp")
    File.mkdir_p!("tmp")
    logo_path = "erlang_128px.ico"

    nsi = """
    !include "MUI2.nsh"

    ;--------------------------------
    ;General

    Name "#{app_name}"
    OutFile "#{app_name}Install.exe"
    Unicode True
    InstallDir "$LOCALAPPDATA\\#{app_name}"
    ; need admin for registering URL scheme, otherwise user would suffice.
    RequestExecutionLevel admin

    ;--------------------------------
    ;Interface Settings

    !define MUI_ABORTWARNING

    ;--------------------------------
    ;Pages

    ;!insertmacro MUI_PAGE_COMPONENTS
    !define MUI_ICON "app_icon.ico"
    !insertmacro MUI_PAGE_DIRECTORY
    !insertmacro MUI_PAGE_INSTFILES

    !insertmacro MUI_UNPAGE_CONFIRM
    !insertmacro MUI_UNPAGE_INSTFILES

    ;--------------------------------
    ;Languages

    !insertmacro MUI_LANGUAGE "English"

    ;--------------------------------
    ;Installer Sections

    Section "Dummy Section" SecDummy
      SetOutPath "$INSTDIR"
      ;CopyFiles "${NSISDIR}\\#{app_name}Install.exe" "$INSTDIR\\#{app_name}.exe"
      File /r "rel\\"
      File "#{app_name}.vbs"
      WriteUninstaller "$INSTDIR\\#{app_name}Uninstall.exe"

      ; url scheme
      DetailPrint "Register #{url_scheme} URL Handler"
      DeleteRegKey HKCR "#{url_scheme}"
      WriteRegStr HKCR "#{url_scheme}" "" "URL:#{url_scheme} Protocol"
      WriteRegStr HKCR "#{url_scheme}" "URL Protocol" ""
      WriteRegStr HKCR "#{url_scheme}\\shell" "" ""
      WriteRegStr HKCR "#{url_scheme}\\shell\\open" "" ""
      WriteRegStr HKCR "#{url_scheme}\\shell\\open\\command" "" '$WINDIR\\system32\\wscript.exe "$INSTDIR\\#{app_name}.vbs" "%1"'
    SectionEnd

    Section "Desktop Shortcut" SectionX
      CreateShortCut "$DESKTOP\\#{app_name}.lnk" "$INSTDIR\\#{app_name}.vbs"
    SectionEnd

    Section "Uninstall"
      Delete "$INSTDIR\\#{app_name}Install.exe"
      Delete "$INSTDIR\\#{app_name}Uninstall.exe"
      Delete "$DESKTOP\\#{app_name}.lnk"
      RMDir "$INSTDIR"
    SectionEnd
    """

    File.write!("tmp/#{app_name}.vbs", """
    ' This avoids a flashing cmd window when launching the bat file
    strPath = Left(Wscript.ScriptFullName, Len(Wscript.ScriptFullName) - Len(Wscript.ScriptName)) & "bin\\windows_installer.bat"
    ' Debug: MsgBox(strPath)

    Dim Args()
    ReDim Args(WScript.Arguments.Count - 1)

    For i = 0 To WScript.Arguments.Count - 1
       Args(i) = \"""" & WScript.Arguments(i) & \""""
    Next

    Set WshShell = CreateObject("WScript.Shell" )
    WshShell.Run \"""" & strPath & \""" start -- " & Join(Args), 0
    Set WshShell = Nothing
    """)

    File.rename!(release.path, "tmp/rel")

    File.cp!(logo_path, "tmp/app_icon.ico")
    File.write!("tmp/#{app_name}.nsi", nsi)
    cmd!("makensis", ~w(tmp/#{app_name}.nsi))

    File.rename!(
      "tmp/#{app_name}Install.exe",
      Path.join([Mix.Project.build_path(), "rel", "#{app_name}Install.exe"])
    )

    release
  end

  ## Utilities

  defp cmd!(bin, args, opts \\ []) do
    {_, 0} = System.cmd(bin, args, [into: IO.stream()] ++ opts)
  end

  # TODO: use Keyword.validate! when we require Elixir 1.13
  defp keyword_validate(keyword, values) when is_list(keyword) and is_list(values) do
    validate(keyword, values, [], [], [])
  end

  defp validate([{key, _} = pair | keyword], values1, values2, acc, bad_keys)
       when is_atom(key) do
    case find_key!(key, values1, values2) do
      {values1, values2} ->
        validate(keyword, values1, values2, [pair | acc], bad_keys)

      :error ->
        case find_key!(key, values2, values1) do
          {values1, values2} ->
            validate(keyword, values1, values2, [pair | acc], bad_keys)

          :error ->
            validate(keyword, values1, values2, acc, [key | bad_keys])
        end
    end
  end

  defp validate([], values1, values2, acc, []) do
    {:ok, move_pairs!(values1, move_pairs!(values2, acc))}
  end

  defp validate([], _values1, _values2, _acc, bad_keys) do
    {:error, bad_keys}
  end

  defp validate([pair | _], _values1, _values2, _acc, []) do
    raise ArgumentError,
          "expected a keyword list as first argument, got invalid entry: #{inspect(pair)}"
  end

  defp find_key!(key, [key | rest], acc), do: {rest, acc}
  defp find_key!(key, [{key, _} | rest], acc), do: {rest, acc}
  defp find_key!(key, [head | tail], acc), do: find_key!(key, tail, [head | acc])
  defp find_key!(_key, [], _acc), do: :error

  defp move_pairs!([key | rest], acc) when is_atom(key),
    do: move_pairs!(rest, acc)

  defp move_pairs!([{key, _} = pair | rest], acc) when is_atom(key),
    do: move_pairs!(rest, [pair | acc])

  defp move_pairs!([], acc),
    do: acc

  defp move_pairs!([other | _], _) do
    raise ArgumentError,
          "expected the second argument to be a list of atoms or tuples, got: #{inspect(other)}"
  end

  defp keyword_validate!(keyword, values) do
    case keyword_validate(keyword, values) do
      {:ok, kw} ->
        kw

      {:error, invalid_keys} ->
        keys =
          for value <- values,
              do: if(is_atom(value), do: value, else: elem(value, 0))

        raise ArgumentError,
              "unknown keys #{inspect(invalid_keys)} in #{inspect(keyword)}, the allowed keys are: #{inspect(keys)}"
    end
  end
end
