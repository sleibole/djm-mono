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

  test "returns highlighted fields" do
    result = search("Queen")
    song = result.songs.first
    assert_includes song[:artist_highlighted], "<mark>"
    assert_includes song[:artist_highlighted], "Queen"
  end

  test "returns all song fields" do
    result = search("Bohemian")
    song = result.songs.first
    assert_equal "Bohemian Rhapsody", song[:title]
    assert_equal "Queen", song[:artist]
    assert_equal "Original", song[:version]
    assert_equal "A Night at the Opera", song[:album]
    assert_equal "1001", song[:external_id]
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

    songs = [
      ["Bohemian Rhapsody", "Queen", "Original", "A Night at the Opera", "1001"],
      ["Sweet Caroline", "Neil Diamond", "Original", "Brother Love's Travelling Salvation Show", "1002"],
      ["Don't Stop Believin'", "Journey", "Original", "Escape", "1003"],
      ["Piano Man", "Billy Joel", "Original", "Piano Man", "1004"],
      ["Total Eclipse of the Heart", "Bonnie Tyler", "Original", "Faster Than the Speed of Night", "1006"],
      ["I Will Survive", "Gloria Gaynor", "Original", "Love Tracks", "1007"],
      ["Halo", "Beyoncé", "Original", "I Am... Sasha Fierce", "1008"],
      ["Mr. Brightside", "The Killers", "Original", "Hot Fuss", "1011"],
      ["Wonderwall", "Oasis", "Original", "What's the Story Morning Glory", "1012"],
      ["Hey Jude", "The Beatles", "Original", "Non-album single", "1013"],
    ]

    db.execute("BEGIN TRANSACTION")
    songs.each do |title, artist, version, album, ext_id|
      db.execute(
        "INSERT INTO songs (title, artist, version, album, external_id) VALUES (?, ?, ?, ?, ?)",
        [title, artist, version, album, ext_id]
      )
    end
    db.execute("COMMIT")

    db.execute("INSERT INTO songs_fts(songs_fts) VALUES('rebuild')")
    db.close
  end
end
