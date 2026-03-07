require "sqlite3"
require "json"

class CatalogSearchService
  DEFAULT_LIMIT = 25
  MAX_LIMIT = 100

  TITLE_WEIGHT  = 10.0
  ARTIST_WEIGHT = 5.0
  VERSIONS_TEXT_WEIGHT = 1.0

  Result = Struct.new(:songs, :total, keyword_init: true)

  FTS5_META_CHARS = /["*+\-()^:{}~|@]/
  FTS5_KEYWORDS = %w[AND OR NOT NEAR].to_set.freeze

  def initialize(catalog_record)
    @record = catalog_record
  end

  def search(query, limit: DEFAULT_LIMIT, offset: 0)
    fts_query = build_fts_query(query)
    return Result.new(songs: [], total: 0) if fts_query.blank?

    limit = [[limit.to_i, 1].max, MAX_LIMIT].min
    offset = [offset.to_i, 0].max

    db = open_db
    db.results_as_hash = true

    total = count_matches(db, fts_query)
    songs = fetch_matches(db, fts_query, limit, offset)

    db.close

    Result.new(songs: songs, total: total)
  end

  private

  def open_db
    path = @record.db_path.to_s
    raise "Catalog database not found" unless File.exist?(path)

    SQLite3::Database.new(path, readonly: true)
  end

  def build_fts_query(raw)
    return nil if raw.blank?

    terms = raw.to_s
      .gsub(FTS5_META_CHARS, " ")
      .split
      .reject(&:blank?)
      .reject { |t| FTS5_KEYWORDS.include?(t.upcase) }
      .first(20)
      .map { |term| "#{term}*" }

    terms.empty? ? nil : terms.join(" ")
  end

  def count_matches(db, fts_query)
    db.get_first_value(
      "SELECT COUNT(*) FROM songs_fts WHERE songs_fts MATCH ?",
      [fts_query]
    ).to_i
  end

  def fetch_matches(db, fts_query, limit, offset)
    rows = db.execute(<<~SQL, [fts_query, limit, offset])
      SELECT
        songs.id,
        songs.title,
        songs.artist,
        songs.album,
        songs.versions_json,
        songs.external_ids_json,
        bm25(songs_fts, #{TITLE_WEIGHT}, #{ARTIST_WEIGHT}, #{VERSIONS_TEXT_WEIGHT}) AS rank
      FROM songs_fts
      JOIN songs ON songs.id = songs_fts.rowid
      WHERE songs_fts MATCH ?
      ORDER BY rank
      LIMIT ? OFFSET ?
    SQL

    rows.map do |row|
      {
        id: row["id"],
        title: row["title"],
        artist: row["artist"],
        album: row["album"],
        versions: parse_json_array(row["versions_json"]),
        external_ids: parse_json_array(row["external_ids_json"])
      }
    end
  end

  def parse_json_array(json_str)
    return [] if json_str.blank?
    JSON.parse(json_str)
  rescue JSON::ParserError
    []
  end
end
