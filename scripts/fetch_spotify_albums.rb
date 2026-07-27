require 'net/http'
require 'uri'
require 'dotenv/load'
require 'base64'
require 'json'
require 'yaml'

def get_spotify_access_token(client_id, client_secret)
  values = ['https', nil, 'accounts.spotify.com', nil, nil, '/api/token', nil, nil, nil]
  uri = URI.for(*values)
  client_auth = Base64.strict_encode64("#{client_id}:#{client_secret}")
  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Basic #{client_auth}"
  request['content-type'] = 'application/x-www-form-urlencoded'
  request.set_form_data(
    'grant_type' => "client_credentials"
  )
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end
  data = JSON.parse(response.body)
  return data['access_token']
end

def spotify_api_search(name, artist, access_token)
  query = URI.encode_www_form({q:"#{name}%20artist:#{artist}", type: 'album'})
  values = ['https',nil,'api.spotify.com',nil,nil,'/v1/search',nil, query,nil]
  uri = URI.for(*values)
  auth_header = "Bearer #{access_token}"
  headers = {Authorization: auth_header}
  response = Net::HTTP.get_response(uri,headers)
  return JSON.parse(response.body)
end

def load_albums(path)
  data = YAML.load_file(path)
  puts data
end

# Call this script like `ruby fetch_spotify_albums.rb {path_to_yml}`
# The yml file given to script should be an array of albums with a "name" and "artist" property
# This file will be overwritten with an identical array containing a new "image_url" property
# A .env file containing spotify CLIENT_ID and CLIENT_SECRET variables should be added to the project
# The dotenv gem is a dependency for this script

albums = YAML.load_file(ARGV[0])
access_token = get_spotify_access_token(ENV['CLIENT_ID'], ENV['CLIENT_SECRET'])
for i in 0...albums.length
  album = albums[i]
  puts "Fetching image URL for #{album['name']} by #{album['artist']}"
  data = spotify_api_search(album["name"], album["artist"], access_token)
  image_url = data['albums']['items'][0]['images'][2]['url']
  albums[i]["image_url"] = image_url
end
File.write(ARGV[0], albums.to_yaml)