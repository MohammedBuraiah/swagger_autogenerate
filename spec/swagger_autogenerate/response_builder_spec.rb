# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwaggerAutogenerate::ResponseBuilder do
  let(:response) { double('Response', status: 201, body: { id: 1, name: 'Ada' }.to_json) }
  let(:config) { SwaggerAutogenerate.configuration }

  subject(:builder) { described_class.new(response, config: config, example_title: 'creates a user') }

  it 'builds a status response with example and description' do
    result = builder.build

    expect(result.keys).to eq(['201'])
    expect(result['201']['description']).to include('created')
    expect(result['201']['content']['application/json']['examples']['creates a user']['value']).to eq(
      'id' => 1,
      'name' => 'Ada'
    )
  end

  it 'falls back when body is not JSON' do
    allow(response).to receive(:body).and_return('not-json')
    result = builder.build

    expect(result['201']['content']['application/json']['examples']['creates a user']['value']).to eq(
      'file' => 'file/data'
    )
  end
end
