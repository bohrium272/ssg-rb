require 'redcarpet'
require 'rouge'
require 'rouge/plugins/redcarpet'
require 'fileutils'
require 'erb'
require 'toml'
require 'time'
require 'whirly'

class HTML < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet
end

class Category
  attr_reader :name, :pages
  CATEGORY_TEMPLATE = File.read('./templates/category.erb')
  def initialize(name, pages)
    @name = name
    @pages = pages
  end

  def publish(categories)
    FileUtils.mkdir_p("public/categories/#{@name}/")
    File.write("public/categories/#{@name}/index.html", ERB.new(CATEGORY_TEMPLATE).result(binding))
  end
end

class Tag
  TAGS_TEMPLATE = File.read('./templates/tags.erb')
  def initialize(name, pages)
    @name = name
    @pages = pages
  end

  def publish(categories)
    FileUtils.mkdir_p("public/tags/#{@name}")
    File.write("public/tags/#{@name}/index.html", ERB.new(TAGS_TEMPLATE).result(binding))
  end
end

class Page
  attr_reader :title, :description, :category, :date, :key, :path, :href, :tags, :name
  PAGE_TEMPLATE = File.read('./templates/page.erb')
  def initialize(name, lines)
    @name = name
    @lines = lines
    @markdown = Redcarpet::Markdown.new(HTML.new(filter_html: true, hard_wrap: true), fenced_code_blocks: true, highlight: true)
    build
  end

  def publish(categories)
    FileUtils.mkdir_p(@directory)
    @content = @markdown.render(@md_content)
    File.write(@path, ERB.new(PAGE_TEMPLATE).result(binding))
    @images.each { |path| FileUtils.cp(path, @directory) }
  end

  private

  def build
    fm_indices = frontmatter_indices

    @frontmatter = parse_frontmatter(select_content(@lines, fm_indices[0] + 1, fm_indices[1] - 1))
    @directory = "public/categories/#{@frontmatter.fetch('category', 'Uncategorized')}/#{@name}"
    @path = "#{@directory}/index.html"
    @href = @directory.split('/').last(3).join('/')
    @md_content = select_content(@lines, fm_indices[1] + 1).join
    @title = @frontmatter['title'] 
    @description = @frontmatter['description']
    @category = @frontmatter.fetch('category', 'Uncategorized')
    @key = Time.parse(@frontmatter['date'])
    @date = @key.strftime('%A, %e %B %Y')
    @tags = @frontmatter.fetch('tags', []).map(&:strip).map

    @images = Dir.glob(["content/#{@name}/*.png", "content/#{@name}/*.jpg"])
  end

  def frontmatter_indices
    (0...@lines.length).find_all { |i| @lines[i].start_with? '+++' }.sort
  end

  def select_content(content, start, finish = nil)
    finish = content.length - 1 if finish.nil?
    content.select.each_with_index { |_, i| i >= start and i <= finish }
  end

  def parse_frontmatter(fm_content)
    TOML.load(fm_content.join)
  end
end

class Site
  INDEX_TEMPLATE = File.read('./templates/index.erb')
  def initialize(content_dir)
    @content_dir = content_dir
    build
  end

  def publish
    Whirly.status = 'Publishing categories'
    @categories.each { |category| category.publish(@categories.map { |category| category.name }) }
    Whirly.status = 'Publishing tags'
    @tags.each { |tag| tag.publish(@categories.map { |category| category.name }) }
    Whirly.status = 'Publishing pages'
    @pages.each { |page| page.publish(@categories.map { |category| category.name }) }
    Whirly.status = 'Publishing homepage'
    File.write('public/index.html', ERB.new(INDEX_TEMPLATE).result(binding))
  end
  
  private
  
  def build
    md_files = Dir.glob("#{@content_dir}/*/*.md")
    category_to_pages = {}
    tag_to_pages = {}

    all_pages = []

    Whirly.status = 'Building site'
    md_files.each do |path|
      lines = File.readlines(path)
      page = Page.new(path.split('/')[1], lines)
      category_to_pages[page.category] = category_to_pages.fetch(page.category, []).append(page).sort_by { |page| page.key }.reverse
      page.tags.each do |tag|
        tag_to_pages[tag] = tag_to_pages.fetch(tag, []).append(page).sort_by { |page| page.key }.reverse
      end
      all_pages.append(page)
    end

    all_categories = []
    category_to_pages.each do |category, pages|
      all_categories.append(Category.new(category, pages))
    end

    all_tags = []
    tag_to_pages.each do |tag, pages|
      all_tags.append(Tag.new(tag, pages))
    end

    @categories = all_categories
    @tags = all_tags
    @pages = all_pages.sort_by { |page| page.key }.reverse
  end
  
end

start = Time.now

Whirly.start spinner: 'dots' do
  Site.new('content').publish
  FileUtils.mkdir_p('public/static/')
  Dir.glob('static/*').each { |file| FileUtils.cp(file, 'public/static/') }
end

puts "Done in #{(Time.now - start).to_i}s"
