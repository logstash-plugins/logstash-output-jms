FROM jruby:9

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock logstash-output-jms.gemspec ./
RUN bundle install
COPY . .
