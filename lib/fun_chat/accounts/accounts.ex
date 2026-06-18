defmodule FunChat.Accounts do
  @moduledoc false

  import Ecto.Query, warn: false
  alias FunChat.Repo
  alias FunChat.Accounts.User

  def authenticate(login, password) do
    case get_user_by_login(login) do
      nil -> create_and_handle_user(login, password)
      user -> verify_password(user, password)
    end
  end

  defp create_and_handle_user(login, password) do
    case create_user(%{login: login, password: password}) do
      {:ok, user} ->
        {:ok, user}

      {:error, %Ecto.Changeset{errors: errors}} ->
        if Keyword.has_key?(errors, :login) do
          retry_authenticate(login, password)
        else
          {:error, format_errors(errors)}
        end
    end
  end

  defp verify_password(user, password) do
    if Argon2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      {:error, "incorrect password"}
    end
  end

  defp retry_authenticate(login, password) do
    case get_user_by_login(login) do
      nil -> {:error, "user registration conflict"}
      user -> verify_password(user, password)
    end
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def get_user_by_login(login) do
    Repo.get_by(User, login: login)
  end

  def get_user_by_id(id) do
    Repo.get(User, id)
  end

  def list_users, do: Repo.all(User)

  def delete_all_users do
    {count, _} = Repo.delete_all(User)
    count
  end

  defp format_errors(errors) do
    errors
    |> Enum.map(fn
      {field, {message, _opts}} -> "#{field} #{message}"
      {field, message} -> "#{field} #{message}"
    end)
    |> Enum.join(", ")
  end
end
