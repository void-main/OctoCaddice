require 'sinatra'
require 'json'

@@commit_hash = {}

get '/:type/:name' do
  path = path_for params[:type], params[:name]
  result = @@commit_hash[path] || 0
  result.to_s
end

post '/update' do
  @events = JSON.load(request.body.read)
  puts @events
end

def path_for type, name
  "#{type}s/#{name}"
end
