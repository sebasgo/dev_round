defmodule DevRound.Repo.Migrations.DecoupleTeamMembersFromAttendees do
  use Ecto.Migration

  def up do
    # 1. Add new columns to team_members (nullable initially for data migration)
    alter table(:team_members) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :is_remote, :boolean
      add :experience_level, :integer
    end

    flush()

    # 2. Populate new columns from event_attendees
    execute("""
    UPDATE team_members
    SET user_id = ea.user_id,
        is_remote = ea.is_remote,
        experience_level = ea.experience_level
    FROM event_attendees ea
    WHERE team_members.event_attendee_id = ea.id
    """)

    # 3. Create team_member_langs join table
    create table(:team_member_langs, primary_key: false) do
      add :team_member_id, references(:team_members, on_delete: :delete_all), null: false
      add :lang_id, references(:langs, on_delete: :delete_all), null: false
    end

    create unique_index(:team_member_langs, [:team_member_id, :lang_id])

    flush()

    # 4. Copy attendee langs to team_member_langs for existing team members
    execute("""
    INSERT INTO team_member_langs (team_member_id, lang_id)
    SELECT tm.id, eal.lang_id
    FROM team_members tm
    JOIN event_attendees_langs eal ON eal.event_attendee_id = tm.event_attendee_id
    """)

    # 5. Make new columns NOT NULL (after data is populated)
    alter table(:team_members) do
      modify :is_remote, :boolean, null: false
      modify :experience_level, :integer, null: false
    end

    # 6. Drop old unique index and column
    drop unique_index(:team_members, [:team_id, :event_attendee_id])

    alter table(:team_members) do
      remove :event_attendee_id
    end

    # 7. Add new unique index
    create unique_index(:team_members, [:team_id, :user_id])
    create index(:team_members, [:user_id])
  end

  def down do
    # Remove new index
    drop unique_index(:team_members, [:team_id, :user_id])
    drop index(:team_members, [:user_id])

    # Re-add event_attendee_id column
    alter table(:team_members) do
      add :event_attendee_id, references(:event_attendees, on_delete: :delete_all)
    end

    flush()

    # Best-effort: try to restore event_attendee_id from user_id + team → session → event
    execute("""
    UPDATE team_members
    SET event_attendee_id = ea.id
    FROM teams t, event_sessions es, event_attendees ea
    WHERE t.id = team_members.team_id
      AND es.id = t.session_id
      AND ea.event_id = es.event_id
      AND ea.user_id = team_members.user_id
    """)

    create unique_index(:team_members, [:team_id, :event_attendee_id])

    # Drop team_member_langs
    drop table(:team_member_langs)

    # Remove new columns
    alter table(:team_members) do
      remove :user_id
      remove :is_remote
      remove :experience_level
    end
  end
end
