# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwaggerAutogenerate::Helpers do
  describe '.snake_case' do
    it { expect(described_class.snake_case('Employees')).to eq('employees') }
    it { expect(described_class.snake_case('API')).to eq('api') }
    it { expect(described_class.snake_case('User Profiles')).to eq('user_profiles') }
  end

  describe '.number?' do
    it { expect(described_class.number?('42')).to eq(true) }
    it { expect(described_class.number?('abc')).to eq(false) }
  end

  describe '.valid_date?' do
    it { expect(described_class.valid_date?('2024-01-15')).to eq(true) }
    it { expect(described_class.valid_date?('not-a-date')).to eq(false) }
  end

  describe '.format_path_to_title' do
    it 'strips version and params' do
      expect(described_class.format_path_to_title('/v1/users/{id}/posts')).to eq('Users Posts')
    end
  end

  describe '.json_example_plus_one' do
    it { expect(described_class.json_example_plus_one('example-1')).to eq('example-2') }
  end

  describe '.merge_properties' do
    it 'deep merges hashes' do
      left = { 'a' => { 'b' => 1 }, 'c' => 2 }
      right = { 'a' => { 'd' => 3 }, 'e' => 4 }
      expect(described_class.merge_properties(left, right)).to eq(
        'a' => { 'b' => 1, 'd' => 3 },
        'c' => 2,
        'e' => 4
      )
    end
  end
end
