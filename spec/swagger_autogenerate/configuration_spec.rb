# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwaggerAutogenerate::Configuration do
  subject(:config) { described_class.new }

  it 'enables useful defaults for any project' do
    expect(config.with_config).to eq(true)
    expect(config.with_multiple_examples).to eq(true)
    expect(config.with_rspec_examples).to eq(true)
    expect(config.security).to eq([])
    expect(config.security_schemes).to eq({})
    expect(config.auto_include).to eq(true)
    expect(config.swagger_path_environment_variable).to eq('SWAGGER_GENERATE_PATH')
    expect(config.generate_swagger_environment_variable).to eq('SWAGGER_GENERATE')
    expect(config.action_for_old_examples).to eq(:append)
  end

  it 'resolves default_path to swagger when no override' do
    expect(config.resolved_default_path).to eq('swagger')
  end

  it 'respects an explicit default_path' do
    config.default_path = 'swagger/v1'
    expect(config.resolved_default_path).to eq('swagger/v1')
  end

  it 'builds a generic OpenAPI document' do
    doc = config.resolved_swagger_config

    expect(doc['openapi']).to eq('3.0.1')
    expect(doc['info']['title']).to eq('DemoApp')
    expect(doc['info']['version']).to eq('1.0.0')
    expect(doc['components']['securitySchemes']).to eq({})
  end

  it 'uses custom info and security schemes when set' do
    config.info_title = 'Payments API'
    config.info_version = '2.1.0'
    config.security_schemes = {
      'bearerAuth' => {
        'type' => 'http',
        'scheme' => 'bearer'
      }
    }
    config.security = [{ 'bearerAuth' => [] }]
    config.servers = [{ 'url' => 'https://api.example.com' }]

    doc = config.resolved_swagger_config

    expect(doc['info']['title']).to eq('Payments API')
    expect(doc['info']['version']).to eq('2.1.0')
    expect(doc['servers']).to eq([{ 'url' => 'https://api.example.com' }])
    expect(doc['components']['securitySchemes']['bearerAuth']['scheme']).to eq('bearer')
    expect(config.security).to eq([{ 'bearerAuth' => [] }])
  end

  it 'allows a full swagger_config override' do
    custom = { 'openapi' => '3.1.0', 'info' => { 'title' => 'Custom' }, 'paths' => {} }
    config.swagger_config = custom

    expect(config.resolved_swagger_config).to eq(custom)
  end
end

RSpec.describe SwaggerAutogenerate do
  describe '.generate?' do
    it 'is false without env vars' do
      expect(described_class.generate?).to eq(false)
    end

    it 'is true when SWAGGER_GENERATE_PATH is set in test' do
      ENV['SWAGGER_GENERATE_PATH'] = 'swagger/api.yaml'
      expect(described_class.generate?).to eq(true)
    end

    it 'is true when SWAGGER_GENERATE is set' do
      ENV['SWAGGER_GENERATE'] = 'true'
      expect(described_class.generate?).to eq(true)
    end

    it 'is false outside the configured environment' do
      ENV['SWAGGER_GENERATE'] = 'true'
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      expect(described_class.generate?).to eq(false)
    end
  end

  describe '.configure' do
    it 'yields configuration for customization' do
      described_class.configure do |c|
        c.default_path = 'docs/openapi'
        c.with_multiple_examples = false
      end

      expect(described_class.configuration.default_path).to eq('docs/openapi')
      expect(described_class.configuration.with_multiple_examples).to eq(false)
    end
  end
end
