require 'uri'
require 'net/http'

module Pinboard
    def get filters, username, password
        uri =  construct "get", data

        return call(uri, username, password)
    end

    def add data, username, password
        data = data.to_h unless data.is_a?(Hash)

        uri = construct "add", data
        response = call uri, username, password

        return response.body.include? "done"
    end

    def construct command, arguments
        uri =  URI.parse("https://api.pinboard.in/v1/posts/#{command}")
        uri.query = arguments.to_a.map { |k,v| "#{k}=#{v}"}.join("&")
        uri
    end

    def call uri, username, password
        uri = URU.parse(uri) unless uri.is_a? URI
        req = Net::HTTP::Get.new(uri)
    
        req.basic_auth username, password
    
        res = Net::HTTP.start(uri.host, uri.port, :use_ssl=>uri.scheme == "https") { |http|
    
            http.request(req)
        }
        return res
    end
end