defmodule FunChatWeb.Handlers.UserHandler do
  @moduledoc "Handlers for USER_ACTIVE / USER_INACTIVE."

  alias FunChat.{Accounts, Presence, Logger, RateLimiter}
  alias FunChatWeb.{Protocol, Guards.AuthGuard}

  def handle_active(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "USER_ACTIVE", payload)
    current_user = socket.assigns[:current_user]

    with :ok <- AuthGuard.require_auth(socket),
         :allow <- check_user_rate(current_user.id, "USER_ACTIVE") do
      online_ids = MapSet.new(Presence.online_user_ids())

      users =
        Accounts.list_users()
        |> Enum.filter(fn u -> MapSet.member?(online_ids, u.id) end)
        |> Enum.map(&Protocol.user_payload/1)

      response = Protocol.response(request_id, "USER_ACTIVE", %{users: users})
      Logger.log_outgoing(request_id, "USER_ACTIVE", response)
      {:reply, {:ok, response}, socket}
    else
      :deny ->
        error = Protocol.error(request_id, "rate limit exceeded")
        {:reply, {:ok, error}, socket}

      {:error, reason} ->
        error = Protocol.error(request_id, reason)
        {:reply, {:ok, error}, socket}
    end
  end

  def handle_inactive(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "USER_INACTIVE", payload)
    current_user = socket.assigns[:current_user]

    with :ok <- AuthGuard.require_auth(socket),
         :allow <- check_user_rate(current_user.id, "USER_INACTIVE") do
      online_ids = MapSet.new(Presence.online_user_ids())

      users =
        Accounts.list_users()
        |> Enum.reject(fn u -> MapSet.member?(online_ids, u.id) end)
        |> Enum.map(&Protocol.user_payload/1)

      response = Protocol.response(request_id, "USER_INACTIVE", %{users: users})
      Logger.log_outgoing(request_id, "USER_INACTIVE", response)
      {:reply, {:ok, response}, socket}
    else
      :deny ->
        error = Protocol.error(request_id, "rate limit exceeded")
        {:reply, {:ok, error}, socket}

      {:error, reason} ->
        error = Protocol.error(request_id, reason)
        {:reply, {:ok, error}, socket}
    end
  end

  defp check_user_rate(user_id, action) do
    FunChat.RateLimiter.check_user_rate(user_id, action)
  end
end
