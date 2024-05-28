# SwaggerAutogenerate
automating Swagger YAML generation in Ruby on Rails offers a range of benefits for API documentation. By leveraging the power of the swagger_autogenerate gem, developers can:
1) save time and effort
2) (up to date) reducing the chances of inconsistencies between the actual API implementation and its documentation.
3) improves the overall development workflow by providing a seamless integration with testing frameworks like RSpec.
4) resulting in better communication and understanding of the APIs.

The gem automatically observes the request/response patterns during the execution of test scenarios, generating accurate Swagger YAML files that reflect the API's behavior. developers and consumers can better understand and interact with the APIs.

## Installation

1) Open your Gemfile located at ./Gemfile
2) Add the following line to the Gemfile within the appropriate group (e.g., :test):

    ```
    group :test do
      gem 'swagger_autogenerate'
    end
    ```
3) Install the gem and add to the application's Gemfile by executing:
   ```
   bundle install
   ```

## Configuration

To configure the swagger_autogenerate gem in your Rails application, follow these steps:

### Step 1:
1) Open the app/controllers/application_controller.rb
2) Inside the class ApplicationController block.
3) Add the following code:
```
    include SwaggerAutogenerate if Rails.env.test? && ENV['SWAGGER'].present?
```
in the #Example-step you will set the ENV['SWAGGER'], 

By setting the ENV['SWAGGER'] environment variable, you can specify the path to the new file,
whether it's a specific file (e.g., ../myfile.yaml) or a directory (e.g., ../docs).
This flexibility ensures that the documentation can be easily integrated into your project's structure and workflow.

### Step 2 (optional)
1) Create a file called swagger_autogenerate.rb in the ./config/initializers
2) Open the ./config/initializers/swagger/swagger_autogenerate.rb
3) Add the following code to the swagger_autogenerate.rb
```
module SwaggerAutogenerate
  class SwaggerTrace
    WITH_CONFIG = true
    WITH_MULTIPLE_EXAMPLES = true
    WITH_EXAMPLE_DESCRIPTION = true
    WITH_RESPONSE_DESCRIPTION = true
    SWAGGER_ENVIRONMENT_VARIABLE = 'SWAGGER'
  end
end
```
$ This file is optional and allows you to customize the behavior of the gem by providing additional options.

## Example
To generate Swagger YAML documentation for the APIs implemented in the EmployeesController class, you can follow these steps:
1) Ensure that you have the swagger_autogenerate gem installed and configured in your Rails application, as described later.
2) Create a spec file for the EmployeesController class at the path:
$ spec/your_path/employees_controller_spec.rb
This file should contain the test scenarios for each action (e.g., index, show, create) of the controller.

3) Run the spec code using the rspec command and set the environment variable SWAGGER to the desired YAML file name. For example:
```
SWAGGER='employee_apis.yaml' rspec spec/your_path/employees_controller_spec.rb
```
4) This command runs the spec file and instructs the swagger_autogenerate gem to generate Swagger YAML documentation and save it to the file named employee_apis.yaml.
5) Once the command finishes executing, you will have the Swagger YAML documentation generated based on the test scenarios in the employees_controller_spec.rb file.

### Please note 
that the generated documentation will depend on the test scenarios defined in your employees_controller_spec.rb  file. Make sure to have comprehensive test scenarios that cover  different scenarios and expected responses for accurate and detailed  Swagger documentation.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
