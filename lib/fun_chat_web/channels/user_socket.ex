defmodule FunChatWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", FunChatWeb.ChatChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    socket =
      socket
      |> assign(:current_user, nil)
      |> assign(:authenticated, false)

    {:ok, socket}
  end

  @impl true
  def id(socket) do
    case socket.assigns[:current_user] do
      nil -> nil
      user -> "user_socket:#{user.id}"
    end
  end
end
