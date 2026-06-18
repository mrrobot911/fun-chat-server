defmodule FunChat.AccountsTest do
  use FunChat.DataCase

  alias FunChat.Accounts

  describe "authenticate/2" do
    test "creates new user" do
      assert {:ok, user} = Accounts.authenticate("alice", "password123")
      assert user.login == "alice"
    end

    test "authenticates existing user" do
      {:ok, _} = Accounts.authenticate("alice", "password123")
      assert {:ok, user} = Accounts.authenticate("alice", "password123")
      assert user.login == "alice"
    end

    test "rejects wrong password" do
      {:ok, _} = Accounts.authenticate("alice", "password123")
      assert {:error, "incorrect password"} = Accounts.authenticate("alice", "wrong")
    end
  end
end
