import sqlite3
import os

try:
    db_path = r'c:\Users\suremdra singh\Desktop\zynkup\zynkup_backend\zynkup.db'
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("ALTER TABLE club_messages ADD COLUMN attachment_url TEXT")
    cursor.execute("ALTER TABLE club_messages ADD COLUMN attachment_type TEXT")
    conn.commit()
    print("Database altered successfully")
except Exception as e:
    print(f"Error: {e}")
finally:
    if conn:
        conn.close()
