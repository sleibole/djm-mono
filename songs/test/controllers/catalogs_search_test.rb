require "test_helper"

class CatalogsSearchTest < ActionDispatch::IntegrationTest
  setup do
    @catalog_record = CatalogRecord.create!(
      catalog_id: 888,
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

  test "returns search results with grouped fields" do
    get catalog_search_path(catalog_id: 888), params: { q: "Bohemian" }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 888, json["catalog_id"]
    assert_equal "Bohemian", json["query"]
    assert_equal 1, json["total"]
    assert_equal 1, json["songs"].length

    song = json["songs"].first
    assert_equal "Bohemian Rhapsody", song["title"]
    assert_kind_of Array, song["versions"]
    assert_includes song["versions"], "Original"
    assert_kind_of Array, song["external_ids"]
  end

  test "returns 400 when q is missing" do
    get catalog_search_path(catalog_id: 888)

    assert_response :bad_request
    json = JSON.parse(response.body)
    assert_includes json["error"], "required"
  end

  test "returns 404 for unknown catalog" do
    get catalog_search_path(catalog_id: 99999), params: { q: "test" }

    assert_response :not_found
  end

  test "returns 422 for catalog that is not ready" do
    @catalog_record.update!(status: :processing)

    get catalog_search_path(catalog_id: 888), params: { q: "test" }

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_includes json["error"], "not ready"
  end

  test "supports pagination with limit and offset" do
    get catalog_search_path(catalog_id: 888), params: { q: "Original", limit: 2, offset: 0 }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 2, json["songs"].length
    assert json["total"] > 2
  end

  private

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
      ["Bohemian Rhapsody", "Queen", nil, '["Original","Key +2"]', '["1001"]', "Original Key +2"],
      ["Sweet Caroline", "Neil Diamond", nil, '["Original"]', nil, "Original"],
      ["Don't Stop Believin'", "Journey", nil, '["Original"]', nil, "Original"],
      ["Piano Man", "Billy Joel", nil, '["Original"]', nil, "Original"],
      ["Hey Jude", "The Beatles", nil, '["Original"]', nil, "Original"],
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
