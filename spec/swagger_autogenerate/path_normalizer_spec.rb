# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SwaggerAutogenerate::PathNormalizer do
  def request_double(path:, path_parameters: {})
    double(
      'Request',
      path: path,
      path_parameters: path_parameters.merge(controller: 'users', action: 'show', format: nil)
    )
  end

  it 'replaces path parameter values with templates' do
    request = request_double(path: '/users/42/posts/9', path_parameters: { id: '42', post_id: '9' })

    expect(described_class.call(request)).to eq('/users/{id}/posts/{post_id}')
  end

  it 'leaves static paths unchanged' do
    request = request_double(path: '/users', path_parameters: {})

    expect(described_class.call(request)).to eq('/users')
  end
end
