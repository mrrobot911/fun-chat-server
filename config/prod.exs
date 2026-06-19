import Config

# Force using SSL in production. This also sets the "strict-security-transport" header,
# known as HSTS. If you have a health check endpoint, you may want to exclude it below.
# Note `:force_ssl` is required to be set at compile-time.
config :fun_chat, FunChatWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  server: true,
  force_ssl: [
    rewrite_on: [:x_forwarded_proto],
    exclude: [
      # paths: ["/health"],
      hosts: ["localhost", "127.0.0.1"]
    ]
  ]

# Do not print debug messages in production
config :logger, level: :info

config :argon2_elixir, t_cost: 3, m_cost: 16

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
