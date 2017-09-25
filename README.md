# Concourse

The `Concourse` gem provides rake tasks to help you manage your Concourse pipelines, and to assist in running individual tasks with `fly execute`.

If you're not familiar with Concourse CI, you can read up on it at https://concourse.ci


## Usage

In your Rakefile,

``` ruby
require 'concourse'

Concourse.new("myproject").create_tasks!
```

This will create a set of rake tasks for you.

``` sh
rake concourse:init
```

The `concourse:init` task will create a subdirectory named `concourse`, and create a Concourse pipeline file named `myproject.yml`, which will be interpreted as an ERB template. It will also ensure that files with sensitive data (`concourse/private.yml` and `concourse/myproject.final.yml`) are in `.gitignore`.


### Concourse subdirectory name

You can choose a directory name other than `concourse`:

``` ruby
Concourse.new("myproject", directory: "ci").create_tasks!
```


### Keeping credentials private

If the file `concourse/private.yml` exists, it will be passed to the `fly` commandline with the `-l` option to fill in template values.

For example, I might have a concourse config that looks like this:

``` yaml
  - name: nokogiri-pr
    type: pull-request
    source:
      repo: sparklemotion/nokogiri
      access_token: {{github-repo-status-access-token}}
      ignore_paths:
        - concourse/**
```

I can put my access token in `private.yml` like this:

``` yaml
github-repo-status-access-token: "your-token-here"
```

and the final generate template will substitute your credentials into the appropriate place.


### Templating and `RUBIES`

The ruby variable `RUBIES` is defined in the ERB binding during pipeline file generation. This variable looks like:

``` ruby
  # these numbers/names align with public docker image names
  RUBIES = {
    mri:     %w[2.1 2.2 2.3 2.4], # docker repository: "ruby"
    jruby:   %w[1.7 9.1],         # docker repository: "jruby"
    rbx:     %w[latest],          # docker repository: "rubinius/docker"
    windows: %w[2.3 2.4]          # windows-ruby-dev-tools-release
  }
```

and allows you to write a pipeline like this to get coverage on all the supported rubies:

``` yaml
# myproject.yml
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

Note that the `windows` rubies are not Docker images, since Concourse's Houdini backend doesn't use Docker. Instead, these are implicitly referring to the supported ruby versions installed by the BOSH release at https://github.com/flavorjones/windows-ruby-dev-tools-release


### `fly_target`

Any rake task that needs to interact with your Concourse ATC requires a `fly_target` argument. The value should be a fly target `name`, and it's assumed that you're already logged in to that target.


### Managing your Concourse pipeline

Tasks to manage a local pipeline file, generated from an ERB template:

```
rake concourse:clean                # remove generate pipeline file
rake concourse:generate             # generate and validate the pipeline file for myproject
```

A task to update your pipeline configuration:

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

And, should you ever need to [nuke the site from orbit][ripley], a task to destroy your pipeline:

```
rake concourse:destroy[fly_target]  # destroy the myproject pipeline
```


  [ripley]: https://www.youtube.com/watch?v=aCbfMkh940Q

### Running tasks with `fly execute`

```
rake concourse:tasks                                       # list all the available tasks from the nokogiri pipeline
rake concourse:task[fly_target,job_task,fly_execute_args]  # fly execute the specified task
```

where:

* _required_: `job_task` is formatted as `job-name/task-name`, for example, `ruby-2.4/rake-test`. Run the `concourse:tasks` rake task to see all available names.
* _optional_: `fly_execute_args` will default to map the project directory to a resource with the project name, e.g. `--input=myproject=.`, so your pipeline must name the input resource appropriately in order to use the default.


### Aborting running builds

```
rake concourse:abort-builds[fly_target]  # abort all running builds for this pipeline
```


### Generating a sweet set of markdown badges

Would you like a markdown table of your jobs' passing/failing badges? Of course you would.

```
rake concourse:badges[fly_target,team_name]   # display a list of jobs and badge urls
```

where:

* _optional_: `team_name` is the name of the pipeline's Concourse Team. Defaults to `main`.


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
