# frozen_string_literal: true

require 'aws-sdk-s3'
require 'httparty'

YC_API = 'api.cloud.yandex.net'
YC_ENDPOINT = 'https://storage.yandexcloud.net'
WAIT_TIME = 2
REPEAT_COUNT = 15

Aws.config.update(
  region: 'ru-central1',
  credentials: Aws::Credentials.new(ENV['YC_ACCESS_KEY_ID'], ENV['YC_SECRET_ACCESS_KEY'])
)

# YandexCloudAPI
class YandexCloudAPI
  attr_reader :client, :endpoint, :bucket, :header_api_key

  def initialize(bucket = ENV['YC_BUCKET_NAME'])
    @client = Aws::S3::Client.new(endpoint: YC_ENDPOINT)
    @bucket = bucket
    @header_api_key = { 'Authorization' => "Api-Key #{ENV['YC_API_KEY']}" }
  end

  def file_upload(file, name)
    client.put_object({
                        bucket: bucket,
                        key: name,
                        body: file
                      })
  end

  def file_remove(name)
    client.delete_object({
                           bucket: bucket,
                           key: name
                         })
  end

  def speech_detect(file_name)
    options = {
      headers: header_api_key,
      body: {
        'config' => {
          'specification' => {
            'languageCode' => 'ru-RU'
          }
        },
        'audio' => {
          'uri' => "#{YC_ENDPOINT}/#{bucket}/#{file_name}"
        }
      }.to_json
    }
    HTTParty.post("https://transcribe.#{YC_API}/speech/stt/v2/longRunningRecognize",
                  options).to_h['id']
  end

  def get_rezult(operation_id)
    tries = REPEAT_COUNT
    while tries.positive?
      response = HTTParty.get("https://operation.#{YC_API}/operations/#{operation_id}",
                              { headers: header_api_key }).to_h
      sleep WAIT_TIME
      break if response['done'] == true

      tries -= 1
    end
    answer = response.dig('response', 'chunks')&.map { |e| e['alternatives']&.first&.dig('text') }&.join(' ')
    answer || 'Не смогли распознать :('
  end
end
