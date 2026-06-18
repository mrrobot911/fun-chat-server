defmodule FunChat.Chat do
  @moduledoc false

  import Ecto.Query, warn: false
  alias FunChat.Repo
  alias FunChat.Chat.Message

  @max_page_size 500

  def send_message(from_user_id, to_user_id, text) do
    %Message{}
    |> Message.changeset(%{
      from_user_id: from_user_id,
      to_user_id: to_user_id,
      text: text,
      datetime: System.system_time(:millisecond)
    })
    |> Repo.insert()
  end

  def get_history(current_user_id, other_user_id, cursor \\ nil, limit \\ 50) do
    limit = min(max(limit, 1), @max_page_size)

    base_query =
      from(m in Message,
        where:
          (m.from_user_id == ^current_user_id and m.to_user_id == ^other_user_id) or
          (m.from_user_id == ^other_user_id and m.to_user_id == ^current_user_id),
        order_by: [asc: m.datetime, asc: m.id],
        limit: ^limit
      )

    query = apply_cursor(base_query, cursor)
    messages = Repo.all(query)

    # side effect
    mark_as_delivered(current_user_id, other_user_id)

    messages
  end

  defp apply_cursor(query, nil), do: query

  defp apply_cursor(query, {cursor_datetime, cursor_id}) do
    from(m in query,
      where:
        m.datetime > ^cursor_datetime or
        (m.datetime == ^cursor_datetime and m.id > ^cursor_id)
    )
  end

  def mark_as_delivered(current_user_id, other_user_id) do
    query =
      from(m in Message,
        where:
          m.from_user_id == ^other_user_id and m.to_user_id == ^current_user_id and
          m.is_delivered == false,
        select: m.id
      )

    message_ids = Repo.all(query)

    if message_ids != [] do
      from(m in Message, where: m.id in ^message_ids)
      |> Repo.update_all(set: [is_delivered: true])
    end

    message_ids
  end

  def mark_message_delivered(message_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, :not_found}
      message ->
        message
        |> Message.update_status_changeset(%{is_delivered: true})
        |> Repo.update()
    end
  end

  def count_unread(current_user_id, other_user_id) do
    from(m in Message,
      where:
        m.from_user_id == ^other_user_id and m.to_user_id == ^current_user_id and
        m.is_readed == false and m.is_deleted == false,
      select: count(m.id)
    )
    |> Repo.one()
  end

  def mark_as_read(message_id, user_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, "message not found"}
      %Message{to_user_id: ^user_id} = message ->
        message
        |> Message.update_status_changeset(%{is_readed: true})
        |> Repo.update()
      _ -> {:error, "access denied"}
    end
  end

  def delete_message(message_id, user_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, "message not found"}
      %Message{from_user_id: ^user_id} = message ->
        message
        |> Message.update_status_changeset(%{is_deleted: true})
        |> Repo.update()
      _ -> {:error, "access denied"}
    end
  end

  def edit_message(message_id, new_text, user_id) do
    case Repo.get(Message, message_id) do
      nil -> {:error, "message not found"}
      %Message{from_user_id: ^user_id} = message ->
        message
        |> Message.update_text_changeset(%{text: new_text, is_edited: true})
        |> Repo.update()
      _ -> {:error, "access denied"}
    end
  end

  def delete_all_messages do
    {count, _} = Repo.delete_all(Message)
    count
  end
end
