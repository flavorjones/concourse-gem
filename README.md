# Concourse

The `Concourse` gem creates rake tasks to help you manage your Concourse pipelines, and to assist in running individual tasks on your local development machine.

If you're not familiar with Concourse CI, you can read up on it at https://concourse.ci


## Usage

In your Rakefile,

``` ruby
require 'concourse'

Concourse.new("myproject").create_tasks!
```

This will create a set of rake tasks for you.


### Managing your Concourse pipeline

Tasks to manage a local pipeline file, generated from an ERB template:

```
rake concourse:clean                # remove generate pipeline file
rake concourse:generate             # generate and validate the pipeline file for myproject
```

A task to upload your pipeline file to the cloud:

```
rake concourse:set[fly_target]      # upload the pipeline file for myproject
```

Tasks to publicly expose or hide your pipeline:

```
rake concourse:expose[fly_target]   # expose the myproject pipeline
rake concourse:hide[fly_target]     # hide the myproject pipeline
```

Tasks to pause and unpause your pipeline:

```
rake concourse:pause[fly_target]    # pause the myproject pipeline
rake concourse:unpause[fly_target]  # unpause the myproject pipeline
```

### Running tasks with `fly execute`

```
rake concourse:tasks                                        # list all the available tasks from the nokogiri pipeline
rake concourse:task[fly_target,task_name,fly_execute_args]  # fly execute the specified task
```

where `fly_execute_args` will default to `--input=git-master=.`



### `fly_target`

The `fly_target` argument should be a fly target `name`, and the rake tasks assume that you're logged in already to that target.


### Templating and `RUBIES`

The ruby variable `RUBIES` is defined during the context of pipeline generation. The structure is something like:

``` ruby
  # these numbers/names align with public docker image names
  RUBIES = {
    mri:   %w[2.1 2.2 2.3 2.4], # docker repository: "ruby"
    jruby: %w[1.7 9.1],         # docker repository: "jruby"
    rbx:   %w[latest],          # docker repository: "rubinius/docker"
  }
```

and allows you to write your pipeline like this to get coverage on all the supported rubies:

``` yaml
# myproject.yaml.erb
jobs:
  <% for ruby_version in RUBIES[:mri] %>
  - name: "ruby-<%= ruby_version %>"
    plan:
      - get: git-master
        trigger: true
      - task: rake-test
    ...
  <% end %>
```


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'concourse'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install concourse


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/flavorjones/concourse-gem. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
