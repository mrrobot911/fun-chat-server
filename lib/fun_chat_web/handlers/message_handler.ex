defmodule FunChatWeb.Handlers.MessageHandler do
  @moduledoc "Hanler MSG_SEND."

  alias FunChat.{Chat, Accounts, Presence, Logger, RateLimiter}
  alias FunChatWeb.{Protocol, Guards.AuthGuard}

  def handle_send(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "MSG_SEND", payload)
    current_user = socket.assigns[:current_user]

    with :ok <- AuthGuard.require_auth(socket),
         :allow <- check_user_rate(current_user.id, "MSG_SEND"),
         {:ok, message, from_user, to_user} <- send_message(socket, payload) do
      response = build_send_response(message, from_user, to_user, request_id)
      push_to_recipient(message, from_user, to_user)
      Logger.log_outgoing(request_id, "MSG_SEND", response)
      {:reply, {:ok, response}, socket}
    else
      :deny ->
        reply_error(request_id, "rate limit exceeded", socket)

      {:error, reason} when is_binary(reason) ->
        reply_error(request_id, reason, socket)
    end
  end

  defp send_message(socket, payload) do
    current_user = socket.assigns.current_user

    case payload do
      %{"from" => from_login, "to" => to_login, "text" => text} ->
        if current_user.login != from_login do
          {:error, "from must match current user"}
        else
          case Accounts.get_user_by_login(to_login) do
            nil ->
              {:error, "recipient not found"}

            to_user ->
              case Chat.send_message(current_user.id, to_user.id, text) do
                {:ok, message} -> {:ok, message, current_user, to_user}
                {:error, changeset} -> {:error, format_changeset(changeset)}
              end
          end
        end

      _ ->
        {:error, "incorrect MSG_SEND parameters"}
    end
  end

  defp build_send_response(message, from_user, to_user, request_id) do
    recipient_online = Presence.online?(to_user.id)

    final_message =
      if recipient_online do
        case Chat.mark_message_delivered(message.id) do
          {:ok, updated} -> updated
          _ -> %{message | is_delivered: true}
        end
      else
        message
      end

    Protocol.response(request_id, "MSG_SEND", %{
      message: Protocol.message_payload(final_message, from_user.login, to_user.login)
    })
  end

  defp push_to_recipient(message, from_user, to_user) do
    if Presence.online?(to_user.id) do
      delivered_msg = %{message | is_delivered: true}

      Phoenix.PubSub.broadcast(
        FunChat.PubSub,
        "user:#{to_user.id}",
        {:personal_push, "MSG_SEND",
         %{message: Protocol.message_payload(delivered_msg, from_user.login, to_user.login)}}
      )
    end
  end

  def handle_from_user(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "MSG_FROM_USER", payload)
    current_user = socket.assigns[:current_user]

    with :ok <- AuthGuard.require_auth(socket),
         :allow <- check_user_rate(current_user.id, "MSG_FROM_USER"),
         {:ok, other_user} <- resolve_other_user(payload),
         {:ok, messages} <- fetch_history(socket, other_user, payload) do
      response =
        build_history_response(messages, socket.assigns.current_user, other_user, request_id)

      notify_senders_of_delivery(messages, socket.assigns.current_user)
      Logger.log_outgoing(request_id, "MSG_FROM_USER", response)
      {:reply, {:ok, response}, socket}
    else
      :deny ->
        reply_error(request_id, "rate limit exceeded", socket)

      {:error, reason} when is_binary(reason) ->
        reply_error(request_id, reason, socket)
    end
  end

  def handle_count(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "MSG_COUNT_NOT_READED_FROM_USER", payload)

    with :ok <- AuthGuard.require_auth(socket),
         {:ok, other_user} <- resolve_other_user(payload) do
      count = Chat.count_unread(socket.assigns.current_user.id, other_user.id)

      response =
        Protocol.response(request_id, "MSG_COUNT_NOT_READED_FROM_USER", %{count: count})

      Logger.log_outgoing(request_id, "MSG_COUNT_NOT_READED_FROM_USER", response)
      {:reply, {:ok, response}, socket}
    else
      {:error, reason} when is_binary(reason) ->
        reply_error(request_id, reason, socket)
    end
  end

  defp check_user_rate(user_id, action) do
    FunChat.RateLimiter.check_user_rate(user_id, action)
  end

  defp resolve_other_user(payload) do
    case payload do
      %{"user" => other_login} ->
        case Accounts.get_user_by_login(other_login) do
          nil -> {:error, "user not found"}
          user -> {:ok, user}
        end

      _ ->
        {:error, "missing user field"}
    end
  end

  defp fetch_history(socket, other_user, payload) do
    current_user = socket.assigns.current_user
    limit = Map.get(payload, "limit", 50)
    cursor = Map.get(payload, "cursor")

    parsed_cursor =
      case cursor do
        %{"datetime" => dt, "id" => id} -> {dt, id}
        _ -> nil
      end

    {:ok, Chat.get_history(current_user.id, other_user.id, parsed_cursor, limit)}
  end

  defp build_history_response(messages, current_user, other_user, request_id) do
    payloads =
      Enum.map(messages, fn msg ->
        {from_login, to_login} = resolve_logins(msg, current_user, other_user)
        Protocol.message_payload(msg, from_login, to_login)
      end)

    next_cursor =
      case List.last(messages) do
        nil -> nil
        msg -> %{datetime: msg.datetime, id: msg.id}
      end

    Protocol.response(request_id, "MSG_FROM_USER", %{
      messages: payloads,
      count: length(messages),
      next_cursor: next_cursor
    })
  end

  defp resolve_logins(msg, current_user, other_user) do
    from_login =
      if msg.from_user_id == current_user.id, do: current_user.login, else: other_user.login

    to_login =
      if msg.to_user_id == current_user.id, do: current_user.login, else: other_user.login

    {from_login, to_login}
  end

  defp notify_senders_of_delivery(messages, current_user) do
    messages
    |> Enum.filter(fn msg ->
      msg.to_user_id == current_user.id and msg.from_user_id != current_user.id
    end)
    |> Enum.each(fn msg ->
      Phoenix.PubSub.broadcast(
        FunChat.PubSub,
        "user:#{msg.from_user_id}",
        {:personal_push, "MSG_DELIVER",
         %{message: Protocol.message_payload(%{msg | is_delivered: true}, nil, nil)}}
      )
    end)
  end

  defp format_changeset(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.map(fn {field, {msg, _}} -> "#{field}: #{msg}" end)
    |> Enum.join("; ")
  end

  defp reply_error(request_id, reason, socket) do
    error = Protocol.error(request_id, reason)
    Logger.log_outgoing(request_id, "ERROR", error)
    {:reply, {:ok, error}, socket}
  end
end
