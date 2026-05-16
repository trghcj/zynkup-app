# Run this script directly on Render using the Shell tab
# Go to your Render dashboard → zynkup_backend → Shell
# Then paste and run this Python script

# This adds all missing columns to your existing PostgreSQL database
# WITHOUT deleting any data

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
print("\n🎉 Migration complete!")
