defmodule FunChatWeb.Handlers.AuthHandler do
  @moduledoc """
  Handler for USER_LOGIN, USER_LOGOUT and terminate logic.
  """

  alias FunChat.{Accounts, Presence}
  alias FunChatWeb.Protocol
  alias FunChat.Logger

  import Phoenix.Socket, only: [assign: 3]

  def handle_login(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "USER_LOGIN", payload)

    case payload do
      %{"user" => %{"login" => login, "password" => password}} ->
        case Accounts.authenticate(login, password) do
          {:ok, user} ->
            if Presence.online?(user.id) do
              reply_error(request_id, "a user with this login is already authorized", socket)
            else
              case Presence.track_user(user.id) do
                {:ok, _} ->
                  socket = assign_user(socket, user)
                  subscribe_to_personal_topic(user.id)
                  broadcast_external_login(user)

                  response =
                    Protocol.response(request_id, "USER_LOGIN", %{
                      user: Protocol.user_payload(user)
                    })

                  Logger.log_outgoing(request_id, "USER_LOGIN", response)
                  {:reply, {:ok, response}, socket}

                {:error, reason} ->
                  reply_error(request_id, "presence error: #{inspect(reason)}", socket)
              end
            end

          {:error, reason} when is_binary(reason) ->
            reply_error(request_id, reason, socket)

          _ ->
            reply_error(request_id, "authentication failed", socket)
        end

      _ ->
        reply_error(request_id, "incorrect USER_LOGIN parameters", socket)
    end
  end

  def handle_logout(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "USER_LOGOUT", payload)

    case socket.assigns[:current_user] do
      nil ->
        reply_error(request_id, "user is not authorized", socket)

      user ->
        Presence.untrack_user(user.id)
        broadcast_external_logout(user)

        response = Protocol.response(request_id, "USER_LOGOUT", %{})
        Logger.log_outgoing(request_id, "USER_LOGOUT", response)

        socket =
          socket
          |> assign(:current_user, nil)
          |> assign(:authenticated, false)

        {:reply, {:ok, response}, socket}
    end
  end

  def handle_terminate(socket) do
    case socket.assigns[:current_user] do
      nil ->
        :ok

      user ->
        Presence.untrack_user(user.id)
        broadcast_external_logout(user)
    end
  end

  defp assign_user(socket, user) do
    socket
    |> assign(:current_user, user)
    |> assign(:authenticated, true)
  end

  defp subscribe_to_personal_topic(user_id) do
    Phoenix.PubSub.subscribe(FunChat.PubSub, "user:#{user_id}")
  end

  defp broadcast_external_login(user) do
    Phoenix.PubSub.broadcast(
      FunChat.PubSub,
      "chat:lobby",
      {:external_event, "USER_EXTERNAL_LOGIN", %{user: Protocol.user_payload(user)}}
    )
  end

  defp broadcast_external_logout(user) do
    Phoenix.PubSub.broadcast(
      FunChat.PubSub,
      "chat:lobby",
      {:external_event, "USER_EXTERNAL_LOGOUT", %{user: %{login: user.login, isLogined: false}}}
    )
  end

  defp reply_error(request_id, reason, socket) do
    error = Protocol.error(request_id, reason)
    Logger.log_outgoing(request_id, "ERROR", error)
    {:reply, {:ok, error}, socket}
  end
end
