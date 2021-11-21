ssg-rb
---

Yet another static site generator, built to get along well with classless CSS!

### About

* Yes this is yet another static site generator! 
* Actually, its more of a Ruby script that can compile markdown files placed as per a specific (and opiniated) hierarchy. 
* While the layout is pre-defined, the appearance can be changed by dropping in a [classless stylesheet](https://github.com/dbohdan/classless-css). 

### Content

#### Directory Structure

1. The `content/` directory should contain one directory for each post
2. A post directory `content/xyz-abc/` should contain a markdown file and any static content like images etc.

```
content/
   |
   --xyz-abc/
		|
		--xyz-abc.md
		--image.png
		--image.jpg
```

#### Frontmatter, Category and Tags

* Each markdown content file can contain a front-matter, a TOML snippet containing some metadata.

	```toml
	title = ""
	date = "YYYY-MM-DD"
	description = ""
	tags = ["<tag1>", "<tag2>", "<tag3>"]
	category = "notes"
	```

* Each page can be associated with a category:
		* Categories are displayed as nav elements on each content page
		* An index page for each category is generated at `/categories/<category>/`

* Each page can have a set of tags:
		* Tags are displayed on the bottom of each page
		* An index page for each tag is generated at `/tags/<tag>/`

### Usage

1. Place the ruby script `ssg.rb` in the root of your project.
2. Use `bundle` to install dependencies
    ```bash
	$ gem install bundler
	$ bundle install
	```
3. Place your classless CSS	as `static/theme.css`. If any overrides are needed, they can be placed in `static/custom.css`.  
4. Run `ssg.rb` and the site will be available in the `public` directory.
5. Serve the public directory using a simple HTTP server like the Python `http.server` module
    ```bash
	$ cd public/
	$ python3 -m http.server
	```
	
### Why?

Over time I used a number of static site generators like Hugo, Zola, Hexo, Jekyll etc. While each of these require structured representations of content, often when I wanted to change the look of a site I couldn't do it by simply changing the theme attribute in the site configuration. This implied that each theme required content to be structured or written differently. At least this was the case with the themes I tried to use...

So this is an attempt to create a script that expects a fixed (and opinionated) content structure, builds it into a simple (and opinionated) site, while allowing the use of [classless stylesheets](https://github.com/dbohdan/classless-css) for theming.
