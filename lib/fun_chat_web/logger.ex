defmodule FunChat.Logger do
  @moduledoc """
  Structured logger with sensitive data sanitization.
  """

  require Logger

  @sensitive_keys ~w(password password_hash)

  def log(direction, id, type, payload) do
    level = Application.get_env(:fun_chat, :log_level, "ALL")
    safe_payload = sanitize(payload)

    cond do
      level == "NONE" -> :ok
      level == "ALL" -> do_log(direction, id, type, safe_payload)
      level == "INCOMING" and direction == "INCOMING" -> do_log(direction, id, type, safe_payload)
      level == "OUTGOING" and direction == "OUTGOING" -> do_log(direction, id, type, safe_payload)
      level == "ERROR" and type == "ERROR" -> do_log(direction, id, type, safe_payload)
      true -> :ok
    end
  end

  def log_incoming(id, type, payload), do: log("INCOMING", id, type, payload)
  def log_outgoing(id, type, payload), do: log("OUTGOING", id, type, payload)

  defp do_log(direction, id, type, payload) do
    Logger.info(
      "[#{direction}] id=#{inspect(id)} type=#{type} payload=#{inspect(payload, pretty: true, limit: 500)}"
    )
  end

  defp sanitize(payload) when is_map(payload) do
    payload
    |> Enum.map(fn {k, v} ->
      cond do
        to_string(k) in @sensitive_keys -> {k, "[FILTERED]"}
        is_map(v) -> {k, sanitize(v)}
        true -> {k, v}
      end
    end)
    |> Map.new()
  end

  defp sanitize(payload), do: payload
end
