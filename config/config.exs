import Config

config :fun_chat,
  ecto_repos: [FunChat.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :fun_chat, FunChatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: FunChatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: FunChat.PubSub,
  live_view: [signing_salt: "Z5F3cQhH"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Config Hammer
config :hammer,
  backend:
    {Hammer.Backend.ETS,
     [
       expiry_ms: :timer.hours(2),
       cleanup_interval_ms: :timer.minutes(5)
     ]}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
