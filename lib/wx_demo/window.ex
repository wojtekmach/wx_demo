defmodule WxDemo.Window do
  @moduledoc false

  @behaviour :wx_object

  # https://github.com/erlang/otp/blob/OTP-24.1.2/lib/wx/include/wx.hrl#L1314
  @wx_id_exit 5006

  def start_link(_) do
    {:wx_ref, _, _, pid} = :wx_object.start_link(__MODULE__, [], [])
    {:ok, pid}
  end

  def child_spec(init_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_arg]},
      restart: :transient
    }
  end

  @impl true
  def init(_) do
    title = "WxDemo"

    wx = :wx.new()
    frame = :wxFrame.new(wx, -1, title)
    fixup_macos_menubar(frame, title)
    :wxFrame.show(frame)
    :wxFrame.connect(frame, :command_menu_selected)
    :wxFrame.connect(frame, :close_window, skip: true)
    :wx.subscribe_events()
    state = %{frame: frame}
    {frame, state}
  end

  @impl true
  def handle_event({:wx, @wx_id_exit, _, _, _}, state) do
    :init.stop()
    {:stop, :normal, state}
  end

  @impl true
  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, state) do
    :init.stop()
    {:stop, :normal, state}
  end

  # TODO: investigate "Universal Links" [1], that is, instead of livebook://foo, we have
  # https://livebook.dev/foo, which means the link works with and without Livebook.app.
  #
  # [1] https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content
  @impl true
  def handle_info({:open_url, url}, state) do
    :wxMessageDialog.new(state.frame, inspect(url))
    |> :wxDialog.showModal()

    {:noreply, state}
  end

  @impl true
  # ignore other events
  def handle_info(_event, state) do
    {:noreply, state}
  end

  defp fixup_macos_menubar(frame, title) do
    menubar = :wxMenuBar.new()
    # :wxMenuBar.setAutoWindowMenu(false)
    :wxFrame.setMenuBar(frame, menubar)

    # App Menu
    menu = :wxMenuBar.oSXGetAppleMenu(menubar)

    # TODO: remove when https://github.com/erlang/otp/pull/5393 is released
    :wxMenu.setTitle(menu, title)

    # Remove all items except for quit
    for item <- :wxMenu.getMenuItems(menu) do
      if :wxMenuItem.getId(item) == @wx_id_exit do
        :wxMenuItem.setText(item, "Quit #{title}\tCtrl+Q")
      else
        :wxMenu.delete(menu, item)
      end
    end
  end
end