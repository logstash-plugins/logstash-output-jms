require_relative '../spec_helper'
require 'logstash/outputs/jms'
require 'jms'
require 'json'

describe LogStash::Outputs::Jms do
  let (:jms_config) {{'destination' => 'ExampleQueue'}}
  subject { described_class.new(jms_config)}

  describe 'initialization' do
    let (:yaml_section) { 'activemq' }

    before :each do
      allow(subject).to receive(:setup_producer)
    end
    context 'via yaml file' do
      let (:jms_config) {{'yaml_file' => fixture_path(file), 'yaml_section' => yaml_section, 'destination' => 'ExampleQueue'}}
      context 'simple yaml configuration' do
        let (:file) { "jms.yml" }
        let (:password) { 'the_password' }
        it 'should populate jms config from the yaml file' do
          expect(subject.jms_config).to include({:broker_url => "tcp://localhost:61616",
                                             :factory=>"org.apache.activemq.ActiveMQConnectionFactory",
                                             :password => password,
                                             :require_jars=>["activemq-all.jar"]})
        end
        it 'should not log the password in plaintext' do
          expect(subject.logger).to receive(:debug) do |message, params|
            expect(params[:context]).to include(:password)
            expect(params[:context][:password]).not_to eq(password)
          end
          subject.register
        end

      end

      context 'jndi yaml configuration' do
        let (:file) { "jndijms.yml" }
        let (:yaml_section) { 'solace' }
        it 'should populate jms config from the yaml file' do
          expect(subject.jms_config).to include({:jndi_context=>{
                                                  "java.naming.factory.initial"=>"com.solacesystems.jndi.SolJNDIInitialContextFactory",
                                                  "java.naming.security.principal"=>"username",
                                                  "java.naming.provider.url"=>"tcp://localhost:20608",
                                                  "java.naming.security.credentials"=>"password"},
                                             :jndi_name => "/jms/cf/default",
                                             :require_jars => ["commons-lang-2.6.jar",
                                                               "sol-jms-10.5.0.jar",
                                                               "geronimo-jms_1.1_spec-1.1.1.jar",
                                                               "commons-lang-2.6.jar"]})
        end
      end
    end

    context 'simple configuration' do
      let (:password) { 'the_password' }
      let (:jms_config) {{
                          'destination' => 'ExampleQueue',
                          'username' => 'user',
                          'password' => password,
                          'broker_url' => 'tcp://localhost:61616',
                          'pub_sub' => true,
                          'factory' => 'org.apache.activemq.ActiveMQConnectionFactory',
                          'require_jars' => ['activemq-all-5.15.8.jar']
                          }}
      it 'should populate jms config from the configuration' do
        expect(subject.jms_config).to include({:broker_url => "tcp://localhost:61616",
                                           :factory=>"org.apache.activemq.ActiveMQConnectionFactory",
                                           :require_jars=>["activemq-all-5.15.8.jar"]})
      end
      it 'should not log the password in plaintext' do
        expect(subject.logger).to receive(:debug) do |message, params|
          expect(params[:context]).to include(:password)
          expect(params[:context][:password]).not_to eq(password)
        end
        subject.register
      end

    end
    context 'simple configuration with jndi' do
      let (:jms_config) {{
          'destination' => 'ExampleQueue',
          'jndi_name' => "/jms/cf/default",
          "jndi_context" => {
              "java.naming.factory.initial"=>"com.solacesystems.jndi.SolJNDIInitialContextFactory",
              "java.naming.security.principal"=>"username",
              "java.naming.provider.url"=>"tcp://localhost:20608",
              "java.naming.security.credentials"=>"password"},
          'pub_sub' => true,
          "require_jars" => ["commons-lang-2.6.jar",
                            "sol-jms-10.5.0.jar",
                            "geronimo-jms_1.1_spec-1.1.1.jar",
                            "commons-lang-2.6.jar"]}}


      it 'should populate jms config from the configuration' do
        expect(subject.jms_config).to include({:jndi_context=>{
            "java.naming.factory.initial"=>"com.solacesystems.jndi.SolJNDIInitialContextFactory",
            "java.naming.security.principal"=>"username",
            "java.naming.provider.url"=>"tcp://localhost:20608",
            "java.naming.security.credentials"=>"password"},
                                           :jndi_name => "/jms/cf/default",
                                           :require_jars => ["commons-lang-2.6.jar",
                                                             "sol-jms-10.5.0.jar",
                                                             "geronimo-jms_1.1_spec-1.1.1.jar",
                                                             "commons-lang-2.6.jar"]})
      end
    end
  end
  describe '#error_hash' do

    context 'with a java exception cause chain' do
      let (:raised) { java.lang.Exception.new("Outer", java.lang.RuntimeException.new("middle", java.io.IOException.new("Inner")))}
      let (:expected_message) { "Inner" }

      it 'should find contain the root cause of a java exception cause chain' do
        expect(subject.error_hash(raised)[:exception].to_s).to eql("Java::JavaLang::Exception")
        expect(subject.error_hash(raised)[:exception_message].to_s).to eql("Outer")
        expect(subject.error_hash(raised)[:root_cause][:exception]).to eql("Java::JavaIo::IOException")
        expect(subject.error_hash(raised)[:root_cause][:exception_message]).to eql("Inner")
        expect(subject.error_hash(raised)[:root_cause][:exception_loop]).to be_falsey
      end

    end

    context 'should not go into an infinite loop when a Java Exception cause chain contains a loop' do
      let (:inner)  { java.io.IOException.new("Inner") }
      let (:middle) { java.lang.RuntimeException.new("Middle", inner) }
      let (:raised) { java.lang.Exception.new("Outer", middle)}

      before :each do
        inner.init_cause(middle)
      end

      it 'should not go into an infinite loop when a Java Exception cause chain contains a loop' do
        expect(subject.error_hash(raised)[:exception].to_s).to eql("Java::JavaLang::Exception")
        expect(subject.error_hash(raised)[:exception_message].to_s).to eql("Outer")
        expect(subject.error_hash(raised)[:root_cause][:exception]).to eql("Java::JavaLang::RuntimeException")
        expect(subject.error_hash(raised)[:root_cause][:exception_message]).to eql("Middle")
        expect(subject.error_hash(raised)[:root_cause][:exception_loop]).to be_truthy
      end
    end

    context 'should not go into an infinite loop when a Java Exception cause chain contains a loop' do
      let (:raised) { StandardError.new("Ruby") }

      it 'should not go into an infinite loop when a Java Exception cause chain contains a loop' do
        expect(subject.error_hash(raised)[:exception].to_s).to eql("StandardError")
        expect(subject.error_hash(raised)[:exception_message].to_s).to eql("Ruby")
        expect(subject.error_hash(raised)[:root_cause]).to be_nil
      end
    end

  end

end