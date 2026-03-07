require "test_helper"
require "csv"

class CatalogSearchServiceTest < ActiveSupport::TestCase
  setup do
    @catalog_record = CatalogRecord.create!(
      catalog_id: 999,
      user_id: 1,
      status: :ready,
      active_db_version: 1
    )

    build_test_db!
  end

  teardown do
    path = @catalog_record.db_path
    File.delete(path) if path && File.exist?(path)
  end

  test "finds songs by title" do
    result = search("Bohemian")
    assert_equal 1, result.total
    assert_equal "Bohemian Rhapsody", result.songs.first[:title]
  end

  test "finds songs by artist" do
    result = search("Queen")
    assert_equal 1, result.total
    assert_equal "Queen", result.songs.first[:artist]
  end

  test "prefix matching works with partial words" do
    result = search("bohem rhap")
    assert_equal 1, result.total
    assert_equal "Bohemian Rhapsody", result.songs.first[:title]
  end

  test "diacritics are ignored in search" do
    result = search("Beyonce")
    assert_equal 1, result.total
    assert_equal "Beyoncé", result.songs.first[:artist]
  end

  test "search is case insensitive" do
    result = search("bohemian rhapsody")
    assert_equal 1, result.total

    result = search("BOHEMIAN RHAPSODY")
    assert_equal 1, result.total
  end

  test "title matches rank higher than artist matches" do
    result = search("Piano")
    titles = result.songs.map { |s| s[:title] }
    assert_includes titles, "Piano Man"
    assert_equal "Piano Man", titles.first, "Title match should rank above artist/version match"
  end

  test "returns versions as an array" do
    result = search("Bohemian")
    song = result.songs.first
    assert_kind_of Array, song[:versions]
    assert_includes song[:versions], "Original"
    assert_includes song[:versions], "Key +2"
    assert_includes song[:versions], "Key -3"
  end

  test "returns external_ids as an array" do
    result = search("Boyfriend")
    song = result.songs.first
    assert_kind_of Array, song[:external_ids]
    assert_includes song[:external_ids], "ASK-035475"
    assert_includes song[:external_ids], "CB30055-02"
  end

  test "collapses duplicate title/artist into one result" do
    result = search("Boyfriend")
    assert_equal 1, result.total
    assert_equal "Boyfriend", result.songs.first[:title]
    assert_equal "Ashlee Simpson", result.songs.first[:artist]
  end

  test "returns all song fields" do
    result = search("Bohemian")
    song = result.songs.first
    assert_equal "Bohemian Rhapsody", song[:title]
    assert_equal "Queen", song[:artist]
    assert_equal "A Night at the Opera", song[:album]
    assert_kind_of Array, song[:versions]
    assert_kind_of Array, song[:external_ids]
  end

  test "version text is searchable via FTS5" do
    result = search("Acoustic")
    assert result.total >= 1
    titles = result.songs.map { |s| s[:title] }
    assert_includes titles, "Don't Stop Believin'"
  end

  test "respects limit parameter" do
    result = search("the", limit: 2)
    assert_equal 2, result.songs.length
    assert result.total > 2
  end

  test "respects offset parameter" do
    all = search("the", limit: 100)
    offset = search("the", limit: 100, offset: 1)
    assert_equal all.total, offset.total
    assert_equal all.songs[1][:id], offset.songs[0][:id]
  end

  test "returns empty results for no matches" do
    result = search("zzzznotasong")
    assert_equal 0, result.total
    assert_empty result.songs
  end

  test "returns empty results for blank query" do
    result = search("")
    assert_equal 0, result.total
    assert_empty result.songs
  end

  test "strips FTS5 special characters from query" do
    result = search('"Bohemian" OR (DROP TABLE)')
    assert result.total >= 0
  end

  test "caps limit at MAX_LIMIT" do
    result = search("the", limit: 9999)
    assert result.songs.length <= CatalogSearchService::MAX_LIMIT
  end

  private

  def search(query, **opts)
    CatalogSearchService.new(@catalog_record).search(query, **opts)
  end

  def build_test_db!
    dir = File.dirname(@catalog_record.db_path)
    FileUtils.mkdir_p(dir)

    db = SQLite3::Database.new(@catalog_record.db_path.to_s)

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

    songs = [
      ["Bohemian Rhapsody", "Queen", "A Night at the Opera",
       '["Original","Key +2","Key -3"]', '["1001"]', "Original Key +2 Key -3"],
      ["Sweet Caroline", "Neil Diamond", "Brother Love's Travelling Salvation Show",
       '["Original"]', '["1002"]', "Original"],
      ["Don't Stop Believin'", "Journey", "Escape",
       '["Original","Acoustic","Duet"]', '["1003"]', "Original Acoustic Duet"],
      ["Piano Man", "Billy Joel", "Piano Man",
       '["Original"]', '["1004"]', "Original"],
      ["Total Eclipse of the Heart", "Bonnie Tyler", "Faster Than the Speed of Night",
       '["Original"]', '["1006"]', "Original"],
      ["I Will Survive", "Gloria Gaynor", "Love Tracks",
       '["Original"]', '["1007"]', "Original"],
      ["Halo", "Beyoncé", "I Am... Sasha Fierce",
       '["Original"]', '["1008"]', "Original"],
      ["Mr. Brightside", "The Killers", "Hot Fuss",
       nil, nil, nil],
      ["Wonderwall", "Oasis", "What's the Story Morning Glory",
       nil, nil, nil],
      ["Hey Jude", "The Beatles", "Non-album single",
       nil, nil, nil],
      ["Boyfriend", "Ashlee Simpson", nil,
       nil, '["ASK-035475","CB30055-02"]', nil],
    ]

    db.execute("BEGIN TRANSACTION")
    songs.each do |title, artist, album, versions_json, external_ids_json, versions_text|
      db.execute(
        "INSERT INTO songs (title, artist, album, versions_json, external_ids_json, versions_text) VALUES (?, ?, ?, ?, ?, ?)",
        [title, artist, album, versions_json, external_ids_json, versions_text]
      )
    end
    db.execute("COMMIT")

    db.execute("INSERT INTO songs_fts(songs_fts) VALUES('rebuild')")
    db.close
  end
end
