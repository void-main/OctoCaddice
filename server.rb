require 'sinatra'
require 'json'
require 'time'
require 'httpclient'
require './helper'

@@device_pool = Hash.new ""
@@commit_hash = Hash.new 0 # default to 0
@@time_hash = {}
@@clnt = HTTPClient.new

GCM_ANDROID_ENDPOINT = "https://android.googleapis.com/gcm/send"
SECONDS_DAY = 60 * 60 * 24

get '/:type/:name' do
  path = path_for params[:type], params[:name]

  if !@@commit_hash.has_key? path
    status(404) # Not found
    return "Unregistered path: `#{path}`, please register it with your android device first"
  end

  result = {
    "path" => path,
    "count" => @@commit_hash[path]
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
    devices = @@device_pool.reverse_as_list[path]
    puts devices
    if new_commit_count > 0 && devices.size > 0
      msg = {
        "registration_ids" => devices,
        "data" => {
          "path" => path,
          "count" => new_commit_count
        }
      }

      puts msg
      # Do post request
      @@clnt.post(GCM_ANDROID_ENDPOINT, JSON.dump(msg), {"Authorization" => ENV["GOOGLE_API_KEY"], "Content-Type" => "application/json"})
    end
  end
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
