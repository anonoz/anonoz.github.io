#!/usr/bin/env ruby
# Script to convert Jekyll posts to redirect stubs pointing to new site

require 'yaml'
require 'fileutils'

POSTS_DIR = File.expand_path('../_posts', __dir__)
NEW_SITE_BASE = 'https://www.anonoz.com'

# Mapping of old posts to new URLs
posts = Dir.glob(File.join(POSTS_DIR, '*.{md,markdown}')).map do |post_path|
  filename = File.basename(post_path)

  # Parse filename: YYYY-MM-DD-slug.md
  match = filename.match(/^(\d{4}-\d{2}-\d{2})-(.+)\.(md|markdown)$/)
  next unless match

  date_str = match[1]
  slug = match[2]

  # Read original frontmatter to get category
  content = File.read(post_path)
  if content =~ /\A---\s*\n(.*?)\n---/m
    frontmatter = YAML.safe_load($1, permitted_classes: [Date, Time]) rescue {}
  else
    frontmatter = {}
  end

  title = frontmatter['title'] || slug.gsub('-', ' ').capitalize

  {
    path: post_path,
    filename: filename,
    slug: slug,
    title: title,
    new_url: "#{NEW_SITE_BASE}/blog/#{slug}"
  }
end.compact

puts "Converting #{posts.count} posts to redirects..."
puts

posts.each do |post|
  # Create minimal redirect stub
  redirect_content = <<~YAML
---
redirect_to: #{post[:new_url]}
---
YAML

  File.write(post[:path], redirect_content)
  puts "#{post[:slug]} -> #{post[:new_url]}"
end

puts
puts "Done! #{posts.count} posts converted to redirects."
