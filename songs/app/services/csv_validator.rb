class CsvValidator
  REQUIRED_HEADERS = %w[title artist].freeze
  KNOWN_HEADERS = %w[title artist version album id].freeze
  MAX_ROW_ERRORS = 20

  Result = Struct.new(:valid?, :errors, :headers, keyword_init: true)

  def initialize(csv_content)
    @csv_content = csv_content
  end

  def validate
    errors = []

    begin
      rows = CSV.parse(@csv_content, headers: true, liberal_parsing: true)
    rescue CSV::MalformedCSVError => e
      return Result.new(valid?: false, errors: [ { type: "parse_error", detail: "Invalid CSV: #{e.message}" } ])
    end

    if rows.headers.nil? || rows.headers.compact.empty?
      return Result.new(valid?: false, errors: [ { type: "no_headers", detail: "CSV has no header row" } ])
    end

    normalized = rows.headers.map { |h| h&.strip&.downcase }

    normalized.each_with_index do |header, i|
      if header.nil? || header.empty?
        errors << { type: "empty_header", column: i + 1, detail: "Header cell #{i + 1} is empty" }
      end
    end

    dupes = normalized.compact.tally.select { |_, count| count > 1 }
    dupes.each do |header, _|
      errors << { type: "duplicate_header", column: header, detail: "Duplicate header '#{header}'" }
    end

    REQUIRED_HEADERS.each do |required|
      unless normalized.include?(required)
        errors << { type: "missing_header", detail: "Required header '#{required}' is missing" }
      end
    end

    return Result.new(valid?: false, errors: errors) if errors.any?

    title_idx = normalized.index("title")
    artist_idx = normalized.index("artist")
    row_errors = 0

    rows.each.with_index(2) do |row, line_num|
      break if row_errors >= MAX_ROW_ERRORS

      title = row.fields[title_idx]&.strip
      artist = row.fields[artist_idx]&.strip

      if title.nil? || title.empty?
        errors << { type: "blank_field", row: line_num, column: "title", detail: "Title is blank on row #{line_num}" }
        row_errors += 1
      end

      if artist.nil? || artist.empty?
        errors << { type: "blank_field", row: line_num, column: "artist", detail: "Artist is blank on row #{line_num}" }
        row_errors += 1
      end
    end

    Result.new(valid?: errors.empty?, errors: errors, headers: normalized.compact)
  end
end
