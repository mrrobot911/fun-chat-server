defmodule FunChat.Presence do
  use Phoenix.Presence,
    otp_app: :fun_chat,
    pubsub_server: FunChat.PubSub

  @topic "online_users"

  @doc """
  Marks user as online (process-based).
  """
  def track_user(user_id, meta \\ %{}) do
    track(
      self(),
      @topic,
      to_string(user_id),
      Map.merge(meta, %{
        online_at: System.system_time(:millisecond)
      })
    )
  end

  @doc """
  Marks user as offline.
  """
  def untrack_user(user_id) do
    untrack(self(), @topic, to_string(user_id))
  end

  def online?(user_id) do
    case get_by_key(@topic, to_string(user_id)) do
      %{metas: [_ | _]} -> true
      _ -> false
    end
  end

  def online_user_ids do
    list(@topic)
    |> Map.keys()
  end
end
