require 'aws-sdk'
require 'aws-base'

# Registered entity
# This entity is saved totally under
class RegisteredEntity < AWSBase

  DEVICE_INFO_DB     = "DevicePathInfoDB"
  DEVICE_COLUMN_NAME = "DeviceRegId"

  attr_reader :db

  def initialize
    super # call super to setup for AWS

    # Find the db that saves the devices info
    @db = AWS::SimpleDB.new.domains.create(DEVICE_INFO_DB)
  end

  def add_device_for_path path, device_id
    devices = @db.items[path].attributes[DEVICE_COLUMN_NAME]
    devices.add device_id unless devices.include? device_id
  end

  def delete_device_for_path path, device_id
    devices = @db.items[path].attributes[DEVICE_COLUMN_NAME]
    devices.delete device_id if devices.include? device_id
  end

  def list
    list = {}
    @db.items.each do |path|
      list[path] = @db.items[path].attributes.to_h
    end

    JSON.dump list
  end

end
