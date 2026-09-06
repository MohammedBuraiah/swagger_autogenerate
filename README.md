# Swagger Autogenerate

Generate **OpenAPI / Swagger YAML** from your existing Rails RSpec request (or controller) specs.

Designed to drop into projects that use **`rswag-api`** and **`rswag-ui`**:

1. Run specs with `SWAGGER_GENERATE=1` → one YAML fragment per resource under `swagger/v1/`
2. Combine fragments into `swagger/v1/swagger.yaml`
3. Rswag serves that file at `/api-docs`

## Dependencies

- Ruby `>= 2.7`
- Rails `>= 5.2`
- [rspec-rails](https://github.com/rspec/rspec-rails) in the host app
- Recommended: [`rswag-api`](https://github.com/rswag/rswag) + [`rswag-ui`](https://github.com/rswag/rswag)

## Installation

```ruby
# Gemfile
gem 'rswag-api'
gem 'rswag-ui'

group :test do
  gem 'rspec-rails'
  gem 'swagger_autogenerate'
end
```

```bash
bundle install
```

Then add the host-app files below (copy-paste and adjust titles / URLs for your API).

---

## Host app setup (required for rswag UI)

### 1. Mount rswag in `config/routes.rb`

```ruby
mount Rswag::Ui::Engine => "/api-docs"
mount Rswag::Api::Engine => "/api-docs"
```

### 2. `config/initializers/rswag_api.rb`

Serves `swagger/v1/swagger.yaml` at `/api-docs/v1/swagger.yaml`.

```ruby
# frozen_string_literal: true

Rswag::Api.configure do |c|
  # Serves files from swagger/ — so swagger/v1/swagger.yaml → /api-docs/v1/swagger.yaml
  c.openapi_root = Rails.root.join("swagger").to_s
end

Rswag::Ui.configure do |c|
  c.openapi_endpoint "/api-docs/v1/swagger.yaml", "My API V1"
end
```

### 3. `config/initializers/swagger_autogenerate.rb`

Guard with `defined?` so `rails s` does not crash when the gem is only in the `:test` group.

```ruby
# frozen_string_literal: true

# swagger_autogenerate is only loaded in the test (and optionally development) group.
# Guard so `rails s` in development does not crash when the gem is not required.
return unless defined?(SwaggerAutogenerate)

SwaggerAutogenerate.configure do |config|
  # Where SWAGGER_GENERATE writes files (rswag default layout)
  config.default_path = "swagger/v1"

  # OpenAPI info
  config.info_title = "My API"
  config.info_description = "Public HTTP API"
  config.info_version = "1.0.0"
  config.openapi_version = "3.0.1"
  config.servers = [{ "url" => "http://localhost:3000" }]

  # Auth for rswag / OpenAPI (optional — remove if you have no auth)
  config.security_schemes = {
    "bearerAuth" => {
      "type" => "http",
      "scheme" => "bearer",
      "bearerFormat" => "JWT"
    }
  }
  config.security = [{ "bearerAuth" => [] }]

  # Behavior flags
  config.with_config = true
  config.with_multiple_examples = true
  config.with_rspec_examples = true
  config.with_response_description = true
  config.with_payload_properties = true
  config.action_for_old_examples = :append

  # Env var names / environment gate
  config.swagger_path_environment_variable = "SWAGGER_GENERATE_PATH"
  config.generate_swagger_environment_variable = "SWAGGER_GENERATE"
  config.environment_name = :test
  config.auto_include = true
end
```

### 4. Combine fragments → single `swagger.yaml`

`SWAGGER_GENERATE=1` writes **one file per resource** (e.g. `swagger/v1/users.yaml`). Rswag UI expects a **single** file at `swagger/v1/swagger.yaml`. Add a small combiner in the host app.

#### `lib/swagger_combiner.rb`

```ruby
# frozen_string_literal: true

require "yaml"
require "fileutils"

# Merges every OpenAPI fragment under swagger/v1/*.yaml (except swagger.yaml)
# into a single swagger/v1/swagger.yaml for Rswag UI.
module SwaggerCombiner
  module_function

  SOURCE_DIR = File.expand_path("../swagger/v1", __dir__)
  OUTPUT_FILE = File.join(SOURCE_DIR, "swagger.yaml")
  SKIP_BASENAMES = %w[swagger.yaml swagger.yml].freeze

  DEFAULT_DOC = {
    "openapi" => "3.0.1",
    "info" => {
      "title" => "My API",
      "description" => "Public HTTP API",
      "version" => "1.0.0"
    },
    "servers" => [
      { "url" => "http://localhost:3000" }
    ],
    "components" => {
      "securitySchemes" => {
        "bearerAuth" => {
          "type" => "http",
          "scheme" => "bearer",
          "bearerFormat" => "JWT"
        }
      }
    },
    "security" => [
      { "bearerAuth" => [] }
    ],
    "paths" => {}
  }.freeze

  def combine!(source_dir: SOURCE_DIR, output_file: OUTPUT_FILE)
    FileUtils.mkdir_p(source_dir)

    fragments = Dir[File.join(source_dir, "*.{yaml,yml}")]
                  .reject { |path| SKIP_BASENAMES.include?(File.basename(path)) }
                  .sort

    if fragments.empty?
      warn "[SwaggerCombiner] no fragment files found in #{source_dir}"
      write_yaml(output_file, DEFAULT_DOC.dup)
      return output_file
    end

    merged = deep_dup(DEFAULT_DOC)

    fragments.each do |path|
      doc = load_yaml(path)
      next unless doc.is_a?(Hash)

      merged["paths"] = deep_merge(merged["paths"], stringify_keys(doc["paths"] || {}))
      merged["components"] = deep_merge(merged["components"], stringify_keys(doc["components"] || {}))

      if doc["tags"].is_a?(Array)
        merged["tags"] = Array(merged["tags"]) | doc["tags"]
      end
    end

    merged["paths"] = merged["paths"].sort.to_h

    write_yaml(output_file, merged)
    puts "[SwaggerCombiner] wrote #{output_file} (#{merged["paths"].size} paths from #{fragments.size} files)"
    output_file
  end

  def load_yaml(path)
    YAML.safe_load(
      File.read(path),
      permitted_classes: [Date, Time, Symbol],
      aliases: true
    )
  rescue Psych::DisallowedClass, Psych::BadAlias
    YAML.load_file(path) # fragments may contain complex examples
  end

  def write_yaml(path, data)
    File.write(path, data.to_yaml)
  end

  def deep_merge(left, right)
    left = {} unless left.is_a?(Hash)
    right = {} unless right.is_a?(Hash)

    left.merge(right) do |_key, old_val, new_val|
      if old_val.is_a?(Hash) && new_val.is_a?(Hash)
        deep_merge(old_val, new_val)
      else
        new_val.nil? ? old_val : new_val
      end
    end
  end

  def stringify_keys(value)
    case value
    when Hash
      value.each_with_object({}) do |(k, v), memo|
        memo[k.to_s] = stringify_keys(v)
      end
    when Array
      value.map { |item| stringify_keys(item) }
    else
      value
    end
  end

  def deep_dup(value)
    Marshal.load(Marshal.dump(value))
  end
end
```

#### `config/initializers/combine_swagger.rb`

Rebuilds the combined file on every boot so `/api-docs` stays fresh.

```ruby
# frozen_string_literal: true

# Rebuild swagger/v1/swagger.yaml from per-resource fragments on every boot.
# Rswag UI expects a single file at /api-docs/v1/swagger.yaml.
begin
  require Rails.root.join("lib/swagger_combiner")
  SwaggerCombiner.combine!(
    source_dir: Rails.root.join("swagger/v1").to_s,
    output_file: Rails.root.join("swagger/v1/swagger.yaml").to_s
  )
rescue StandardError => e
  warn "[SwaggerCombiner] failed to combine OpenAPI docs: #{e.class}: #{e.message}"
end
```

#### `lib/tasks/swagger.rake`

```ruby
# frozen_string_literal: true

namespace :swagger do
  desc "Combine swagger/v1/*.yaml fragments into swagger/v1/swagger.yaml"
  task combine: :environment do
    require Rails.root.join("lib/swagger_combiner")
    SwaggerCombiner.combine!
  end
end
```

#### `bin/combine_swagger`

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/swagger_combiner"

SwaggerCombiner.combine!
```

```bash
chmod +x bin/combine_swagger
```

---

## Generate docs

In **test**, the gem Railtie includes itself into `ApplicationController` automatically.

```bash
# One YAML fragment per controller tag under swagger/v1/
SWAGGER_GENERATE=1 bundle exec rspec spec/requests/

# Then combine into swagger/v1/swagger.yaml
bin/combine_swagger
# or: bundle exec rake swagger:combine
```

Or write a single file directly:

```bash
SWAGGER_GENERATE_PATH='swagger/v1/swagger.yaml' bundle exec rspec spec/requests/users_spec.rb
```

Generation only runs when:

1. `SWAGGER_GENERATE_PATH` or `SWAGGER_GENERATE` is set, and
2. `Rails.env` matches `config.environment_name` (default `:test`)

Without those env vars, specs run normally and nothing is written.

Open the UI: `http://localhost:3000/api-docs`

### Environment variables

| Variable | Purpose |
|---|---|
| `SWAGGER_GENERATE_PATH` | Exact `.yaml`/`.yml` file **or** a directory (one file per tag) |
| `SWAGGER_GENERATE` | Write under `config.default_path` (rswag-aware) |
| `tag` | Optional override for the OpenAPI tag / filename stem |

### Manual include / disable auto-include

```ruby
# app/controllers/application_controller.rb
include SwaggerAutogenerate if Rails.env.test?
```

```ruby
# config/initializers/swagger_autogenerate.rb
config.auto_include = false
```

---

## Configuration reference

Only override what you need. Defaults are project-agnostic (empty security, app name as title, `swagger` output path).

### Full document override

```ruby
SwaggerAutogenerate.configure do |config|
  config.swagger_config = {
    "openapi" => "3.0.1",
    "info" => { "title" => "Custom", "version" => "1.0.0" },
    "components" => { "securitySchemes" => {} }
  }
end
```

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
