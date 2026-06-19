alias FunChat.Accounts

users = [
  %{login: "alice", password: "alice123"},
  %{login: "bob", password: "bob123"}
]

for attrs <- users do
  case Accounts.get_user_by_login(attrs.login) do
    nil ->
      case Accounts.create_user(attrs) do
        {:ok, _} -> IO.puts("Created: #{attrs.login}")
        {:error, reason} -> IO.puts("Failed: #{inspect(reason)}")
      end

    _ ->
      IO.puts("Exists: #{attrs.login}")
  end
end
