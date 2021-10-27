CREATE TABLE "outbound" (
  "id" INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  "created_at" INTEGER NOT NULL,
  "status" INTEGER NOT NULL,
  "updated_at" INTEGER,
  "message" TEXT NOT NULL,
  "encrypted_file_path" TEXT,
  "subject" TEXT NOT NULL
);
