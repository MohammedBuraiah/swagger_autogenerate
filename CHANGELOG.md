## [Unreleased]

### Improved
- README documents full Rails + rswag host setup (routes, initializers, SwaggerCombiner, rake/bin)

## [2.0.0] - 2026-09-03

### Breaking
- Default `security` is now `[]` (no project-specific `org_slug` / `locale` schemes)
- Default OpenAPI document is built from app name + empty `securitySchemes`
- Env-gated generation helpers renamed conceptually to `SwaggerAutogenerate.generate?` (`allow_swagger?` still works)
- Internal code split into focused classes (public configure API unchanged in spirit)

### Added
- Railtie auto-includes into `ApplicationController` in the configured test environment
- RSpec test suite for configuration, helpers, schema/params/responses, and YAML generation
- rswag-friendly `default_path` resolution (`swagger` / `swagger/v1`)
- Ergonomic config: `info_title`, `servers`, `security_schemes`, `auto_include`

### Improved
- README for rswag-api / rswag-ui usage
- Clearer module layout under `lib/swagger_autogenerate/`

## [1.2.9] - 2025-11-24
## [1.2.8] - 2024-11-05
## [1.2.6] - 2024-11-05
## [1.2.5] - 2024-09-15
## [1.2.4] - 2024-09-15
## [1.2.3] - 2024-09-12
## [1.2.2] - 2024-09-12
## [1.2.1] - 2024-09-08
## [1.2.0] - 2024-09-08
## [1.1.2] - 2024-08-17
## [1.1.1] - 2024-06-26
## [1.1.0] - 2024-06-23
## [1.0.9] - 2024-06-04
## [1.0.8] - 2024-06-03
## [1.0.7] - 2024-06-01
## [1.0.6] - 2024-06-01
## [1.0.5] - 2024-06-01
## [1.0.4] - 2024-06-01
## [1.0.3] - 2024-05-31
## [1.0.2] - 2024-05-31
## [0.1.1] - 2024-05-27

- Initial release
