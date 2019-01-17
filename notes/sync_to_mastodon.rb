require 'json'
require 'open-uri'

    def initialize_config
        p "Initializing config"
        config = {}
        config[:next_point] = get_starting_point 'end'
        config
    end

    def get_config
        filename = File.expand_path(File.join("~", ".enki", "#{File.basename(__FILE__)}.config"))
        return initialize_config unless File.exists?(filename)
        
        config = File.open(filename, "r") { |f| 
            JSON.parse(f.readlines.join("\n"))
        }
        
        return initialize_config unless config.class == {}.class
    
        config = config.each_with_object({}){|(k,v), h| h[k.to_sym] = v}
        initialize_config unless config[:next_point]
        config
    end
    
    def store_config config
        filename = File.expand_path(File.join("~", ".enki", "#{File.basename(__FILE__)}.config"))
        File.open(filename, "w") { |f| 
            f << config.to_json
        }
    end
    
    def get_points last
        uri = "http://avocadia.net/stream/get_records/#{last}/10"
    
        open(uri) { |f|
            JSON.parse(f.readlines.join("\n"))
        }.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    end

    def get_starting_point type, from = 0
        uri = "http://avocadia.net/stream/get_stream_position/#{type}/#{from}"
    
        open(uri) { |f|
            JSON.parse(f.readlines.join("\n"))
        }["point"]
    end

config = get_config

data = get_points config[:next_point]
working_on = config[:next_point]

mastodon = Mastodon::REST::Client.new(config[:mastodon])

begin
    while (!data[:records].empty?)
        data[:records].each{ |r| 
            
            working_on = r["sequence_number"] 
            next unless (r["data"]["content"] && !r["data"]["name"])

            entry = r["data"].each_with_object({}){|(k,v), h| h[k.downcase] = v}
            
            created_at = DateTime.parse(r["created_at"])
            
            tweet = entry["content"]

            puts "Syncing #{tweet}"
            mastodon.create_status(tweet)
            config[:next_point] = working_on
        }
        config[:next_point] = working_on + 1
        data = get_points config[:next_point]
    end
ensure
    store_config config
end
