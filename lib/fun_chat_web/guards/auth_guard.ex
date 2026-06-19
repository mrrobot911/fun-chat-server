defmodule FunChatWeb.Guards.AuthGuard do
  @moduledoc """
  Authentication guard for channel handlers.
  """
  def require_auth(socket) do
    case socket.assigns[:current_user] do
      nil -> {:error, "user is not authorized"}
      _user -> :ok
    end
  end
end
