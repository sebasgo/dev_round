defmodule DevRound.Repo.Migrations.AddFulltextIndexToEvents do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE events
      ADD COLUMN  searchable_text tsvector
      GENERATED ALWAYS AS (
        setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(teaser, '')), 'B') ||
        setweight(to_tsvector('english', coalesce(body, '')), 'B')
      ) STORED;
    """)

    execute("""
    CREATE INDEX events_searchable_text_idx ON events USING GIN(searchable_text);
    """)
  end

  def down do
    execute("DROP INDEX events_searchable_text_idx;")
    execute("ALTER TABLE events DROP COLUMN searchable_text;")
  end
end
