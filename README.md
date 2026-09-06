# Swagger Autogenerate

Generate **OpenAPI / Swagger YAML** from your existing Rails RSpec request (or controller) specs.

Designed to drop into projects that already use **`rswag-api`** and **`rswag-ui`**: run specs → YAML lands under `swagger/` (or `swagger/v1/`) → rswag serves and renders it.

## Why

- Keep docs in sync with real request/response behavior from tests
- No hand-maintained path definitions for happy-path coverage
- Works with any Rails app; rswag-friendly defaults out of the box

## Dependencies

- Ruby `>= 2.7`
- Rails `>= 5.2`
- [rspec-rails](https://github.com/rspec/rspec-rails) in the host app
- Optional but recommended: [`rswag-api`](https://github.com/rswag/rswag) + [`rswag-ui`](https://github.com/rswag/rswag)

## Installation

Add to the test group:

```ruby
group :test do
  gem 'swagger_autogenerate'
end
```

```bash
bundle install
```

### With rswag

Typical Gemfile:

```ruby
gem 'rswag-api'
gem 'rswag-ui'

group :test do
  gem 'rspec-rails'
  gem 'swagger_autogenerate'
end
```

Point rswag at the same folder this gem writes to (default `swagger` or `swagger/v1` when that directory exists).

## Quick start

### 1. Auto-include (default)

In **test**, the gem Railtie includes itself into `ApplicationController` automatically.

You can still include manually if you prefer:

```ruby
# app/controllers/application_controller.rb
include SwaggerAutogenerate if Rails.env.test?
```

Disable auto-include:

```ruby
# config/initializers/swagger_autogenerate.rb
SwaggerAutogenerate.configure do |config|
  config.auto_include = false
end
```

### 2. Generate docs from specs

Write a normal file path (recommended with rswag):

```bash
SWAGGER_GENERATE_PATH='swagger/v1/swagger.yaml' bundle exec rspec spec/requests/users_spec.rb
```

Or generate one YAML file per controller tag under the default directory:

```bash
SWAGGER_GENERATE=1 bundle exec rspec spec/requests/
# => swagger/users.yaml  (or swagger/v1/users.yaml when that folder exists / is configured)
```

Generation only runs when:

1. `SWAGGER_GENERATE_PATH` or `SWAGGER_GENERATE` is set, and
2. `Rails.env` matches `config.environment_name` (default `:test`)

Without those env vars, specs run normally and nothing is written.

## Configuration

Optional initializer — **only override what you need**. Defaults are project-agnostic (empty security, app name as title, `swagger` output path).

```ruby
# config/initializers/swagger_autogenerate.rb
SwaggerAutogenerate.configure do |config|
  # Where SWAGGER_GENERATE writes files (rswag default layout)
  config.default_path = 'swagger/v1'

  # OpenAPI info (auto title = Rails app module name when unset)
  config.info_title = 'My API'
  config.info_description = 'Public HTTP API'
  config.info_version = '1.0.0'
  config.openapi_version = '3.0.1'
  config.servers = [{ 'url' => 'https://api.example.com' }]

  # Auth for rswag / OpenAPI
  config.security_schemes = {
    'bearerAuth' => {
      'type' => 'http',
      'scheme' => 'bearer',
      'bearerFormat' => 'JWT'
    }
  }
  config.security = [{ 'bearerAuth' => [] }]

  # Behavior flags
  config.with_config = true                 # write openapi/info/components header
  config.with_multiple_examples = true      # keep several response examples per status
  config.with_rspec_examples = true         # use RSpec example group description as example name
  config.with_response_description = true   # human-readable status descriptions
  config.with_payload_properties = true     # document request payload shapes per example
  config.action_for_old_examples = :append  # or :replace

  # Env var names / environment gate (rarely changed)
  config.swagger_path_environment_variable = 'SWAGGER_GENERATE_PATH'
  config.generate_swagger_environment_variable = 'SWAGGER_GENERATE'
  config.environment_name = :test
  config.auto_include = true
end
```

### Full document override

If you already maintain a root OpenAPI hash (or want zero magic):

```ruby
SwaggerAutogenerate.configure do |config|
  config.swagger_config = {
    'openapi' => '3.0.1',
    'info' => { 'title' => 'Custom', 'version' => '1.0.0' },
    'components' => { 'securitySchemes' => {} }
  }
end
```

### Environment variables

| Variable | Purpose |
|---|---|
| `SWAGGER_GENERATE_PATH` | Exact `.yaml`/`.yml` file **or** a directory (one file per tag) |
| `SWAGGER_GENERATE` | Write under `config.default_path` (rswag-aware) |
| `tag` | Optional override for the OpenAPI tag / filename stem |

## Example

```bash
SWAGGER_GENERATE_PATH='swagger/v1/swagger.yaml' \
  bundle exec rspec spec/requests/employees_spec.rb
```

Coverage in the YAML matches what your examples actually hit (paths, statuses, bodies, query/path params). Prefer request specs that exercise real routes.

## Library layout

```
lib/swagger_autogenerate/
  configuration.rb      # defaults + customization
  swagger_trace.rb      # orchestrates one request/response
  path_normalizer.rb    # /users/1 → /users/{id}
  parameter_builder.rb  # parameters + requestBody
  response_builder.rb   # responses + examples
  schema_builder.rb     # type inference
  document_writer.rb    # read/write YAML
  yaml_merger.rb        # merge into existing document
  helpers.rb
  railtie.rb            # auto-include in test
```

## Development

```bash
bundle install
bundle exec rspec
```

## License

MIT — see [LICENSE.txt](LICENSE.txt).
