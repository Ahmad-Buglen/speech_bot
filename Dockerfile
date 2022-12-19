FROM ruby:2.7.4

WORKDIR /speech_bot
COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY main.rb yandex_cloud_api.rb config.ru .env Dockerfile ./

# EXPOSE 4567
# CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "-p", "4567"]

CMD ["bundle", "exec", "rackup"]