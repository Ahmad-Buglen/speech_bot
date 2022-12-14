# frozen_string_literal: true

class YandexCloudAPI
  def file_upload(file, name)
    Aws::S3::Client.new(endpoint: YC_ENDPOINT).put_object({
                                                            bucket: ENV['YC_BUCKET_NAME'],
                                                            key: name,
                                                            body: file
                                                          })
  end

  def file_remove(name)
    Aws::S3::Client.new(endpoint: YC_ENDPOINT).delete_object({
                                                               bucket: ENV['YC_BUCKET_NAME'],
                                                               key: name
                                                             })
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
end
