require "builder"

set :css_dir, 'css'
set :js_dir, 'js'
set :images_dir, 'images'
set :relative_links, true

activate :blog do |blog|
  blog.prefix = "blog"
  blog.tag_template = "tag.html"
  blog.calendar_template = "calendar.html"
  blog.layout = "blog_layout"
end

page "/feed.xml", :layout => false

# Build-specific configuration
configure :build do
  activate :minify_css
  activate :minify_javascript
  activate :asset_hash, :ignore => [/^images\/aaaa/]
  set :build_dir, '../cw-prod'
  set :css_dir, '//cdn.codewright.roguenet.org/css'
  set :js_dir, '//cdn.codewright.roguenet.org/js'
  set :images_dir, '//cdn.codewright.roguenet.org/images'
end
