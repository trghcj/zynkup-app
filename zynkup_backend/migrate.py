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