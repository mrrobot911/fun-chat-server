defmodule FunChat.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :text, :text, null: false
      add :datetime, :bigint, null: false
      add :is_delivered, :boolean, default: false, null: false
      add :is_readed, :boolean, default: false, null: false
      add :is_edited, :boolean, default: false, null: false
      add :is_deleted, :boolean, default: false, null: false
      add :from_user_id, references(:users, on_delete: :delete_all), null: false
      add :to_user_id, references(:users, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:messages, [:from_user_id, :to_user_id, :datetime])
    create index(:messages, [:to_user_id, :from_user_id, :datetime])
    create index(:messages, [:to_user_id, :is_delivered, :datetime])
  end
end
