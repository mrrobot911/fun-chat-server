defmodule FunChat.RateLimiter do
  @moduledoc """
  Hammer rate limiting.
  """

  def check_rate(key, scale \\ 60_000, limit \\ 30) do
    case Hammer.check_rate(key, scale, limit) do
      {:allow, _count} -> :allow
      {:deny, _limit} -> :deny
    end
  end

  def check_user_rate(user_id, action) do
    check_rate("user:#{user_id}:#{action}")
  end

  def check_ip_rate(ip_str, action) do
    check_rate("ip:#{ip_str}:#{action}", 60_000, 60)
  end
end
