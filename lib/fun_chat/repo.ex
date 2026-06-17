defmodule FunChat.Repo do
  use Ecto.Repo,
    otp_app: :fun_chat,
    adapter: Ecto.Adapters.Postgres
end
