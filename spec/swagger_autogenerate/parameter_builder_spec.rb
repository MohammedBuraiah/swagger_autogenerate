# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwaggerAutogenerate::ParameterBuilder do
  let(:request) do
    double(
      'Request',
      path_parameters: { controller: 'users', action: 'create', format: nil, id: '5' },
      query_parameters: { 'page' => '1', 'filter' => { 'active' => 'true' } },
      request_parameters: { 'name' => 'Ada', 'email' => 'ada@example.com' }
    )
  end

  subject(:builder) { described_class.new(request) }

  it 'builds path and query parameters' do
    params = builder.parameters

    path_param = params.find { |p| p['name'] == 'id' && p['in'] == 'path' }
    expect(path_param['required']).to eq(true)
    expect(path_param['schema']['type']).to eq('integer')

    page_param = params.find { |p| p['name'] == 'page' && p['in'] == 'query' }
    expect(page_param).not_to be_nil

    filter_param = params.find { |p| p['name'] == 'filter' && p['in'] == 'query' }
    expect(filter_param['style']).to eq('deepObject')
    expect(filter_param['explode']).to eq(true)
  end

  it 'builds a request body from request parameters' do
    body = builder.request_body

    expect(body['content']['multipart/form-data']['schema']['type']).to eq('object')
    expect(body['content']['multipart/form-data']['schema']['properties']).to include('name', 'email')
  end

  it 'returns nil request body when empty' do
    allow(request).to receive(:request_parameters).and_return({})
    expect(builder.request_body).to be_nil
  end
end
