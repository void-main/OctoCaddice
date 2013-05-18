require 'sinatra'
require 'json'
require 'time'

@@commit_hash = Hash.new 0 # default to 0
@@time_hash = {}

SECONDS_DAY = 60 * 60 * 24

get '/:type/:name' do
  path = path_for params[:type], params[:name]
  update_time_for path
  result = @@commit_hash[path]
  result.to_s
end

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
    if new_commit_count > 0
      # TODO notify android devices!!!!!
    end
  end
end

def path_for type, name
  "#{type}s/#{name}"
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
