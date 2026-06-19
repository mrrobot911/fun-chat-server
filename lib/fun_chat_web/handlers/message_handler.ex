defmodule FunChatWeb.Handlers.MessageHandler do
  @moduledoc "Hanler MSG_SEND."

  alias FunChat.{Chat, Accounts, Presence, Logger}
  alias FunChatWeb.{Protocol, Guards.AuthGuard}

  def handle_send(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "MSG_SEND", payload)

    with :ok <- AuthGuard.require_auth(socket),
         {:ok, message, from_user, to_user} <- send_message(socket, payload) do
      response = build_send_response(message, from_user, to_user, request_id)
      push_to_recipient(message, from_user, to_user)
      Logger.log_outgoing(request_id, "MSG_SEND", response)
      {:reply, {:ok, response}, socket}
    else
      {:error, reason} when is_binary(reason) ->
        reply_error(request_id, reason, socket)

      _ ->
        reply_error(request_id, "incorrect MSG_SEND parameters", socket)
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
