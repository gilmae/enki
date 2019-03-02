require "time"
require "octokit"

BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__), ".."))

require("#{BASE_DIR}/enki.rb")
require("#{BASE_DIR}/enbilulu.rb")
require("#{BASE_DIR}/files.rb")
require("./blog")

CONFIG_NAME = "#{File.basename(__FILE__)}.config"

config = Enki.get_config(CONFIG_NAME) {
  {:next_point => Enbilulu.get_starting_point("end")}
}

octokit_client = Octokit::Client.new(:access_token => config[:octokit_token])

data = Enbilulu.get_points config[:next_point]
working_on = config[:next_point]

begin
  while (!data[:records].empty?)
    data[:records].each { |r|
      working_on = r["sequence_number"]
      next unless r["data"]["name"]

      entry = r["data"].each_with_object({}) { |(k, v), h| h[k.downcase] = v }

      puts entry
      post = BlogPost.new
      post.publish_at = DateTime.parse(r["created_at"])
      post.body = entry["content"]
      post.title = r["data"]["name"]

      categories = entry["category"] || []
      categories = categories.split("\s") unless (categories.is_a? Array)
      categories = categories.join(",") unless (categories.is_a? String)

      post.categories = categories
      post.allow_comments = false
      if entry["bookmark-of"]
        post.link = entry["bookmark-of"]

        post.body = "#{post.body}<!--more-->"
        post.title = "🔖 #{post.title}"
      end

      name, contents = post.to_jekyll "post"

      octokit_client.create_contents("gilmae/blog.avocadia.net",
                                     "_posts/#{name}",
                                     "Adding post",
                                     contents)

      config[:next_point] = working_on
    }
    config[:next_point] = working_on + 1
    data = Enbilulu.get_points config[:next_point]
  end
ensure
  Enki.store_config config, CONFIG_NAME
end

Enki.store_config config, CONFIG_NAME
