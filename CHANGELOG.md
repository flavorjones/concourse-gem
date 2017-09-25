# concourse-gem changelog

## 0.16.0 / 2017-09-24

Bugfix: require "tempfile", we've been relying on the class being implicitly loaded


## 0.15.0 / 2017-09-24

* Add awareness of Windows Rubies (implicitly linked with https://github.com/flavorjones/windows-ruby-dev-tools-release)


## 0.14.0 / 2017-04-23

* Removed badge functionality. IMHO: too complicated, not useful
* Restoring support for Ruby 1.9 (for JRuby 1.7), ugh.


## 0.13.0 / 2017-03-23

### Features

* allow setting of concourse directory name


## 0.12.0 / 2017-02-14

### Features

* rake task `concourse:init`

### Bug fixes

* properly require 'yaml'


## 0.11.0 / 2017-02-14

Stop using `myproject.yml.erb` and just interpret `myproject.yml` as an ERB template. @jtarchie was right. He's always right.


## 0.10.0 / 2017-02-08

Add `destroy` and `abort-builds` tasks.


## 0.9.0 / 2017-02-08

Bugfix: run `fly execute` with a clean Bundler environment, to avoid accidentally injecting our environment variables into the running task.


## 0.8.0 / 2017-02-08

Expose `#erbify` and `#markdown_badge` methods.


## 0.7.0 / 2017-02-08

Added a rake task to generate badges markdown.


## 0.6.{0,1} / 2017-01-26

If it exists, use `concourse/private.yml` to fill in template values.


## 0.5.0 / 2017-01-23

Renamed the `concourse:tasks` task name arg, and improved the README.


## 0.4.0 / 2017-01-22

Now uses the project name as the `fly execute` input resource name.


## 0.3.0 / 2017-01-22

Avoid depending on `rake/clean`


## 0.2.0 / 2017-01-22

Always regenerate pipeline file.


## 0.1.0 / 2017-01-22

First release.
