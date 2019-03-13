require "twitter"
require "uri"

BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__), ".."))

require("#{BASE_DIR}/enki.rb")
require("#{BASE_DIR}/enbilulu.rb")
require("#{BASE_DIR}/files.rb")

CONFIG_NAME = "#{File.basename(__FILE__)}.config"

config = Enki.get_config(CONFIG_NAME) {
  {:next_point => Enbilulu.get_starting_point("end")}
}

data = Enbilulu.get_points config[:next_point]
working_on = config[:next_point]

twitter = Twitter::REST::Client.new do |tw|
  tw.consumer_key = config[:twitter]["CONSUMER_KEY"]
  tw.consumer_secret = config[:twitter]["CONSUMER_SECRET"]
  tw.access_token = config[:twitter]["OAUTH_TOKEN"]
  tw.access_token_secret = config[:twitter]["OAUTH_TOKEN_SECRET"]
end

begin
  while (!data[:records].empty?)
    data[:records].each { |r|
      working_on = r["sequence_number"]
      next unless (r["data"]["content"] && !r["data"]["name"])

      entry = r["data"].each_with_object({}) { |(k, v), h| h[k.downcase] = v }

      created_at = DateTime.parse(r["created_at"])

      tweet = entry["content"]

      next if tweet.length > 280
 
      photos = []
      if entry.key? "photo"
        photos = [entry["photo"]].flatten.map { |ph| File.new(Files.save_to_tempfile(ph)) }
      end

      if photos.empty?
        puts "Syncing #{tweet}"

        twitter.update(tweet)
      else
        puts "Syncing #{tweet} with #{photos.length} images"
        photos.each { |f|
          puts f.path
        }

        twitter.update_with_media(tweet, photos) if !photos.empty?
      end

      config[:next_point] = working_on
    }
    config[:next_point] = working_on + 1
    data = Enbilulu.get_points config[:next_point]
  end
ensure
  Enki.store_config config, CONFIG_NAME
end
