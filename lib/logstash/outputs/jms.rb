# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"

# Write events to a Jms Broker. Supports both Jms Queues and Topics.
#
# For more information about Jms, see <http://docs.oracle.com/javaee/6/tutorial/doc/bncdq.html>
# For more information about the Ruby Gem used, see <http://github.com/reidmorrison/jruby-jms>
# Here is a config example :
#  jms {
#     include_header => false
#     include_properties => false
#     include_body => true
#     use_jms_timestamp => false
#     queue_name => "myqueue"
#     yaml_file => "~/jms.yml"
#     yaml_section => "mybroker"
#   }
#
#
class LogStash::Outputs::Jms < LogStash::Outputs::Base
  config_name "jms"

# Name of delivery mode to use
# Options are "persistent" and "non_persistent" if not defined nothing will be passed.
config :delivery_mode, :validate => %w(persistent non_persistent)

# If pub-sub (topic) style should be used or not.
# Mandatory
config :pub_sub, :validate => :boolean, :default => false
# Name of the destination queue or topic to use.
# Mandatory
config :destination, :validate => :string

# Yaml config file
config :yaml_file, :validate => :string
# Yaml config file section name
# For some known examples, see: [Example jms.yml](https://github.com/reidmorrison/jruby-jms/blob/master/examples/jms.yml)
config :yaml_section, :validate => :string

# If you do not use an yaml configuration use either the factory or jndi_name.

# An optional array of Jar file names to load for the specified
# JMS provider. By using this option it is not necessary
# to put all the JMS Provider specific jar files into the
# java CLASSPATH prior to starting Logstash.
config :require_jars, :validate => :array

# Name of JMS Provider Factory class
config :factory, :validate => :string
# Username to connect to JMS provider with
config :username, :validate => :string
# Password to use when connecting to the JMS provider
config :password, :validate => :string
# Url to use when connecting to the JMS provider
config :broker_url, :validate => :string

# Name of JNDI entry at which the Factory can be found
config :jndi_name, :validate => :string
# Mandatory if jndi lookup is being used,
# contains details on how to connect to JNDI server
config :jndi_context, :validate => :hash

config :system_properties, :validate => :hash

config :keystore, :validate => :path
config :keystore_password, :validate => :password
config :truststore, :validate => :path
config :truststore_password, :validate => :password


# :yaml_file, :factory and :jndi_name are mutually exclusive, both cannot be supplied at the
# same time. The priority order is :yaml_file, then :jndi_name, then :factory
#
# JMS Provider specific properties can be set if the JMS Factory itself
# has setters for those properties.
#
# For some known examples, see: [Example jms.yml](https://github.com/reidmorrison/jruby-jms/blob/master/examples/jms.yml)

  public
  def register
    require "jms"
    @connection = nil

    load_ssl_properties
    load_system_properties if @system_properties

    @jms_config = jms_config

    logger.debug("JMS Config being used ", :context => obfuscate_jms_config(@jms_config))

    setup_producer
  end

  def setup_producer
    begin
      # The jruby-jms adapter dynamically loads the Java classes that it extends, and may fail
      @connection = JMS::Connection.new(@jms_config)
    rescue NameError => ne
      if @require_jars && !@require_jars.empty?
        logger.warn('The `require_jars` directive was provided, but may not correctly map to a JMS provider', :require_jars => @require_jars)
      end
      logger.error('Failed to load JMS Connection, likely because a JMS Provider is not on the Logstash classpath '+
                       'or correctly specified by the plugin\'s `require_jars` directive', :exception => ne.message, :backtrace => ne.backtrace)
      fail(LogStash::PluginLoadingError, 'JMS Output plugin failed to load, likely because a JMS provider is not on the Logstash classpath')
    rescue => e
      logger.error("Unable to connect to JMS Provider. Retrying", error_hash(e))
      sleep(5)
      retry
    end

    @session = @connection.create_session

    # Cache the producer since we should keep reusing this one.
    destination_key = @pub_sub ? :topic_name : :queue_name
    @producer = @session.create_producer(@session.create_destination(destination_key => @destination))

    # If a delivery mode has been specified, inform the producer
    @producer.delivery_mode_sym = @delivery_mode.to_sym unless @delivery_mode.nil?
  end

# def register


  def obfuscate_jms_config(config)
    config.each_with_object({}) { |(k, v), h| h[k] = obfuscatable?(k) ? 'xxxxx' : v }
  end

  def obfuscatable?(setting)
    [:password, :keystore_password, :truststore_password].include?(setting)
  end

  def jms_config
      return jms_config_from_yaml(@yaml_file, @yaml_section) if @yaml_file
      return jms_config_from_jndi if @jndi_name
      jms_config_from_configuration
  end

  def jms_config_from_configuration
    {
        :require_jars => @require_jars,
        :factory => @factory,
        :username => @username,
        :password => @password,
        :broker_url => @broker_url,
        :url => @broker_url # "broker_url" is named "url" with Oracle AQ
    }
  end

  def jms_config_from_jndi
    {
        :require_jars => @require_jars,
        :jndi_name => @jndi_name,
        :jndi_context => @jndi_context
    }
  end

  def jms_config_from_yaml(file, section)
    YAML.load_file(file)[section]
  end

  def load_ssl_properties
    java.lang.System.setProperty("javax.net.ssl.keyStore", @keystore) if @keystore
    java.lang.System.setProperty("javax.net.ssl.keyStorePassword", @keystore_password.value) if @keystore_password
    java.lang.System.setProperty("javax.net.ssl.trustStore", @truststore) if @truststore
    java.lang.System.setProperty("javax.net.ssl.trustStorePassword", @truststore_password.value) if @truststore_password
  end

  def load_system_properties
    @system_properties.each do |key,value|
      java.lang.System.set_property(key,value.to_s)
    end
  end

  def receive(event)
      begin
        mess = @session.message(event.to_json)
        @producer.send(mess)
      rescue Object => e
        logger.warn("Failed to send event to JMS", {:event => event}.merge(error_hash(e)))
        cleanup_producer
        setup_producer
        retry
      end
  end # def receive

  def cleanup_producer
    @producer.close unless @producer.nil?
    @session.close unless @session.nil?
    @connection.close unless @connection.nil?
  end

  def close
    cleanup_producer
  end

  def error_hash(e)
    error_hash = {:exception => e.class.name, :exception_message => e.message, :backtrace => e.backtrace}
    root_cause = get_root_cause(e)
    unless root_cause.nil?
      error_hash.merge!(:root_cause => root_cause)
    end
    error_hash
  end

  # JMS Exceptions can contain chains of Exceptions, making it difficult to determine the root cause of an error
  # without knowing the actual root cause behind the problem.
  # This method protects against Java Exceptions where the cause methods loop. If there is a cause loop, the last
  # cause exception before the loop is detected will be returned, along with an entry in the root_cause hash indicating
  # that an exception loop was detected.
  def get_root_cause(e)
    return nil unless e.respond_to?(:get_cause) && !e.get_cause.nil?
    cause = e
    slow_pointer = e
    # Use a slow pointer to avoid cause loops in Java Exceptions
    move_slow = false
    until (next_cause = cause.get_cause).nil?
      cause = next_cause
      return {:exception => cause.class.name, :exception_message => cause.message, :exception_loop => true } if cause == slow_pointer
      slow_pointer = slow_pointer.cause if move_slow
      move_slow = !move_slow
    end
    {:exception => cause.class.name, :exception_message => cause.message }
  end
end # class LogStash::Output::Jms
