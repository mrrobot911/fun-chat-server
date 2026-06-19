defmodule FunChatWeb.Protocol do
  @moduledoc """
  Protocol layer for formatting messages according to fun-chat-server contract.
  """

  def response(id, type, payload) do
    %{id: id, type: type, payload: payload}
  end

  def error(id, message) do
    %{id: id, type: "ERROR", payload: %{error: message}}
  end

  def push(type, payload) do
    %{id: nil, type: type, payload: payload}
  end

  def user_payload(user) do
    %{
      login: user.login,
      isLogined: FunChat.Presence.online?(user.id)
    }
  end

  def message_payload(message, from_login, to_login) do
    %{
      id: message.id,
      from: from_login,
      to: to_login,
      text: message.text,
      datetime: message.datetime,
      status: %{
        isDelivered: message.is_delivered,
        isReaded: message.is_readed,
        isEdited: message.is_edited,
        isDeleted: message.is_deleted
      }
    }
  end
end
