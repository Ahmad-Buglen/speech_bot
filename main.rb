# frozen_string_literal: true

require 'sinatra'
require 'telegram/bot'
require 'dotenv/load'
require_relative 'yandex_cloud_api'

def handle_voice(message, bot, yc_api)
  path = bot.api.get_file(file_id: message.voice.file_id).dig(
    'result', 'file_path'
  )
  file = HTTParty.get("https://api.telegram.org/file/bot#{ENV['TG_BOT_TOKEN']}/#{path}")&.body

  name = "#{message.chat.id}_#{message.message_id}.ogg'"
  yc_api.file_upload(file, name)
  operation_id = yc_api.speech_detect(name)
  text = yc_api.get_rezult(operation_id)
  bot.api.send_message(chat_id: message.chat.id, text: text)
  yc_api.file_remove(name)
end

def message_handle(message, bot, yc_api)
  if message.instance_of?(Telegram::Bot::Types::Message) && message.voice
    handle_voice(message, bot, yc_api)
  elsif message.instance_of?(Telegram::Bot::Types::Message) && message.text == '/start'
    bot.api.send_message(chat_id: message.chat.id,
                         text: "Привет, #{message.from.first_name}! Отправь голосовое, получи текст!")
  else
    bot.api.send_message(chat_id: message.chat.id, text: 'Распознаю только речь :)')
  end
end

def telegram_bot
  yc_api = YandexCloudAPI.new
  Telegram::Bot::Client.run(ENV['TG_BOT_TOKEN']) do |bot|
    bot.listen do |message|
      message_handle(message, bot, yc_api)
    end
  rescue Telegram::Bot::Exceptions::ResponseError => e
    retry
  end
end

telegram_bot
