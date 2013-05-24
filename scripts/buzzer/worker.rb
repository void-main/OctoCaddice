require 'json'
require 'aws-sdk'
require 'aws-base'
require 'httpclient'

class OctoBuzzer < AWSBase
  GCM_ANDROID_ENDPOINT = "https://android.googleapis.com/gcm/send"
  NOTIF_QUEUE_NAME   = "GithubEventNotification"
  DEVICE_INFO_DB     = "DevicePathInfoDB"
  DEVICE_COLUMN_NAME = "DeviceRegId"

  attr_reader :queue
  attr_reader :db
  attr_reader :clnt

  def initialize
    # Call super to get creditial setup
    super

    # Create sqs, and find the queue that we'll poll
    sqs = AWS::SQS.new
    url = sqs.queues.url_for(NOTIF_QUEUE_NAME)
    @queue = sqs.queues[url]

    # Find the db that saves the devices info
    @db = AWS::SimpleDB.new.domains[DEVICE_INFO_DB]

    # Init the httpclient
    @clnt = HTTPClient.new
  end

  def turn_on
    # Work, work
    @queue.poll do |msg|
      task = JSON.parse msg.body
      path = task["path"]
      evts = task["evts"]
      devices = @db.items[path].attributes[DEVICE_COLUMN_NAME].values
      if evts.size > 0 && devices.size > 0
        msg = {
          "registration_ids" => devices,
          "data" => {
            "path" => path,
            "count" => evts.size
          }
        }

        key = ENV["GOOGLE_API_KEY"]
        @clnt.post(GCM_ANDROID_ENDPOINT, JSON.dump(msg), {"Authorization" => "key=#{key}", "Content-Type" => "application/json"})
      end
    end
  end
end

# Set and go
buzzer = OctoBuzzer.new
buzzer.turn_on
