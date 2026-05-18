
import os
import psycopg2

DATABASE_URL = os.getenv("DATABASE_URL")

conn = psycopg2.connect(DATABASE_URL)
cur = conn.cursor()

migrations = [
    "ALTER TABLE events ADD COLUMN IF NOT EXISTS creator_id INTEGER REFERENCES users(id)",
    "ALTER TABLE events ADD COLUMN IF NOT EXISTS image_urls TEXT DEFAULT ''",
    "ALTER TABLE events ADD COLUMN IF NOT EXISTS gallery_files TEXT DEFAULT ''",
    "ALTER TABLE events ADD COLUMN IF NOT EXISTS registration_url VARCHAR",
    "ALTER TABLE events ADD COLUMN IF NOT EXISTS registration_url_type VARCHAR",
    "ALTER TABLE events ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW()",
    "ALTER TABLE events ADD COLUMN IF NOT EXISTS is_reported BOOLEAN DEFAULT FALSE NOT NULL",
    "ALTER TABLE events ADD COLUMN IF NOT EXISTS report_count INTEGER DEFAULT 0 NOT NULL",
    """
    DO $$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name='events'
              AND column_name='image_urls'
              AND data_type='ARRAY'
        ) THEN
            ALTER TABLE events
            ALTER COLUMN image_urls DROP DEFAULT,
            ALTER COLUMN image_urls TYPE TEXT
                USING COALESCE(array_to_string(image_urls, ','), ''),
            ALTER COLUMN image_urls SET DEFAULT '';
        END IF;

        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name='events'
              AND column_name='gallery_files'
              AND data_type='ARRAY'
        ) THEN
            ALTER TABLE events
            ALTER COLUMN gallery_files DROP DEFAULT,
            ALTER COLUMN gallery_files TYPE TEXT
                USING COALESCE(array_to_string(gallery_files, '|||---|||'), ''),
            ALTER COLUMN gallery_files SET DEFAULT '';
        END IF;
    END $$;
    """,
    """
    DO $$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_name='events' AND column_name='organizer_id'
        ) THEN
            UPDATE events
            SET creator_id = organizer_id
            WHERE creator_id IS NULL AND organizer_id IS NOT NULL;
        END IF;
    END $$;
    """,
]

for sql in migrations:
    try:
        cur.execute(sql)
        print(f"✅ {sql[:60]}...")
    except Exception as e:
        print(f"⚠️  Skipped (already exists): {e}")

conn.commit()
cur.close()
conn.close()
print("\n Migration complete!")
