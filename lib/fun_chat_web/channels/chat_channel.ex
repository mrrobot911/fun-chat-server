defmodule FunChatWeb.ChatChannel do
  @moduledoc false
  use FunChatWeb, :channel

  @impl true
  def join("chat:lobby", _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in(type, payload, socket) do
    {:reply, {:ok, %{echo: type, payload: payload}}, socket}
  end
end
