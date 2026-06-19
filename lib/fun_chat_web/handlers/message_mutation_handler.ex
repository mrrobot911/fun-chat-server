defmodule FunChatWeb.Handlers.MessageMutationHandler do
  @moduledoc "Handler for MSG_READ / MSG_DELETE / MSG_EDIT."

  alias FunChat.{Chat, Logger, RateLimiter}
  alias FunChatWeb.{Protocol, Guards.AuthGuard}

  def handle_read(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "MSG_READ", payload)
    current_user = socket.assigns[:current_user]

    with :ok <- AuthGuard.require_auth(socket),
         :allow <- check_user_rate(current_user.id, "MSG_READ"),
         %{"id" => message_id} <- payload,
         {:ok, message} <- Chat.mark_as_read(message_id, socket.assigns.current_user.id),
         false <- message.is_deleted do
      response =
        Protocol.response(request_id, "MSG_READ", %{
          message: Protocol.message_payload(message, nil, nil)
        })

      notify_sender("MSG_READ", message)
      Logger.log_outgoing(request_id, "MSG_READ", response)
      {:reply, {:ok, response}, socket}
    else
      :deny -> reply_error(request_id, "rate limit exceeded", socket)
      true -> reply_error(request_id, "message is deleted", socket)
      {:error, reason} when is_binary(reason) -> reply_error(request_id, reason, socket)
      _ -> reply_error(request_id, "incorrect MSG_READ parameters", socket)
    end
  end

  def handle_delete(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "MSG_DELETE", payload)
    current_user = socket.assigns[:current_user]

    with :ok <- AuthGuard.require_auth(socket),
         :allow <- check_user_rate(current_user.id, "MSG_DELETE"),
         %{"id" => message_id} <- payload,
         {:ok, message} <- Chat.delete_message(message_id, socket.assigns.current_user.id) do
      response =
        Protocol.response(request_id, "MSG_DELETE", %{
          message: Protocol.message_payload(message, nil, nil)
        })

      notify_recipient("MSG_DELETE", message)
      Logger.log_outgoing(request_id, "MSG_DELETE", response)
      {:reply, {:ok, response}, socket}
    else
      :deny -> reply_error(request_id, "rate limit exceeded", socket)
      {:error, reason} when is_binary(reason) -> reply_error(request_id, reason, socket)
      _ -> reply_error(request_id, "incorrect MSG_DELETE parameters", socket)
    end
  end

  def handle_edit(payload, socket) do
    request_id = Map.get(payload, "id")
    Logger.log_incoming(request_id, "MSG_EDIT", payload)
    current_user = socket.assigns[:current_user]

    with :ok <- AuthGuard.require_auth(socket),
         :allow <- check_user_rate(current_user.id, "MSG_EDIT"),
         %{"id" => message_id, "text" => new_text} <- payload,
         %FunChat.Chat.Message{is_deleted: false} <-
           FunChat.Repo.get(FunChat.Chat.Message, message_id),
         {:ok, message} <- Chat.edit_message(message_id, new_text, socket.assigns.current_user.id) do
      response =
        Protocol.response(request_id, "MSG_EDIT", %{
          message: Protocol.message_payload(message, nil, nil)
        })

      notify_recipient("MSG_EDIT", message)
      Logger.log_outgoing(request_id, "MSG_EDIT", response)
      {:reply, {:ok, response}, socket}
    else
      :deny ->
        reply_error(request_id, "rate limit exceeded", socket)

      %FunChat.Chat.Message{is_deleted: true} ->
        reply_error(request_id, "cannot edit deleted message", socket)

      nil ->
        reply_error(request_id, "message not found", socket)

      {:error, reason} when is_binary(reason) ->
        reply_error(request_id, reason, socket)

      _ ->
        reply_error(request_id, "incorrect MSG_EDIT parameters", socket)
    end
  end

  defp check_user_rate(user_id, action) do
    FunChat.RateLimiter.check_user_rate(user_id, action)
  end

  defp notify_sender(event, message) do
    Phoenix.PubSub.broadcast(
      FunChat.PubSub,
      "user:#{message.from_user_id}",
      {:personal_push, event, %{message: Protocol.message_payload(message, nil, nil)}}
    )
  end

  defp notify_recipient(event, message) do
    Phoenix.PubSub.broadcast(
      FunChat.PubSub,
      "user:#{message.to_user_id}",
      {:personal_push, event, %{message: Protocol.message_payload(message, nil, nil)}}
    )
  end

  defp reply_error(request_id, reason, socket) do
    error = Protocol.error(request_id, reason)
    Logger.log_outgoing(request_id, "ERROR", error)
    {:reply, {:ok, error}, socket}
  end
end
