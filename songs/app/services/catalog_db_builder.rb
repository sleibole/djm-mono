require "sqlite3"
require "csv"
require "fileutils"

class CatalogDbBuilder
  KNOWN_HEADERS = %w[title artist version album id].freeze

  def initialize(catalog_record, version)
    @record = catalog_record
    @version = version
  end

  def build
    FileUtils.mkdir_p(db_dir)

    temp_path = @record.db_path(@version).to_s + ".tmp"
    final_path = @record.db_path(@version).to_s

    db = SQLite3::Database.new(temp_path)
    create_schema(db)
    insert_rows(db)
    create_fts_index(db)
    db.close

    File.rename(temp_path, final_path)
    final_path
  end

  private

  def db_dir
    Rails.root.join("storage", "catalog_dbs")
  end

  def csv_content
    @csv_content ||= @record.csv_file.download
  end

  def create_schema(db)
    db.execute <<~SQL
      CREATE TABLE songs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        version TEXT,
        album TEXT,
        external_id TEXT
      )
    SQL

    db.execute <<~SQL
      CREATE VIRTUAL TABLE songs_fts USING fts5(
        title,
        artist,
        version,
        content=songs,
        content_rowid=id,
        tokenize="unicode61 remove_diacritics 2",
        prefix='2 3'
      )
    SQL
  end

  def insert_rows(db)
    rows = CSV.parse(csv_content, headers: true, liberal_parsing: true)
    normalized = rows.headers.map { |h| h&.strip&.downcase }

    title_idx = normalized.index("title")
    artist_idx = normalized.index("artist")
    version_idx = normalized.index("version")
    album_idx = normalized.index("album")
    id_idx = normalized.index("id")

    db.execute("BEGIN TRANSACTION")

    rows.each do |row|
      fields = row.fields
      db.execute(
        "INSERT INTO songs (title, artist, version, album, external_id) VALUES (?, ?, ?, ?, ?)",
        [
          fields[title_idx]&.strip,
          fields[artist_idx]&.strip,
          version_idx ? fields[version_idx]&.strip : nil,
          album_idx ? fields[album_idx]&.strip : nil,
          id_idx ? fields[id_idx]&.strip : nil
        ]
      )
    end

    db.execute("COMMIT")
  end

  def create_fts_index(db)
    db.execute("INSERT INTO songs_fts(songs_fts) VALUES('rebuild')")
  end
end
