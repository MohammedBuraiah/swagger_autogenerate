# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwaggerAutogenerate::SchemaBuilder do
  subject(:builder) { described_class.new }

  describe '#schema_type' do
    it { expect(builder.schema_type('1')).to eq('integer') }
    it { expect(builder.schema_type('true')).to eq('boolean') }
    it { expect(builder.schema_type('hello')).to eq('string') }
    it { expect(builder.schema_type([1])).to eq('array') }
    it { expect(builder.schema_type('a' => 1)).to eq('object') }
  end

  describe '#schema_data' do
    it 'builds object properties' do
      result = builder.schema_data('name' => 'Ada', 'age' => '30')

      expect(result['type']).to eq('object')
      expect(result['properties']['name']['type']).to eq('string')
      expect(result['properties']['age']['type']).to eq('integer')
    end
  end

  describe '#build_properties' do
    it 'infers nested schema from a hash payload' do
      result = builder.build_properties('user' => { 'email' => 'a@b.com' })

      expect(result['type']).to eq('object')
      expect(result['properties']['user']['type']).to eq('object')
      expect(result['properties']['user']['properties']['email']['example']).to eq('a@b.com')
    end

    it 'handles arrays of objects' do
      result = builder.build_properties([{ 'id' => 1 }, { 'id' => 2, 'name' => 'x' }])

      expect(result['type']).to eq('array')
      expect(result['items']['type']).to eq('object')
      expect(result['items']['properties']).to include('id', 'name')
    end
  end
end
