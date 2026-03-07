require "sqlite3"
require "csv"
require "fileutils"
require "json"

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
    song_count = insert_rows(db)
    create_fts_index(db)
    db.close

    File.rename(temp_path, final_path)
    song_count
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
        album TEXT,
        versions_json TEXT,
        external_ids_json TEXT,
        versions_text TEXT
      )
    SQL

    db.execute <<~SQL
      CREATE VIRTUAL TABLE songs_fts USING fts5(
        title,
        artist,
        versions_text,
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

    grouped = group_rows(rows, title_idx, artist_idx, version_idx, album_idx, id_idx)

    db.execute("BEGIN TRANSACTION")

    grouped.each_value do |song|
      versions_json = song[:versions].empty? ? nil : song[:versions].to_json
      external_ids_json = song[:external_ids].empty? ? nil : song[:external_ids].to_json
      versions_text = song[:versions].empty? ? nil : song[:versions].join(" ")

      db.execute(
        "INSERT INTO songs (title, artist, album, versions_json, external_ids_json, versions_text) VALUES (?, ?, ?, ?, ?, ?)",
        [song[:title], song[:artist], song[:album], versions_json, external_ids_json, versions_text]
      )
    end

    db.execute("COMMIT")
    grouped.size
  end

  def group_rows(rows, title_idx, artist_idx, version_idx, album_idx, id_idx)
    grouped = {}

    rows.each do |row|
      fields = row.fields
      title = fields[title_idx]&.strip
      artist = fields[artist_idx]&.strip
      next if title.blank? || artist.blank?

      key = [title.downcase, artist.downcase]

      unless grouped.key?(key)
        grouped[key] = {
          title: title,
          artist: artist,
          album: nil,
          versions: [],
          external_ids: []
        }
      end

      song = grouped[key]

      if album_idx
        album = fields[album_idx]&.strip
        song[:album] ||= album if album.present?
      end

      if version_idx
        version = fields[version_idx]&.strip
        song[:versions] << version if version.present? && !song[:versions].include?(version)
      end

      if id_idx
        ext_id = fields[id_idx]&.strip
        song[:external_ids] << ext_id if ext_id.present? && !song[:external_ids].include?(ext_id)
      end
    end

    grouped
  end

  def create_fts_index(db)
    db.execute("INSERT INTO songs_fts(songs_fts) VALUES('rebuild')")
  end
end
