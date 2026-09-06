# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwaggerAutogenerate::SwaggerTrace do
  let(:tmpdir) { Dir.mktmpdir }
  let(:swagger_file) { File.join(tmpdir, 'users.yaml') }

  let(:request) do
    double(
      'Request',
      path: '/users',
      method: 'POST',
      path_parameters: { controller: 'users', action: 'create', format: nil },
      query_parameters: {},
      request_parameters: { 'name' => 'Ada' },
      params: { 'controller' => 'users', 'action' => 'create' }
    )
  end

  let(:response) do
    double('Response', status: 201, body: { id: 1, name: 'Ada' }.to_json)
  end

  before do
    Rails.root = Pathname.new(tmpdir)
    ENV['SWAGGER_GENERATE_PATH'] = swagger_file
    described_class.rspec_description = 'creates a user'
  end

  after do
    FileUtils.remove_entry(tmpdir)
  end

  it 'creates an OpenAPI YAML file from a request/response' do
    described_class.new(request, response).call

    doc = YAML.safe_load(File.read(swagger_file), permitted_classes: [Date, Time, DateTime, Symbol])

    expect(doc['openapi']).to eq('3.0.1')
    expect(doc['info']['title']).to eq('DemoApp')
    expect(doc['paths']['/users']['post']['tags']).to eq(['Users'])
    expect(doc['paths']['/users']['post']['summary']).to eq('Create Users')
    expect(doc['paths']['/users']['post']['responses']['201']['content']['application/json']['examples']).to include(
      'creates a user'
    )
  end

  it 'appends another example on a second call' do
    described_class.new(request, response).call

    described_class.rspec_description = 'creates another user'
    allow(response).to receive(:body).and_return({ id: 2, name: 'Grace' }.to_json)
    described_class.new(request, response).call

    doc = YAML.safe_load(File.read(swagger_file), permitted_classes: [Date, Time, DateTime, Symbol])
    examples = doc['paths']['/users']['post']['responses']['201']['content']['application/json']['examples']

    expect(examples.keys).to include('creates a user', 'creates another user')
  end

  it 'templates path parameters' do
    show_request = double(
      'Request',
      path: '/users/99',
      method: 'GET',
      path_parameters: { controller: 'users', action: 'show', format: nil, id: '99' },
      query_parameters: {},
      request_parameters: {},
      params: { 'controller' => 'users', 'action' => 'show', 'id' => '99' }
    )
    show_response = double('Response', status: 200, body: { id: 99 }.to_json)
    ENV['SWAGGER_GENERATE_PATH'] = File.join(tmpdir, 'show.yaml')

    described_class.new(show_request, show_response).call
    doc = YAML.safe_load(File.read(ENV['SWAGGER_GENERATE_PATH']), permitted_classes: [Date, Time, DateTime, Symbol])

    expect(doc['paths'].keys).to include('/users/{id}')
    expect(doc['paths']['/users/{id}']['get']['parameters'].first['name']).to eq('id')
  end

  it 'writes into default_path when SWAGGER_GENERATE is set' do
    ENV.delete('SWAGGER_GENERATE_PATH')
    ENV['SWAGGER_GENERATE'] = '1'
    SwaggerAutogenerate.configure { |c| c.default_path = 'swagger/v1' }

    described_class.new(request, response).call

    generated = File.join(tmpdir, 'swagger/v1/users.yaml')
    expect(File.exist?(generated)).to eq(true)
  end
end
