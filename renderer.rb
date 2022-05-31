require 'redcarpet'

module SVG
  def image(link, title, alt_text)
    return File.open(link).read if link.end_with? "svg"
    "<img src='#{link}'>"
  end
end

class HTML < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet
  include SVG
end

