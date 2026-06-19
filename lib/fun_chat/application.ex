defmodule FunChat.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FunChatWeb.Telemetry,
      FunChat.Repo,
      {DNSCluster, query: Application.get_env(:fun_chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: FunChat.PubSub},
      {Registry, keys: :duplicate, name: FunChat.ConnectionRegistry},
      FunChat.Presence,
      # Start a worker by calling: FunChat.Worker.start_link(arg)
      # {FunChat.Worker, arg},
      # Start to serve requests, typically the last entry
      FunChatWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FunChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FunChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
