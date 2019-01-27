require 'twitter'
require 'json'
require 'open-uri'
require 'uri'
require 'digest'

    def get_config
        filename = File.expand_path(File.join("~", ".enki", "#{File.basename(__FILE__)}.config"))
        return {:next_point=>0} unless File.exists?(filename)
        
        config = File.open(filename, "r") { |f| 
            JSON.parse(f.readlines.join("\n"))
        }
        
        return {:next_point=>0} unless config.class == {}.class
    
        config = config.each_with_object({}){|(k,v), h| h[k.to_sym] = v}
        config[:next_point] = 0 unless config[:next_point]
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

    def save_to_tempfile(url)
        uri = URI.parse(url)
        name = uri.path.split("/").last
        filepath = "/tmp/#{name}"
        Net::HTTP.start(uri.host, uri.port) do |http|
          resp = http.get(uri.path)
          File.open(filepath, "wb") { |file| 
            file.write(resp.body)
          }
        end

        filepath
      end

config = get_config

data = get_points config[:next_point]
working_on = config[:next_point]

twitter = Twitter::REST::Client.new do |tw|
    tw.consumer_key = config[:twitter]["CONSUMER_KEY"]
    tw.consumer_secret = config[:twitter]["CONSUMER_SECRET"]
    tw.access_token = config[:twitter]["OAUTH_TOKEN"]
    tw.access_token_secret = config[:twitter]["OAUTH_TOKEN_SECRET"]
  end


begin
    while (!data[:records].empty?)
        data[:records].each{ |r| 
            
            working_on = r["sequence_number"] 
            next unless (r["data"]["content"] && !r["data"]["name"])

            entry = r["data"].each_with_object({}){|(k,v), h| h[k.downcase] = v}
            
            created_at = DateTime.parse(r["created_at"])
            
            tweet = entry["content"]
            photos = []
            if entry.key? "photo"
                photos = [entry["photo"]].flatten.map{|ph| File.new(save_to_tempfile(ph))}
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
        data = get_points config[:next_point]
    end
ensure
    store_config config
end
