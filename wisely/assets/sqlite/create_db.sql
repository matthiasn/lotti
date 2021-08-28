
CREATE TABLE "entry_story_edges" (
  "entry_story_edge_id" TEXT NOT NULL,
  "story_id" TEXT NOT NULL,
  "entry_id" TEXT NOT NULL,
  PRIMARY KEY ("entry_story_edge_id"),
  CONSTRAINT "unique_entry_story_edge" UNIQUE ("story_id" COLLATE BINARY ASC, "entry_id" COLLATE BINARY DESC)
);

CREATE INDEX "entry_story_edges__story_id_asc"
ON "entry_story_edges" (
  "story_id" COLLATE BINARY ASC
);

CREATE INDEX "entry_story_edges__entry_id_asc"
ON "entry_story_edges" (
  "entry_id" COLLATE BINARY DESC
);

CREATE TABLE "entries" (
  "entry_id" text NOT NULL,
  "timestamp" INTEGER,
  "updated_at" INTEGER,
  "plain_text" TEXT,
  "markdown" TEXT,
  "quill" TEXT,
  "lat" REAL,
  "lon" REAL,
  "comment_for" TEXT,
  "vector_clock" TEXT,
  PRIMARY KEY ("entry_id"),
  CONSTRAINT "comment_fk" FOREIGN KEY ("comment_for") REFERENCES "entries" ("entry_id") ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE "entry_edges" (
  "entry_edge_id" TEXT NOT NULL,
  "from_entry" TEXT NOT NULL,
  "to_entry" TEXT NOT NULL,
  "meta" TEXT,
  PRIMARY KEY ("entry_edge_id"),
  CONSTRAINT "from_fk" FOREIGN KEY ("from_entry") REFERENCES "entries" ("entry_id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "to_fk" FOREIGN KEY ("to_entry") REFERENCES "entries" ("entry_id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "from_asc"
ON "entry_edges" (
  "from_entry" COLLATE BINARY ASC
);
CREATE INDEX "to_Asc"
ON "entry_edges" (
  "to_entry" COLLATE BINARY ASC
);

CREATE TABLE "photo_entry_edges" (
  "photo_entry_id" text NOT NULL,
  "photo_id" text NOT NULL,
  "entry_id" text NOT NULL,
  PRIMARY KEY ("photo_entry_id"),
  CONSTRAINT "photo_entry_edges__photo_fk" FOREIGN KEY ("photo_id") REFERENCES "photos" ("photo_id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "photo_entry_edges__entry_fk" FOREIGN KEY ("entry_id") REFERENCES "entries" ("entries_id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE "photos" (
  "photo_id" text NOT NULL,
  "created_at" integer NOT NULL,
  "vector_clock" TEXT NOT NULL,
  "filename" text NOT NULL,
  "asset_id" text,
  "lat" real,
  "lon" real,
  "meta_json" text,
  PRIMARY KEY ("photo_id")
);

CREATE TABLE "stories" (
  "story_id" TEXT,
  "created_at" INTEGER NOT NULL,
  "updated_at" INTEGER NOT NULL,
  "vector_clock" TEXT,
  "title" TEXT NOT NULL,
  "child_of" TEXT,
  PRIMARY KEY ("story_id"),
  FOREIGN KEY ("child_of") REFERENCES "stories" ("story_id") ON DELETE SET NULL ON UPDATE CASCADE
);
