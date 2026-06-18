defmodule FunChat.ChatTest do
  use FunChat.DataCase
  alias FunChat.{Chat, Accounts}

  setup do
    {:ok, alice} = Accounts.create_user(%{login: "alice", password: "pass"})
    {:ok, bob} = Accounts.create_user(%{login: "bob", password: "pass"})
    %{alice: alice, bob: bob}
  end

  test "send_message creates message", %{alice: alice, bob: bob} do
    assert {:ok, msg} = Chat.send_message(alice.id, bob.id, "Hello")
    assert msg.text == "Hello"
    assert msg.from_user_id == alice.id
  end

  test "rejects self-messages", %{alice: alice} do
    assert {:error, changeset} = Chat.send_message(alice.id, alice.id, "Hi")
    assert %{to_user_id: ["cannot send message to self"]} = errors_on(changeset)
  end

  test "edit_message only by sender", %{alice: alice, bob: bob} do
    {:ok, msg} = Chat.send_message(alice.id, bob.id, "Original")

    assert {:ok, edited} = Chat.edit_message(msg.id, "Edited", alice.id)
    assert edited.text == "Edited"
    assert edited.is_edited == true

    assert {:error, _} = Chat.edit_message(msg.id, "Hacked", bob.id)
  end
end
