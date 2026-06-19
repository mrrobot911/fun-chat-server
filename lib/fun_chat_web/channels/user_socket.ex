defmodule FunChatWeb.UserSocket do
  use Phoenix.Socket

  channel "chat:*", FunChatWeb.ChatChannel

  @impl true
  def connect(_params, socket, connect_info) do
    ip_str = extract_ip(connect_info)

    case FunChat.ConnectionLimiter.check_limit(ip_str) do
      :allow ->
        {_, ref} = FunChat.ConnectionLimiter.register_connection(ip_str)

        socket =
          socket
          |> assign(:current_user, nil)
          |> assign(:authenticated, false)
          |> assign(:client_ip, ip_str)
          |> assign(:connection_ref, ref)

        {:ok, socket}

      :deny ->
        :error
    end
  end

  @impl true
  def id(_socket), do: nil

  defp extract_ip(%{peer_data: %{address: ip}}) do
    ip |> :inet.ntoa() |> to_string()
  end

  defp extract_ip(_), do: "127.0.0.1"
end
