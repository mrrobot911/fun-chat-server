defmodule FunChat.ConnectionLimiter do
  @moduledoc "Limit IP connections registry (duplicate keys)."

  @registry FunChat.ConnectionRegistry

  def check_limit(ip_str) do
    max_conn = Application.get_env(:fun_chat, :max_connections_per_ip, 10)
    current = count_connections(ip_str)

    if current < max_conn, do: :allow, else: :deny
  end

  def register_connection(ip_str) do
    Registry.register(@registry, {:ip, ip_str}, %{pid: self()})
  end

  def unregister_connection(ref) do
    case ref do
      nil -> :ok
      _ -> Registry.unregister(@registry, ref)
    end
  end

  defp count_connections(ip_str) do
    Registry.lookup(@registry, {:ip, ip_str}) |> length()
  end
end
