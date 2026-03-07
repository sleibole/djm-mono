class DocsController < ApplicationController
  PAGES_DIR = Rails.root.join("app/views/docs/pages")

  def show
    slug = params[:slug]
    path = PAGES_DIR.join("#{slug}.md")

    unless slug.match?(/\A[a-z0-9\-]+\z/) && path.exist?
      raise ActionController::RoutingError, "Not Found"
    end

    markdown = path.read
    @title = markdown[/\A#\s+(.+)$/, 1] || slug.titleize
    @html = Kramdown::Document.new(markdown, input: "GFM", syntax_highlighter: nil).to_html.html_safe

    expires_in 1.hour, public: true, "s-maxage": 1.day.to_i
  end
end
