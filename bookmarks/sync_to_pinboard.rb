require "time"

BASE_DIR = File.expand_path(File.join(File.dirname(__FILE__), ".."))

require("#{BASE_DIR}/enki.rb")
require("#{BASE_DIR}/enbilulu.rb")
require("#{File.expand_path(File.dirname(__FILE__))}/pinboard")

include Pinboard

CONFIG_NAME = "#{File.basename(__FILE__)}.config"

config = Enki.get_config(CONFIG_NAME) {
  {:next_point => 0}
}

data = Enbilulu.get_points config[:next_point]
working_on = config[:next_point]

begin
  while (!data[:records].empty?)
    data[:records].each { |r|
      working_on = r["sequence_number"]
      next unless r["data"]["bookmark-of"]

      entry = r["data"].each_with_object({}) { |(k, v), h| h[k.downcase] = v }
      created_at = DateTime.parse(r["created_at"])
      categories = entry["category"]
      categories = categories.split("\s") unless (categories.is_a? Array)
      categories = categories.join(",") unless (categories.is_a? String)

      bookmark = {
        "url" => entry["bookmark-of"],
        "description" => entry["name"],
        "extended" => entry["content"],
        "tags" => categories,
        "dt" => created_at.new_offset(0).strftime("%FT%TZ"),
      }
      puts "Syncing #{bookmark}"
      Pinboard::add bookmark, config[:pinboard]["username"], config[:pinboard]["password"]
      config[:next_point] = working_on
    }
    config[:next_point] = working_on + 1
    data = Enbilulu.get_points config[:next_point]
  end
ensure
  Enki.store_config config, CONFIG_NAME
end
