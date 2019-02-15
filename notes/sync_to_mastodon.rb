require "mastodon"

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

mastodon = Mastodon::REST::Client.new(
  base_url: config[:mastodon]["base_url"],
  bearer_token: config[:mastodon]["bearer_token"],
)

begin
  while (!data[:records].empty?)
    data[:records].each { |r|
      working_on = r["sequence_number"]
      next unless (r["data"]["content"] && !r["data"]["name"])

      entry = r["data"].each_with_object({}) { |(k, v), h| h[k.downcase] = v }

      created_at = DateTime.parse(r["created_at"])

      tweet = entry["content"]
      photo_ids = []
      if entry.key? "photo"
        photos = [entry["photo"]].flatten.map { |ph| HTTP::FormData::File.new(Files.save_to_tempfile(ph)) }

        # Should be uploading media, but the mastodon gem keeps failing.
        # So just adding the links on for now
        photo_ids = photos.map { |p|
          puts "Uploading file"
          mastodon.upload_media(p).id
        }
        puts "Syncing #{tweet}\n\twith media: #{photo_ids.join(", ")}"
        mastodon.create_status(tweet, nil, photo_ids)
      else
        puts "Syncing #{tweet}"
        mastodon.create_status(tweet)
      end

      config[:next_point] = working_on
    }
    config[:next_point] = working_on + 1
    data = Enbilulu.get_points config[:next_point]
  end
ensure
  Enki.store_config config, CONFIG_NAME
end
