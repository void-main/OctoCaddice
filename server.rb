require 'json'
require 'aws-sdk'
require 'sinatra'
require 'aws-base'
require './entity'

entity_manager = RegisteredEntity.new

# list current registered devices
get '/devices' do
  entity_manager.list
end

# Register a new device with it's user path
post '/register' do
  regId = params["regId"]
  path = params["path"]
  entity_manager.add_device_for_path(path, regId)
  '{"status" : "success"}'
end

# Unregister the device, as well as the path
post '/unregister' do
  regId = params["regId"]
  path = params["path"]
  entity_manager.delete_device_for_path(path, regId)
  '{"status" : "success"}'
end
