require 'sinatra'
require 'json'
require 'time'
require 'httpclient'
require 'cgi'
require './helper'

@@device_pool = Hash.new ""
@@commit_hash = Hash.new 0 # default to 0
@@time_hash = {}
@@clnt = HTTPClient.new

COUCHDB_ENDPOINT = "http://61.167.60.58:5984/octo-caddice"
GCM_ANDROID_ENDPOINT = "https://android.googleapis.com/gcm/send"
SECONDS_DAY = 60 * 60 * 24

before do
  @@device_pool = JSON.load(open("device.json").read) if File.exists?("device.json")
  @@commit_hash = JSON.load(open("commit_hash.json").read) if File.exists?("commit_hash.json")
  @@time_hash = JSON.load(open("time_hash.json").read) if File.exists?("time_hash.json")
end

after do
  File.open("device.json", "w") { |file| file.write(JSON.dump(@@device_pool)) }
  File.open("commit_hash.json", "w") { |file| file.write(JSON.dump(@@commit_hash)) }
  File.open("time_hash.json", "w") { |file| file.write(JSON.dump(@@time_hash)) }
end

get '/:type/:name' do
  path = path_for params[:type], params[:name]

  result = {
    "path" => path,
    "count" => @@commit_hash[path] || 0
  }
  JSON.dump result
end

get '/devices' do
  JSON.dump @@device_pool
end

# Register a new device with it's user path
post '/register' do
  regId = params["regId"]
  path = params["path"]
  @@device_pool[regId] = path

  type, name = path.split("/", 2)
  doc = {"name" => name, "type" => "type"}
  target_url = COUCHDB_ENDPOINT + "/" + CGI.escape(path)
  @@clnt.put target_url, JSON.dump(doc)

  update_time_for path
  '{"status" : "success"}'
end

# Unregister the device, as well as the path
post '/unregister' do
  regId = params["regId"]
  path = @@device_pool[regId]
  @@device_pool.delete regId
  @@commit_hash.delete path
  @@time_hash.delete path
  '{"status" : "success"}'
end

# Updated by OctoCaddice-Web
post '/update' do
  request.body.rewind  # in case someone already read it
  events = JSON.load request.body.read
  events.each_pair do |path, evts|
    update_time_for path

    results = evts.select do |evt|
      t = Time.parse(evt["created_at"]).getlocal("+08:00")
      deadline = @@time_hash[path] || init_deadline(Time.now.getlocal("+08:00"))
      t < deadline && t > (deadline - SECONDS_DAY)
    end

    new_commit_count = results.size
    @@commit_hash[path] += new_commit_count
    puts @@device_pool.reverse_as_list
    devices = @@device_pool.reverse_as_list[path]
    if new_commit_count > 0 && devices.size > 0
      msg = {
        "registration_ids" => devices,
        "data" => {
          "path" => path,
          "count" => new_commit_count
        }
      }

      key = ENV["GOOGLE_API_KEY"]
      result = {"Authorization" => "key=#{key}", "Content-Type" => "application/json"}
      @@clnt.post(GCM_ANDROID_ENDPOINT, JSON.dump(msg), {"Authorization" => "key=#{key}", "Content-Type" => "application/json"})
    end
  end

  'OK'
end

def path_for type, name
  "#{type}/#{name}"
end

def update_time_for path
  time = Time.now.getlocal("+08:00")
  deadline = @@time_hash[path] || init_deadline(time)
  if time > deadline # next day
    deadline += SECONDS_DAY
    @@time_hash[path] = deadline
    @@commit_hash[path] = 0
  end
end

def init_deadline time
  if time.hour >= 15
    time += SECONDS_DAY
  end

  Time.new(time.year, time.month, time.day, 15, 0, 0, time.utc_offset)
end
