-- Migration 0025: Tambah kolom interaksi story (likes dan reposts)
ALTER TABLE stories ADD COLUMN likes INTEGER NOT NULL DEFAULT 0;
ALTER TABLE stories ADD COLUMN reposts INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS story_likes (
  story_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  dibuat TEXT NOT NULL,
  PRIMARY KEY (story_id, user_id),
  FOREIGN KEY (story_id) REFERENCES stories(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
