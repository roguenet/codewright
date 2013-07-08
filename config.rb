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
  set :build_dir, '../cw-prod'

  set :cdn_url, '//cdn.codewright.roguenet.org'
  activate :asset_host
  set :asset_host do |asset|
    settings.cdn_url.to_s
  end

  activate :minify_css
  activate :minify_javascript
  activate :asset_hash, :ignore => [/^images\/aaaa/]
end
