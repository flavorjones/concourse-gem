# concourse-gem changelog

## v0.29.0 / 2019-10-28

* add `2.7-rc` to the set of MRI Rubies


## v0.28.0 / 2019-08-06

* update the `concourse/concourse` docker image when a new docker-compose file is downloaded, to ensure the two stay in sync.


## v0.27.0 / 2019-04-28

### Features

* Provide description for the `concourse:local` rake task.
* `concourse:task` resolves private variables.


### Bug fixes

* Update error message for `concourse:task` task to match actual args.


## v0.26.0 / 2019-02-02

### Breaking changes

* Generated pipeline files are no longer `.gitignore`d.


## v0.25.0 / 2019-02-02

### Features

* Support running a local ephemeral Concourse cluster with `docker-compose`.


## v0.24.0 / 2019-01-24

### Features

* `$LOAD_PATH` includes the concourse directory, so that `require` will find relative filepaths.
* `erbify_file` method may be called to recursively include yaml erb templates.


### Breaking changes

* `#erbify` has been removed in favor of `#erbify_file`


## v0.23.0 / 2019-01-19

### Features

* Support for multiple pipelines.


## v0.22.0 / 2019-01-18

### Breaking changes

* The name of the generated, final pipeline file is now `<pipeline_erb_filename>.generated`.


### Features

* Introduce rake task `concourse:prune-stalled-workers`
* `Concourse.new` now takes an optional `:fly_target` named param to avoid passing this to each task. [#2] (Thanks, @ebmeierj!)
* `Concourse.new` now takes an optional `:pipeline_erb_filename` named param to set the name of the pipeline file used. [#1] (Thanks, @ebmeierj!)
* `Concourse.new` now takes an optional `:secrets_filename` named param to set the name of the private variable file used. [#1] (Thanks, @ebmeierj!)


## v0.21.0 / 2018-12-26

* Introduce ruby 2.6 final (and remove 2.6-rc)


## v0.20.0 / 2018-11-09

* Introduce ruby 2.6-rc
* Introduce helper methods `production_rubies` and `rc_rubies`


## v0.19.0 / 2018-09-15

Several version of Ruby have reached EOL and have been removed from `RUBIES`:

- ruby 2.1: https://www.ruby-lang.org/en/news/2017/04/01/support-of-ruby-2-1-has-ended/
- ruby 2.2: https://www.ruby-lang.org/en/news/2018/06/20/support-of-ruby-2-2-has-ended/
- jruby 1.7: https://github.com/jruby/jruby/issues/4112


## v0.18.0 / 2018-02-18

* Better default for `input` args to `concourse:task`: use the local directory for all the inputs. This matches the pattern where two different resources are used for ci scripts and the source under test.


## v0.17.0 / 2017-09-24

* Add support for Ruby 2.5 (in general and on Windows)
* Remove `fly` `-x` argument to work with Concourse 3.7.0+


## v0.16.0 / 2017-09-24

Bugfix: require "tempfile", we've been relying on the class being implicitly loaded


## v0.15.0 / 2017-09-24

* Add awareness of Windows Rubies (implicitly linked with https://github.com/flavorjones/windows-ruby-dev-tools-release)


## v0.14.0 / 2017-04-23

* Removed badge functionality. IMHO: too complicated, not useful
* Restoring support for Ruby 1.9 (for JRuby 1.7), ugh.


## v0.13.0 / 2017-03-23

### Features

* allow setting of concourse directory name


## v0.12.0 / 2017-02-14

### Features

* rake task `concourse:init`

### Bug fixes

* properly require 'yaml'


## v0.11.0 / 2017-02-14

Stop using `myproject.yml.erb` and just interpret `myproject.yml` as an ERB template. @jtarchie was right. He's always right.


## v0.10.0 / 2017-02-08

Add `destroy` and `abort-builds` tasks.


## v0.9.0 / 2017-02-08

Bugfix: run `fly execute` with a clean Bundler environment, to avoid accidentally injecting our environment variables into the running task.


## v0.8.0 / 2017-02-08

Expose `#erbify` and `#markdown_badge` methods.


## v0.7.0 / 2017-02-08

Added a rake task to generate badges markdown.


## v0.6.{0,1} / 2017-01-26

If it exists, use `concourse/private.yml` to fill in template values.


## v0.5.0 / 2017-01-23

Renamed the `concourse:tasks` task name arg, and improved the README.


## v0.4.0 / 2017-01-22

Now uses the project name as the `fly execute` input resource name.


## v0.3.0 / 2017-01-22

Avoid depending on `rake/clean`


## v0.2.0 / 2017-01-22

Always regenerate pipeline file.


## v0.1.0 / 2017-01-22

First release.
