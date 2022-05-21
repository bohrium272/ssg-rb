require 'redcarpet'
require 'rouge'
require 'rouge/plugins/redcarpet'
require 'fileutils'
require 'erb'
require 'toml'
require 'time'

require_relative 'renderer'

if ARGV.length < 2 then 
    puts "Usage: ruby compile.rb CONTENT_DIR PUBLISH_DIR"
    puts
    puts "CONTENT_DIR: Relative to the directory where this script is located"
    puts "PUBLISH_DIR: Absolute path of the directory where the site will be published"
    exit
end

SITE_ROOT = ''
SRC_DIR = File.expand_path('../', __FILE__)
CONTENT_DIR = File.join(SRC_DIR, ARGV[0])
PUBLISH_DIR = ARGV[1]

class Category
  attr_reader :name, :pages
  CATEGORY_TEMPLATE = File.read(File.join(SRC_DIR, 'templates/category.erb'))
  def initialize(name, pages, site_root)
    @name = name
    @pages = pages
    @site_root = site_root
  end

  def publish(categories)
    FileUtils.mkdir_p(File.join(PUBLISH_DIR, "categories/#{@name}/"))
    File.write(File.join(PUBLISH_DIR, "categories/#{@name}/index.html"), ERB.new(CATEGORY_TEMPLATE).result(binding))
  end
end

class Tag
  TAGS_TEMPLATE = File.read(File.join(SRC_DIR, 'templates/tags.erb'))
  def initialize(name, pages, site_root)
    @name = name
    @pages = pages
    @site_root = site_root
  end

  def publish(categories)
    FileUtils.mkdir_p(File.join(PUBLISH_DIR, "tags/#{@name}"))
    File.write(File.join(PUBLISH_DIR, "tags/#{@name}/index.html"), ERB.new(TAGS_TEMPLATE).result(binding))
  end
end

class Page
  attr_reader :title, :description, :category, :date, :key, :path, :href, :tags, :name
  PAGE_TEMPLATE = File.read(File.join(SRC_DIR, 'templates/page.erb'))
  def initialize(name, lines, site_root)
    @name = name
    @lines = lines
    @site_root = site_root
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
    @directory = File.join(PUBLISH_DIR, "categories/#{@frontmatter.fetch('category', 'Uncategorized')}/#{@name}")
    @path = "#{@directory}/index.html"
    @href = @directory.split('/').last(3).join('/')
    @md_content = select_content(@lines, fm_indices[1] + 1).join
    @title = @frontmatter['title'] 
    @description = @frontmatter['description']
    @category = @frontmatter.fetch('category', 'Uncategorized')
    @key = Time.parse(@frontmatter['date'])
    @date = @key.strftime('%A, %e %B %Y')
    @tags = @frontmatter.fetch('tags', []).map(&:strip).map

    @images = Dir.glob([
      "#{CONTENT_DIR}/#{@name}/*.png", 
      "#{CONTENT_DIR}/#{@name}/*.jpg"
    ])
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
  INDEX_TEMPLATE = File.read(File.join(SRC_DIR, 'templates/index.erb'))
  def initialize(content_dir, site_root)
    @content_dir = content_dir
    @site_root = site_root
    build
  end

  def publish
    @categories.each { |category| category.publish(@categories.map { |category| category.name }) }
    @tags.each { |tag| tag.publish(@categories.map { |category| category.name }) }
    @pages.each { |page| page.publish(@categories.map { |category| category.name }) }
    File.write(File.join(PUBLISH_DIR, '/index.html'), ERB.new(INDEX_TEMPLATE).result(binding))
  end
  
  private
  
  def build
    md_files = Dir.glob("#{@content_dir}/*/*.md")
    category_to_pages = {}
    tag_to_pages = {}

    all_pages = []

    md_files.each do |path|
      lines = File.readlines(path)
      page = Page.new(path.split('/').reverse[1], lines, @site_root)
      category_to_pages[page.category] = category_to_pages.fetch(page.category, []).append(page).sort_by { |page| page.key }.reverse
      page.tags.each do |tag|
        tag_to_pages[tag] = tag_to_pages.fetch(tag, []).append(page).sort_by { |page| page.key }.reverse
      end
      all_pages.append(page)
    end

    all_categories = []
    category_to_pages.each do |category, pages|
      all_categories.append(Category.new(category, pages, @site_root))
    end

    all_tags = []
    tag_to_pages.each do |tag, pages|
      all_tags.append(Tag.new(tag, pages, @site_root))
    end

    @categories = all_categories
    @tags = all_tags
    @pages = all_pages.sort_by { |page| page.key }.reverse
  end
  
end

start = Time.now

Site.new(CONTENT_DIR, SITE_ROOT).publish
FileUtils.mkdir_p(File.join(PUBLISH_DIR, 'static'))
Dir.glob(File.join(SRC_DIR, 'static/*')).each { |file| FileUtils.cp(file, File.join(PUBLISH_DIR, 'static/')) }

puts "Done in #{(Time.now - start).to_i}s"
