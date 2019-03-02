require "time"
require("#{BASE_DIR}/files.rb")

class BlogPost
  attr_accessor :body, :title, :publish_at, :categories, :allow_comments, :link

  def initialize
    @allow_comments = false
    @publish_at = DateTime.now
    @categories = []
  end

  def categories=(v)
    @categories = ((v.is_a? Array) ? v : [v]).map { |i| i.to_s }
  end

  def to_jekyll(layout)
    filename = Files.sanitize_filename("#{@publish_at.strftime("%Y-%m-%d")}-#{@title}.markdown")

    return filename, "---
layout: #{layout}
title: \"#{@title}\"
date: #{@publish_at.strftime("%Y-%m-%d %H:%M")}
comments: #{@allow_comments.to_s}
categories: [#{(@categories || []).join(", ")}]
bookmark: #{@link if @link}
#{"excerpt_separator: <!--more-->" if @link}
---
#{@body}\n"
  end
end
