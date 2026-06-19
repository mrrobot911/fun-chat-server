defmodule FunChatWeb.Handlers.UserHandler do
  @moduledoc "Handlers for USER_ACTIVE / USER_INACTIVE."

  alias FunChat.{Accounts, Presence, Logger}
  alias FunChatWeb.{Protocol, Guards.AuthGuard}

  def handle_active(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "USER_ACTIVE", payload)

    with :ok <- AuthGuard.require_auth(socket) do
      online_ids = MapSet.new(Presence.online_user_ids())

      users =
        Accounts.list_users()
        |> Enum.filter(fn u -> MapSet.member?(online_ids, u.id) end)
        |> Enum.map(&Protocol.user_payload/1)

      response = Protocol.response(request_id, "USER_ACTIVE", %{users: users})
      Logger.log_outgoing(request_id, "USER_ACTIVE", response)
      {:reply, {:ok, response}, socket}
    else
      {:error, reason} ->
        error = Protocol.error(request_id, reason)
        {:reply, {:ok, error}, socket}
    end
  end

  def handle_inactive(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "USER_INACTIVE", payload)

    with :ok <- AuthGuard.require_auth(socket) do
      online_ids = MapSet.new(Presence.online_user_ids())

      users =
        Accounts.list_users()
        |> Enum.reject(fn u -> MapSet.member?(online_ids, u.id) end)
        |> Enum.map(&Protocol.user_payload/1)

      response = Protocol.response(request_id, "USER_INACTIVE", %{users: users})
      Logger.log_outgoing(request_id, "USER_INACTIVE", response)
      {:reply, {:ok, response}, socket}
    else
      {:error, reason} ->
        error = Protocol.error(request_id, reason)
        {:reply, {:ok, error}, socket}
    end
  end
end
