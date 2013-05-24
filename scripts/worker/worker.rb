require 'json'
require 'aws-sdk'
require 'aws-base'
require 'octoevent'

require './date'

class OctoCaddiceWorker < AWSBase

  TARGET_URL       = "http://octocaddice.herokuapp.com/devices"
  NOTIF_QUEUE_NAME = "GithubEventNotification"
  MSG_SIZE_LIMIT   = 65536

  attr_reader :octo
  attr_reader :queue

  def initialize
    super # call super to setup the environment

    # setup input data format
    @octo = OctoEvent.new TARGET_URL do |raw|
      result = []
      raw.each_pair do |key, value|
        type, name = key.split("/", 2)
        result << { "name" => name, "type" => type }
      end
      result
    end

    # setup gh key pair for it
    @octo.github_key_pair ENV["GH_KEY_PAIR_ID"], ENV["GH_KEY_PAIR_SECRET"]

    # setup the queue to push notification
    sqs = AWS::SQS.new
    @queue = sqs.queues.create(NOTIF_QUEUE_NAME)
  end

  # Let go the caddice
  def let_go
    # And now here comes the events
    octo.grab "push" do |events|
      events.each_pair do |path, evts|
        evts.select! {|evt| Time.parse(evt["created_at"]).getlocal("+08:00").within_deadline?}
        # Since the text length can be no longer than 65536, split it just in case
        count = (JSON.dump(evts).length / MSG_SIZE_LIMIT) + 1
        slice_size = evts.length / count
        evts.each_slice(slice_size) do |partial|
          obj = {
            "path" => path,
            "evts" => partial
          }

          @queue.send_message(JSON.dump(obj))
        end
      end
    end
  end
end

caddice = OctoCaddiceWorker.new
caddice.let_go
