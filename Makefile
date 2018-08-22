all: plugin gem

plugin:
	docker build -t logstash-output-jms .

gemfile:
	docker run --rm -v $(shell pwd):/usr/src/app -w /usr/src/app jruby:9 bundle install --system

gem:
	docker run --rm -v $(shell pwd):/usr/src/app -w /usr/src/app plugin gem build logstash-output-jms.gemspec