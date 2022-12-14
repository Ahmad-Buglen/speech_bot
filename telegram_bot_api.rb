# frozen_string_literal: true

class TelegramBotAPI
  def download_file(message)
    path = HTTParty.get("#{TG_BOT_API}/bot#{ENV['TG_BOT_TOKEN']}/getFile?file_id=#{message.voice.file_id}").to_h.dig(
      'result', 'file_path'
    )
    HTTParty.get("#{TG_BOT_API}/file/bot#{ENV['TG_BOT_TOKEN']}/#{path}")&.body
  end
end
