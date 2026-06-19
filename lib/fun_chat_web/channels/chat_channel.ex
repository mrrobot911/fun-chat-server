defmodule FunChatWeb.ChatChannel do
  use FunChatWeb, :channel

  alias FunChatWeb.Handlers.AuthHandler
  alias FunChatWeb.Protocol

  @impl true
  def join("chat:lobby", _payload, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  @impl true
  def handle_info(:after_join, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:external_event, event, payload}, socket) do
    current_user = socket.assigns[:current_user]
    event_login = get_in(payload, [:user, :login])

    should_send =
      cond do
        is_nil(current_user) ->
          false

        event in ["USER_EXTERNAL_LOGIN", "USER_EXTERNAL_LOGOUT"] ->
          event_login != current_user.login

        true ->
          true
      end

    if should_send do
      push(socket, event, payload)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:personal_push, event, payload}, socket) do
    push(socket, event, Protocol.push(event, payload))
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_in("USER_LOGIN", payload, socket),
    do: AuthHandler.handle_login(payload, socket)

  def handle_in("USER_LOGOUT", payload, socket),
    do: AuthHandler.handle_logout(payload, socket)

  def handle_in("MSG_SEND", payload, socket),
    do: FunChatWeb.Handlers.MessageHandler.handle_send(payload, socket)

  def handle_in("MSG_FROM_USER", payload, socket),
    do: FunChatWeb.Handlers.MessageHandler.handle_from_user(payload, socket)

  def handle_in(type, payload, socket) do
    request_id = Map.get(payload, "id")

    error = FunChatWeb.Protocol.error(request_id, "unknown or not implemented: #{type}")
    {:reply, {:ok, error}, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    AuthHandler.handle_terminate(socket)
    :ok
  end
end
