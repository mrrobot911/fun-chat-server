defmodule FunChat.Chat.Message do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "messages" do
    field :text, :string
    field :datetime, :integer
    field :is_delivered, :boolean, default: false
    field :is_readed, :boolean, default: false
    field :is_edited, :boolean, default: false
    field :is_deleted, :boolean, default: false

    belongs_to :from_user, FunChat.Accounts.User, foreign_key: :from_user_id
    belongs_to :to_user, FunChat.Accounts.User, foreign_key: :to_user_id

    timestamps(type: :utc_datetime)
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:from_user_id, :to_user_id, :text, :datetime])
    |> validate_required([:from_user_id, :to_user_id, :text, :datetime])
    |> validate_length(:text, min: 1, max: 10_000)
    |> validate_not_self_message()
    |> foreign_key_constraint(:from_user_id)
    |> foreign_key_constraint(:to_user_id)
  end

  def update_text_changeset(message, attrs) do
    message
    |> cast(attrs, [:text, :is_edited])
    |> validate_required([:text])
    |> validate_length(:text, min: 1, max: 10_000)
  end

  def update_status_changeset(message, attrs) do
    message
    |> cast(attrs, [:is_delivered, :is_readed, :is_deleted])
  end

  defp validate_not_self_message(changeset) do
    validate_change(changeset, :to_user_id, fn :to_user_id, to_user_id ->
      from_user_id = get_field(changeset, :from_user_id)

      if from_user_id && to_user_id && from_user_id == to_user_id do
        [to_user_id: "cannot send message to self"]
      else
        []
      end
    end)
  end
end
