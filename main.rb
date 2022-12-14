# frozen_string_literal: true

require 'sinatra'
require 'telegram/bot'
require 'aws-sdk-s3'
require 'dotenv/load'
require 'httparty'

YC_ENDPOINT = 'https://storage.yandexcloud.net'
YC_API = 'api.cloud.yandex.net'
TG_BOT_API = 'https://api.telegram.org'
WAIT_TIME = 2
REPEAT_COUNT = 30

Aws.config.update(
  region: 'ru-central1',
  credentials: Aws::Credentials.new(ENV['YC_ACCESS_KEY_ID'], ENV['YC_SECRET_ACCESS_KEY'])
)

def yc
  yc ||= Aws::S3::Client.new(endpoint: YC_ENDPOINT)
end

def voice_upload(message)
  path = HTTParty.get("#{TG_BOT_API}/bot#{ENV['TG_BOT_TOKEN']}/getFile?file_id=#{message.voice.file_id}").to_h.dig(
    'result', 'file_path'
  )
  file = HTTParty.get("#{TG_BOT_API}/file/bot#{ENV['TG_BOT_TOKEN']}/#{path}")&.body
  name = "#{message.chat.id}_#{message.message_id}.ogg'"
  yc.put_object({
                  bucket: ENV['YC_BUCKET_NAME'],
                  key: name,
                  body: file
                })

  name
end

def speech_detect(file_name)
  options = {
    headers: { 'Authorization' => "Api-Key #{ENV['YC_API_KEY']}" },
    body: {
      'config' => {
        'specification' => {
          'languageCode' => 'ru-RU'
        }
      },
      'audio' => {
        'uri' => "#{YC_ENDPOINT}/#{ENV['YC_BUCKET_NAME']}/#{file_name}"
      }
    }.to_json
  }
  HTTParty.post("https://transcribe.#{YC_API}/speech/stt/v2/longRunningRecognize",
                options).to_h['id']
end

def get_rezult(operation_id, file_name)
  option = {
    headers: { 'Authorization' => "Api-Key #{ENV['YC_API_KEY']}" }
  }

  tries = REPEAT_COUNT
  while tries.positive?
    response = HTTParty.get("https://operation.#{YC_API}/operations/#{operation_id}", option).to_h
    sleep WAIT_TIME
    break if response['done'] == true
    tries -= 1
  end

  yc.delete_object({
                     bucket: ENV['YC_BUCKET_NAME'],
                     key: file_name
                   })
  answer = nested_hash_value(response, 'text')
  answer || 'Не смогли распознать :('
end

def telegram_bot
  Telegram::Bot::Client.run(ENV['TG_BOT_TOKEN']) do |bot|
    begin
      bot.listen do |message|
        if message.instance_of?(Telegram::Bot::Types::Message) && message.voice 
          file_name = voice_upload(message)
          operation_id = speech_detect(file_name)
          answer = get_rezult(operation_id, file_name)
          bot.api.send_message(chat_id: message.chat.id, text: answer)
        elsif message.instance_of?(Telegram::Bot::Types::Message) && message.text == '/start'
          bot.api.send_message(chat_id: message.chat.id,
                              text: "Привет, #{message.from.first_name}! Отправь голосовое, получи текст!")
        else
          bot.api.send_message(chat_id: message.chat.id, text: 'Распознаю только речь :)')
        end
      end
    rescue Telegram::Bot::Exceptions::ResponseError => e
      retry
    end
  end
end

def nested_hash_value(obj, key)
  if obj.respond_to?(:key?) && obj.key?(key)
    obj[key]
  elsif obj.respond_to?(:each)
    r = nil
    obj.find { |*a| r = nested_hash_value(a.last, key) }
    r
  end
end

telegram_bot
