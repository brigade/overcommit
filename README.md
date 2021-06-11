[![Gem Version](https://badge.fury.io/rb/overcommit.svg)](https://badge.fury.io/rb/overcommit)
[![Build Status](https://travis-ci.org/sds/overcommit.svg?branch=master)](https://travis-ci.org/sds/overcommit)
[![Windows Build Status](https://ci.appveyor.com/api/projects/status/umui038jlm597ryf?svg=true)](https://ci.appveyor.com/project/sds/overcommit)
[![Coverage Status](https://coveralls.io/repos/github/sds/overcommit/badge.svg?branch=master)](https://coveralls.io/github/sds/overcommit?branch=master)
[![Maintainability](https://api.codeclimate.com/v1/badges/5da42f7f365e5fef6b4c/maintainability)](https://codeclimate.com/github/sds/overcommit/maintainability)
[![Inline docs](http://inch-ci.org/github/sds/overcommit.svg?branch=master)](http://inch-ci.org/github/sds/overcommit)

<p align="center">
  <img src="https://raw.githubusercontent.com/sds/overcommit/master/logo/horizontal.png" width="65%" alt="Overcommit Logo"/>
</p>

`overcommit` is a tool to manage and configure
[Git hooks](http://git-scm.com/book/en/Customizing-Git-Git-Hooks).

In addition to supporting a wide variety of hooks that can be used across
multiple repositories, you can also define hooks specific to a repository which
are stored in source control. You can also easily
[add your existing hook scripts](#adding-existing-git-hooks) without writing
any Ruby code.

* [Requirements](#requirements)
  * [Dependencies](#dependencies)
* [Installation](#installation)
  * [Automatically Install Overcommit Hooks](#automatically-install-overcommit-hooks)
* [Usage](#usage)
* [Continuous Integration](#continuous-integration)
* [Configuration](#configuration)
  * [Hook Options](#hook-options)
  * [Hook Categories](#hook-categories)
  * [Gemfile](#gemfile)
  * [Plugin Directory](#plugin-directory)
  * [Signature Verification](#signature-verification)
* [Built-In Hooks](#built-in-hooks)
  * [CommitMsg](#commitmsg)
  * [PostCheckout](#postcheckout)
  * [PostCommit](#postcommit)
  * [PostMerge](#postmerge)
  * [PostRewrite](#postrewrite)
  * [PreCommit](#precommit)
  * [PrePush](#prepush)
  * [PreRebase](#prerebase)
* [Repo-Specific Hooks](#repo-specific-hooks)
  * [Adding Existing Git Hooks](#adding-existing-git-hooks)
* [Security](#security)
* [Contributing](#contributing)
* [Community](#community)
* [Changelog](#changelog)
* [License](#license)

## Requirements

This project aims to support the following Ruby runtimes on both \*nix and Windows:

* Ruby 2.4+

### Windows

If you are using Overcommit on **Windows**, make sure you include the `ffi` gem in your
list of dependencies. Overcommit does not include the `ffi` gem by default since it
significantly increases the install time for non-Windows platforms.

### Dependencies

Some hooks have third-party dependencies. For example, to lint your
[SCSS](http://sass-lang.com/) files, you're going to need the
[scss_lint gem](https://github.com/sds/scss-lint).

Depending on the hooks you enable/disable for your repository, you'll need to
ensure your development environment already has those dependencies installed.
Most hooks will display a warning if a required executable isn't available.

If you are using Bundler to manage your Ruby gem dependencies, you'll likely
want to use the [`gemfile`](#gemfile) option to control which gem versions are
available during your hook runs.

## Installation

`overcommit` is installed via [RubyGems](https://rubygems.org/). It is strongly
recommended that your environment support running `gem install` without
requiring root user privileges via `sudo` or otherwise. Using a Ruby version
manager like [`rbenv`](https://github.com/rbenv/rbenv/) or
[`rvm`](https://rvm.io/) is recommended.

Once you have an environment that allows you to install gems without `sudo`,
run:

```bash
gem install overcommit
```

You can then run the `overcommit` command to install hooks into repositories.

```bash
mkdir important-project
cd important-project
git init
overcommit --install
```

After running `overcommit --install`, any existing hooks for your repository
which Overcommit will replace will be backed up. You can restore everything to
the way it was by running `overcommit --uninstall`.

### Automatically Install Overcommit Hooks

If you want to use `overcommit` for all repositories you create/clone going
forward, add the following to automatically run in your shell environment:

```bash
export GIT_TEMPLATE_DIR="$(overcommit --template-dir)"
```

The `GIT_TEMPLATE_DIR` provides a directory for Git to use as a template
for automatically populating the `.git` directory. If you have your own
template directory, you might just want to copy the contents of
`overcommit --template-dir` to that directory.

## Usage

Once you've installed the hooks via `overcommit --install`, they will
automatically run when the appropriate hook is triggered.

The `overcommit` executable supports the following command-line flags:

Command Line Flag         | Description
--------------------------|----------------------------------------------------
`-i`/`--install`          | Install Overcommit hooks in a repository
`-u`/`--uninstall`        | Remove Overcommit hooks from a repository
`-f`/`--force`            | Don't bail on install if other hooks already exist--overwrite them
`-l`/`--list-hooks`       | Display all available hooks in the current repository
`-r`/`--run`              | Run pre-commit hook against all tracked files in repository
`-t`/`--template-dir`     | Print location of template directory
`-h`/`--help`             | Show command-line flag documentation
`-v`/`--version`          | Show version

### Skipping Hooks

Sometimes a hook will report an error that for one reason or another you'll want
to ignore. To prevent these errors from blocking your commit, you can include
the name of the relevant hook in the `SKIP` environment variable, e.g.

```bash
SKIP=RuboCop git commit
```

If you would prefer to specify a whitelist of hooks rather than a blacklist, use
the `ONLY` environment variable instead.

```bash
ONLY=RuboCop git commit
```

Use this feature sparingly, as there is no point to having the hook in the first
place if you're just going to ignore it. If you want to ensure a hook is never
skipped, set the `required` option to `true` in its configuration. If you
attempt to skip it, you'll see a warning telling you that the hook is required,
and the hook will still run.

### Disabling Overcommit

If you have scripts that execute `git` commands where you don't want Overcommit
hooks to run, you can disable Overcommit entirely by setting the
`OVERCOMMIT_DISABLE` environment variable.

```bash
OVERCOMMIT_DISABLE=1 ./my-custom-script
```

### Disabling Colorized Output

Overcommit automatically colorizes its output based on whether it is outputting
to a TTY. However, you can manually enable/disable color by setting the
`OVERCOMMIT_COLOR` environment variable.

```bash
OVERCOMMIT_COLOR=0 git commit
```

## Continuous Integration

You can run the same set of hooks that would be executed in a pre-commit hook
against your entire repository by running `overcommit --run`. This makes it
easy to have the checks verified by a CI service such as
[Travis CI](https://travis-ci.com/), including custom hooks you've written
yourself.

The `--run` flag works by creating a pre-commit context that assumes _all_ the
files in your repository have changed, and follows the same rules as a normal
pre-commit check. If any hook fails with an error, it will return a non-zero
exit code.

## Configuration

Overcommit provides a flexible configuration system that allows you to tailor
the built-in hooks to suit your workflow. All configuration specific to a
repository is stored in `.overcommit.yml` in the top-level directory of the
repository.

When writing your own configuration, it will automatically extend the
[default configuration](config/default.yml), so you only need to specify
your configuration with respect to the default. In order to
enable/disable hooks, you can add the following to your repo-specific
configuration file:

```yaml
PreCommit:
  RuboCop:
    enabled: true
    command: ['bundle', 'exec', 'rubocop'] # Invoke within Bundler context
```

### Hook Options

Individual hooks expose both built-in configuration options as well as their
own custom options unique to each hook. The following table lists all built-in
configuration options:

Option                                  | Description
----------------------------------------|--------------------------------------
`enabled`                               | If `false`, this hook will never be run
`required`                              | If `true`, this hook cannot be skipped via the `SKIP` environment variable
`quiet`                                 | If `true`, this hook does not display any output unless it warns/fails
`description`                           | Message displayed while hook is running.
`requires_files`                        | If `true`, this hook runs only if files that are applicable to it have been modified. See `include` and `exclude` for how to specify applicable files.
`include`                               | File paths or glob patterns of files that apply to this hook. The hook will only run on the applicable files when they have been modified. Note that the concept of modified varies for different types of hooks. By default, `include` matches every file until you specify a list of patterns.
`exclude`                               | File paths or glob patterns of files that do not apply to this hook. This is used to exclude any files that would have been matched by `include`.
`exclude_branches`                      | List of branch names or glob patterns of branches that this hook should not run against.
`exclude_remotes`                       | *`PrePush` hooks only.* List of remote names that the hook should not run against.
`include_remote_ref_deletions`          | *`PrePush` hooks only.* By default, `PrePush` hooks will **not** run for pushes that delete a remote ref (i.e. branches or tags). Set to `true` to have the hook run even for deleted remote ref.
`problem_on_unmodified_line`            | How to treat errors reported on lines that weren't modified during the action captured by this hook (e.g. for pre-commit hooks, warnings/errors reported on lines that were not staged with `git add` may not be warnings/errors you care about). Valid values are `report`: report errors/warnings as-is regardless of line location (default); `warn`: report errors as warnings if they are on lines you didn't modify; and `ignore`: don't display errors/warnings at all if they are on lines you didn't modify (`ignore` is _not_ recommended).
`on_fail`                               | Change the status of a failed hook to `warn` or `pass`. This allows you to treat failures as warnings or potentially ignore them entirely, but you should use caution when doing so as you might be hiding important information.
`on_warn`                               | Similar to `on_fail`, change the status of a hook that returns a warning status to either `pass` (you wish to silence warnings entirely) or `fail` (you wish to treat all warnings as errors).
`required_executable`                   | Name of an executable that must exist in order for the hook to run. If this is a path (e.g. `./bin/ruby`), ensures that the executable file exists at the given location relative to the repository root. Otherwise, if it just the name of an executable (e.g. `ruby`) checks if the executable can be found in one of the directories in the `PATH` environment variable. Set this to a specific path if you want to always use an executable that is stored in your repository. (e.g. RubyGems bin stubs, Node.js binaries, etc.)
`required_library`/`required_libraries` | List of Ruby libraries to load with `Kernel.require` before the hook runs. This is specifically for hooks that integrate with external Ruby libraries.
`command`                               | Array of arguments to use as the command. How each hook uses this is different, but it allows hooks to change the context with which they run. For example, you can change the command to be `['bundle', 'exec', 'rubocop']` instead of just `rubocop` so that you can use the gem versions specified in your local `Gemfile.lock`. This defaults to the name of the `required_executable`.
`flags`                                 | Array of arguments to append to the `command`. This is useful for customizing the behavior of a tool. It's also useful when a newer version of a tool removes/renames existing flags, so you can update the flags via your `.overcommit.yml` instead of waiting for an upstream fix in Overcommit.
`env`                                   | Hash of environment variables the hook should be run with. This is intended to be used as a last resort when an executable a hook runs is configured only via an environment variable. Any pre-existing environment variables with the same names as ones defined in `env` will have their original values restored after the hook runs. **NOTE:** Currently, only strings are accepted values. Boolean values will raise an error. **WARNING**: If you set the same environment variable for multiple hooks and you've enabled parallel hook runs, since the environment is shared across all threads you could accidentally have these separate hooks trample on each other. In this case, you should disable parallelization for the hook using the `parallelize` option.
`parallelize`                           | Whether to allow this hook to be run concurrently with other hooks. Disable this if the hook requires access to a shared resource that other hooks may also access and modify (e.g. files, the git index, process environment variables, etc).
`processors`                            | The number of processing units to reserve for this hook. This does not reserve CPUs, but indicates that out of the total number of possible concurrent hooks allowed by the global `concurrency` option, this hook requires the specified number. Thus in the typical case where `concurrency` is set to the number of available cores (default), and you have a hook that executes an application which itself creates 2 threads (or is otherwise scheduled on 2 cores), you can indicate that Overcommit should allocate 2 `processors` to the hook. Ideally this means your hooks won't put undue load on your available cores.
`install_command`                       | Command the user can run to install the `required_executable` (or alternately the specified `required_libraries`). This is intended for documentation purposes, as Overcommit does not install software on your behalf since there are too many edge cases where such behavior would result in incorrectly configured installations (e.g. installing a Python package in the global package space instead of in a virtual environment).
`skip_file_checkout`                    | Whether to skip this hook for file checkouts (e.g. `git checkout some-ref -- file`). Only applicable to `PostCheckout` hooks.
`skip_if`                               | Array of arguments to be executed to determine whether or not the hook should run. For example, setting this to a value of `['bash', '-c', '! which my-executable']` would allow you to skip running this hook if `my-executable` was not in the bin path.
`ad_hoc`                                | *["Ad-hoc" line-aware command hooks](#adding-existing-line-aware-commands) only.*

In addition to the built-in configuration options, each hook can expose its
own unique configuration options. The `AuthorEmail` hook, for example, allows
you to customize the regex used to check commit author emails via the `pattern`
option&mdash;useful if you want to enforce that developers use a company
email address for their commits. This provides incredible flexibility for hook
authors as you can make your hooks sufficiently generic and then customize them
on a per-project basis.

### Hook Categories

Hook configurations are organized into categories based on the type of hook. So
`pre-commit` hooks are located under the `PreCommit` option, and `post-commit`
hooks are located under `PostCommit`. See the
[default configuration](config/default.yml) for a thorough example.

#### The `ALL` Hook

Within a hook category, there is a special type of hook configuration that
applies to _all_ hooks in the category. This configuration looks like a normal
hook configuration, except it has the name `ALL`:

```yaml
PreCommit:
  ALL:
    problem_on_unmodified_line: warn
    requires_files: true
    required: false
    quiet: false

  SomeHook:
    enabled: true

  ...
```

The `ALL` configuration is useful for when you want to
[DRY](http://en.wikipedia.org/wiki/Don%27t_repeat_yourself) up your
configuration, or when you want to apply changes across an entire category of
hooks.

Note that array configuration options (like `include`/`exclude`) in the
special `ALL` hook section are not merged with individual hook configurations
if custom ones are defined for the hook.
Any custom configuration option for `include`/`exclude` will replace the `ALL`
hook's configuration. If you want to have a global list of default exclusions
and extend them with a custom list, you can use YAML references, e.g.

```yaml
PreCommit:
  ALL:
    exclude: &default_excludes
      - 'node_modules/**/*'
      - 'vendor/**/*'
  MyHook:
    exclude:
      - *default_excludes
      - 'another/directory/in/addition/to/default/excludes/**/*'
```

Again, you can consult the [default configuration](config/default.yml) for
detailed examples of how the `ALL` hook can be used.

### Gemfile

You may want to enforce the version of Overcommit or other gems that you use in
your git hooks. This can be done by specifying the `gemfile` option in your
`.overcommit.yml`.

The `gemfile` option tells Overcommit to load the specified file with
[Bundler](http://bundler.io/), the standard gem dependency manager for Ruby.
This is useful if you would like to:

  - Enforce a specific version of Overcommit to use for all hook runs
    (or to use a version from the master branch that has not been released yet)
  - Enforce a specific version or unreleased branch is used for a gem you want
    to use in your git hooks

Loading a Bundler context necessarily adds a startup delay to your hook runs
as Bundler parses the specified `Gemfile` and checks that the dependencies are
satisfied. Thus for projects with many gems this can introduce a noticeable
delay.

The recommended workaround is to create a separate `Gemfile` in the root of
your repository (call it `.overcommit_gems.rb`), and include only the gems that
your Overcommit hooks need in order to run. Generate the associated lock file
by running:

```bash
bundle install --gemfile=.overcommit_gems.rb
```

...and commit `.overcommit_gems.rb` and the resulting
`.overcommit_gems.rb.lock` file to your repository. Set your `gemfile` option
to `.overcommit_gems.rb`, and you're all set.

Using a smaller Gemfile containing only the gems used by your Overcommit hooks
significantly reduces the startup delay in your hook runs. It is thus the
recommended approach unless your project has a relatively small number of gems
in your `Gemfile`.

### Plugin Directory

You can change the directory that project-specific hooks are loaded from via
the `plugin_directory` option. The default directory is `.git-hooks`.

### Quiet Hook Runs

If you prefer to have your hooks be completely silent unless there is a
problem, you can set the top-level `quiet` option to `true`. Note that if you
have many hooks or slow hooks this may not be desirable, as you don't get
visual feedback indicating the general progress of the hook run.

### Concurrency

Overcommit runs hooks in parallel by default, with a number of concurrent
workers equal to the number of logical cores on your machine. If you know your
particular set of hooks would benefit from higher/lower number of workers, you
can adjust the global `concurrency` option. You can define single-operator
mathematical expressions, e.g. `%{processors} * 2`, or `%{processors} / 2`.

```yaml
concurrency: '%{processors} / 4'
```

Note that individual hooks can specify the number of processors they require
with the `processors` hook option. See the [hook options](#hook-options)
section for more details.

### Signature Verification

You can disable manual verification of signatures by setting
`verify_signatures` to `false`. See the [Security](#security) section for more
information on this option and what exactly it controls.

## Built-In Hooks

Currently, Overcommit supports the following hooks out of the box&mdash;simply
enable them in your `.overcommit.yml`.

**Note**: Hooks with a `*` are enabled by default.

**Warning**: This list represents the list of hooks available on the `master`
branch. Please consult the [change log](CHANGELOG.md) to view which hooks have
not been released yet.

### CommitMsg

`commit-msg` hooks are run against every commit message you write before a
commit is created. A failed hook prevents a commit from being created. These
hooks are useful for enforcing policies on your commit messages, e.g. ensuring
a task ID is included for tracking purposes, or ensuring your commit messages
follow [proper formatting guidelines](http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html).

* [`*`CapitalizedSubject](lib/overcommit/hook/commit_msg/capitalized_subject.rb)
* [`*`EmptyMessage](lib/overcommit/hook/commit_msg/empty_message.rb)
* [GerritChangeId](lib/overcommit/hook/commit_msg/gerrit_change_id.rb)
* [HardTabs](lib/overcommit/hook/commit_msg/hard_tabs.rb)
* [MessageFormat](lib/overcommit/hook/commit_msg/message_format.rb)
* [RussianNovel](lib/overcommit/hook/commit_msg/russian_novel.rb)
* [`*`SingleLineSubject](lib/overcommit/hook/commit_msg/single_line_subject.rb)
* [SpellCheck](lib/overcommit/hook/commit_msg/spell_check.rb)
* [`*`TextWidth](lib/overcommit/hook/commit_msg/text_width.rb)
* [`*`TrailingPeriod](lib/overcommit/hook/commit_msg/trailing_period.rb)

### PostCheckout

`post-checkout` hooks run after a successful `git checkout`, or in other words
any time your `HEAD` changes or a file is explicitly checked out.

* [BowerInstall](lib/overcommit/hook/post_checkout/bower_install.rb)
* [BundleInstall](lib/overcommit/hook/post_checkout/bundle_install.rb)
* [ComposerInstall](lib/overcommit/hook/post_checkout/composer_install.rb)
* [IndexTags](lib/overcommit/hook/post_checkout/index_tags.rb)
* [NpmInstall](lib/overcommit/hook/post_checkout/npm_install.rb)
* [SubmoduleStatus](lib/overcommit/hook/post_checkout/submodule_status.rb)
* [YarnInstall](lib/overcommit/hook/post_checkout/yarn_install.rb)

### PostCommit

`post-commit` hooks run after a commit is successfully created. A hook failing
in this case does not prevent the commit since it has already occurred;
however, it can be used to alert the user to some issue.

* [BowerInstall](lib/overcommit/hook/post_commit/bower_install.rb)
* [BundleInstall](lib/overcommit/hook/post_commit/bundle_install.rb)
* [Commitplease](lib/overcommit/hook/post_commit/commitplease.rb)
* [ComposerInstall](lib/overcommit/hook/post_commit/composer_install.rb)
* [GitGuilt](lib/overcommit/hook/post_commit/git_guilt.rb)
* [IndexTags](lib/overcommit/hook/post_commit/index_tags.rb)
* [NpmInstall](lib/overcommit/hook/post_commit/npm_install.rb)
* [SubmoduleStatus](lib/overcommit/hook/post_commit/submodule_status.rb)
* [YarnInstall](lib/overcommit/hook/post_commit/yarn_install.rb)

### PostMerge

`post-merge` hooks run after a `git merge` executes successfully with no merge
conflicts. A hook failing in this case does not prevent the merge since it has
already occurred; however, it can be used to alert the user to some issue.

* [BowerInstall](lib/overcommit/hook/post_merge/bower_install.rb)
* [BundleInstall](lib/overcommit/hook/post_merge/bundle_install.rb)
* [ComposerInstall](lib/overcommit/hook/post_merge/composer_install.rb)
* [IndexTags](lib/overcommit/hook/post_merge/index_tags.rb)
* [NpmInstall](lib/overcommit/hook/post_merge/npm_install.rb)
* [SubmoduleStatus](lib/overcommit/hook/post_merge/submodule_status.rb)
* [YarnInstall](lib/overcommit/hook/post_merge/yarn_install.rb)

### PostRewrite

`post-rewrite` hooks run after a commit is modified by a `git commit --amend`
or `git rebase`. A hook failing in this case does not prevent the rewrite since
it has already occurred; however, it can be used to alert the user to some
issue.

* [BowerInstall](lib/overcommit/hook/post_rewrite/bower_install.rb)
* [BundleInstall](lib/overcommit/hook/post_rewrite/bundle_install.rb)
* [ComposerInstall](lib/overcommit/hook/post_rewrite/composer_install.rb)
* [IndexTags](lib/overcommit/hook/post_rewrite/index_tags.rb)
* [NpmInstall](lib/overcommit/hook/post_rewrite/npm_install.rb)
* [SubmoduleStatus](lib/overcommit/hook/post_rewrite/submodule_status.rb)
* [YarnInstall](lib/overcommit/hook/post_rewrite/yarn_install.rb)

### PreCommit

`pre-commit` hooks are run after `git commit` is executed, but before the
commit message editor is displayed. If a hook fails, the commit will not be
created. These hooks are ideal for syntax checkers, linters, and other checks
that you want to run before you allow a commit to even be created.

#### WARNING: pre-commit hooks cannot have side effects

`pre-commit` hooks currently do not support hooks with side effects (such as
modifying files and adding them to the index with `git add`). This is a
consequence of Overcommit's pre-commit hook stashing behavior to ensure hooks
are run against _only the changes you are about to commit_.

Without Overcommit, the proper way to write a `pre-commit` hook would be to
extract the staged changes into temporary files and lint those files
instead of whatever contents are in your working tree (as you don't want
unstaged changes to taint your results). Overcommit takes care
of this for you, but to do it in a generalized way introduces this
limitation. See the [thread tracking this
issue](https://github.com/sds/overcommit/issues/238) for more details.

* [`*`AuthorEmail](lib/overcommit/hook/pre_commit/author_email.rb)
* [`*`AuthorName](lib/overcommit/hook/pre_commit/author_name.rb)
* [BerksfileCheck](lib/overcommit/hook/pre_commit/berksfile_check.rb)
* [`*`BrokenSymlinks](lib/overcommit/hook/pre_commit/broken_symlinks.rb)
* [BundleAudit](lib/overcommit/hook/pre_commit/bundle_audit.rb)
* [BundleCheck](lib/overcommit/hook/pre_commit/bundle_check.rb)
* [BundleOutdated](lib/overcommit/hook/pre_commit/bundle_outdated.rb)
* [`*`CaseConflicts](lib/overcommit/hook/pre_commit/case_conflicts.rb)
* [ChamberSecurity](lib/overcommit/hook/pre_commit/chamber_security.rb)
* [CodeSpellCheck](lib/overcommit/hook/pre_commit/code_spell_check.rb)
* [CoffeeLint](lib/overcommit/hook/pre_commit/coffee_lint.rb)
* [Credo](lib/overcommit/hook/pre_commit/credo.rb)
* [CssLint](lib/overcommit/hook/pre_commit/css_lint.rb)
* [DartAnalyzer](lib/overcommit/hook/pre_commit/dart_analyzer.rb)
* [Dogma](lib/overcommit/hook/pre_commit/dogma.rb)
* [ErbLint](lib/overcommit/hook/pre_commit/erb_lint.rb)
* [EsLint](lib/overcommit/hook/pre_commit/es_lint.rb)
* [ExecutePermissions](lib/overcommit/hook/pre_commit/execute_permissions.rb)
* [Fasterer](lib/overcommit/hook/pre_commit/fasterer.rb)
* [FileSize](lib/overcommit/hook/pre_commit/file_size.rb)
* [FixMe](lib/overcommit/hook/pre_commit/fix_me.rb)
* [Flay](lib/overcommit/hook/pre_commit/flay.rb)
* [Foodcritic](lib/overcommit/hook/pre_commit/foodcritic.rb)
* [ForbiddenBranches](lib/overcommit/hook/pre_commit/forbidden_branches.rb)
* [GoLint](lib/overcommit/hook/pre_commit/go_lint.rb)
* [GoVet](lib/overcommit/hook/pre_commit/go_vet.rb)
* [Hadolint](lib/overcommit/hook/pre_commit/hadolint.rb)
* [LicenseFinder](lib/overcommit/hook/pre_commit/license_finder.rb)
* [HamlLint](lib/overcommit/hook/pre_commit/haml_lint.rb)
* [HardTabs](lib/overcommit/hook/pre_commit/hard_tabs.rb)
* [Hlint](lib/overcommit/hook/pre_commit/hlint.rb)
* [HtmlHint](lib/overcommit/hook/pre_commit/html_hint.rb)
* [HtmlTidy](lib/overcommit/hook/pre_commit/html_tidy.rb)
* [ImageOptim](lib/overcommit/hook/pre_commit/image_optim.rb)
* [JavaCheckstyle](lib/overcommit/hook/pre_commit/java_checkstyle.rb)
* [Jscs](lib/overcommit/hook/pre_commit/jscs.rb)
* [JsHint](lib/overcommit/hook/pre_commit/js_hint.rb)
* [JsLint](lib/overcommit/hook/pre_commit/js_lint.rb)
* [Jsl](lib/overcommit/hook/pre_commit/jsl.rb)
* [JsonSyntax](lib/overcommit/hook/pre_commit/json_syntax.rb)
* [KtLint](lib/overcommit/hook/pre_commit/kt_lint.rb)
* [LicenseHeader](lib/overcommit/hook/pre_commit/license_header.rb)
* [LineEndings](lib/overcommit/hook/pre_commit/line_endings.rb)
* [LocalPathsInGemfile](lib/overcommit/hook/pre_commit/local_paths_in_gemfile.rb)
* [Mdl](lib/overcommit/hook/pre_commit/mdl.rb)
* [`*`MergeConflicts](lib/overcommit/hook/pre_commit/merge_conflicts.rb)
* [NginxTest](lib/overcommit/hook/pre_commit/nginx_test.rb)
* [PhpCs](lib/overcommit/hook/pre_commit/php_cs.rb)
* [PhpCsFixer](lib/overcommit/hook/pre_commit/php_cs_fixer.rb)
* [PhpLint](lib/overcommit/hook/pre_commit/php_lint.rb)
* [PhpStan](lib/overcommit/hook/pre_commit/php_stan.rb)
* [Pronto](lib/overcommit/hook/pre_commit/pronto.rb)
* [PuppetLint](lib/overcommit/hook/pre_commit/puppet_lint.rb)
* [PuppetMetadataJsonLint](lib/overcommit/hook/pre_commit/puppet_metadata_json_lint.rb)
* [Pycodestyle](lib/overcommit/hook/pre_commit/pycodestyle.rb)
* [Pydocstyle](lib/overcommit/hook/pre_commit/pydocstyle.rb)
* [Pyflakes](lib/overcommit/hook/pre_commit/pyflakes.rb)
* [Pylint](lib/overcommit/hook/pre_commit/pylint.rb)
* [PythonFlake8](lib/overcommit/hook/pre_commit/python_flake8.rb)
* [RakeTarget](lib/overcommit/hook/pre_commit/rake_target.rb)
* [RailsBestPractices](lib/overcommit/hook/pre_commit/rails_best_practices.rb)
* [RailsSchemaUpToDate](lib/overcommit/hook/pre_commit/rails_schema_up_to_date.rb)
* [Reek](lib/overcommit/hook/pre_commit/reek.rb)
* [RuboCop](lib/overcommit/hook/pre_commit/rubo_cop.rb)
* [RubyLint](lib/overcommit/hook/pre_commit/ruby_lint.rb)
* [RubySyntax](lib/overcommit/hook/pre_commit/ruby_syntax.rb)
* [SwiftLint](lib/overcommit/hook/pre_commit/swift_lint.rb)
* [Scalariform](lib/overcommit/hook/pre_commit/scalariform.rb)
* [Scalastyle](lib/overcommit/hook/pre_commit/scalastyle.rb)
* [ScssLint](lib/overcommit/hook/pre_commit/scss_lint.rb)
* [SemiStandard](lib/overcommit/hook/pre_commit/semi_standard.rb)
* [ShellCheck](lib/overcommit/hook/pre_commit/shell_check.rb)
* [SlimLint](lib/overcommit/hook/pre_commit/slim_lint.rb)
* [Sqlint](lib/overcommit/hook/pre_commit/sqlint.rb)
* [Standard](lib/overcommit/hook/pre_commit/standard.rb)
* [Stylelint](lib/overcommit/hook/pre_commit/stylelint.rb)
* [TrailingWhitespace](lib/overcommit/hook/pre_commit/trailing_whitespace.rb)
* [TravisLint](lib/overcommit/hook/pre_commit/travis_lint.rb)
* [TsLint](lib/overcommit/hook/pre_commit/ts_lint.rb)
* [Vint](lib/overcommit/hook/pre_commit/vint.rb)
* [W3cCss](lib/overcommit/hook/pre_commit/w3c_css.rb)
* [W3cHtml](lib/overcommit/hook/pre_commit/w3c_html.rb)
* [XmlLint](lib/overcommit/hook/pre_commit/xml_lint.rb)
* [XmlSyntax](lib/overcommit/hook/pre_commit/xml_syntax.rb)
* [YamlLint](lib/overcommit/hook/pre_commit/yaml_lint.rb)
* [YamlSyntax](lib/overcommit/hook/pre_commit/yaml_syntax.rb)
* [YardCoverage](lib/overcommit/hook/pre_commit/yard_coverage.rb)
* [YarnCheck](lib/overcommit/hook/pre_commit/yarn_check.rb)

### PrePush

`pre-push` hooks are run during `git push`, after remote refs have been updated
but before any objects have been transferred. If a hook fails, the push is
aborted.

* [Brakeman](lib/overcommit/hook/pre_push/brakeman.rb)
* [FlutterTest](lib/overcommit/hook/pre_push/flutter_test.rb)
* [Minitest](lib/overcommit/hook/pre_push/minitest.rb)
* [PhpUnit](lib/overcommit/hook/pre_push/php_unit.rb)
* [Pronto](lib/overcommit/hook/pre_push/pronto.rb)
* [ProtectedBranches](lib/overcommit/hook/pre_push/protected_branches.rb)
* [PubTest](lib/overcommit/hook/pre_push/pub_test.rb)
* [Pytest](lib/overcommit/hook/pre_push/pytest.rb)
* [PythonNose](lib/overcommit/hook/pre_push/python_nose.rb)
* [RakeTarget](lib/overcommit/hook/pre_push/rake_target.rb)
* [RSpec](lib/overcommit/hook/pre_push/r_spec.rb)
* [TestUnit](lib/overcommit/hook/pre_push/test_unit.rb)

### PreRebase

`pre-rebase` hooks are run during `git rebase`, before any commits are rebased.
If a hook fails, the rebase is aborted.

* [MergedCommits](lib/overcommit/hook/pre_rebase/merged_commits.rb)

## Repo-Specific hooks

Out of the box, `overcommit` comes with a set of hooks that enforce a variety of
styles and lints. However, some hooks only make sense in the context of a
specific repository.

For example, you can have a number of simple checks that run
against your code to catch common errors. For example, if you use
[RSpec](http://rspec.info/), you can make sure all spec files contain the
line `require 'spec_helper'`.

Inside our repository, we can add the file
`.git-hooks/pre_commit/ensure_spec_helper.rb` in order to automatically check
our spec files:

```ruby
module Overcommit::Hook::PreCommit
  class EnsureSpecHelper < Base
    def run
      errors = []

      applicable_files.each do |file|
        if File.read(file) !~ /^require 'spec_helper'/
          errors << "#{file}: missing `require 'spec_helper'`"
        end
      end

      return :fail, errors.join("\n") if errors.any?

      :pass
    end
  end
end
```

The corresponding configuration for this hook would look like:

```yaml
PreCommit:
  EnsureSpecHelper:
    enabled: true
    description: 'Checking for missing inclusion of spec_helper'
    include: '**/*_spec.rb'
```

### Adding Existing Git Hooks

You might already have hook scripts written which you'd like to integrate with
Overcommit right away. To make this easy, Overcommit allows you to include
your hook script in your configuration without writing any Ruby code.
For example:

```yaml
PostCheckout:
  CustomScript:
    enabled: true
    required_executable: './bin/custom-script'
```

So long as a command is given (either by specifying the `command` option
directly or specifying `required_executable`) a special hook is created that
executes the command and appends any arguments and standard input stream that
would have been passed to the regular hook. The hook passes or fails based
on the exit status of the command.

The script is executed as if Git were calling the hook directly. If you want
to understand which arguments are passed to the script depending on the type
of hook, see the [git-hooks documentation][GHD].

[GHD]: https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks

### Adding Existing Line-Aware Commands

Or in other words "low-code error format support."

If you use tools that analyze files and report their findings line-by-line,
and that Overcommit does not yet support, you may be able to integrate them
with Overcommit without writing any Ruby code in a similar way as
[for existing Git hooks](#adding-existing-git-hooks).

These special line-aware command hooks behave and are configured the same way
as the Git ones, except only file arguments get passed to them.
Also they must have the `ad_hoc` option, so that, using the command output:
- differentiating between warnings and errors becomes possible
- modified lines can be detected and acted upon as defined by
  the `problem_on_unmodified_line`, `requires_files`, `include` and `exclude`
  [hook options](#hook-options)

**Warning**: Only the command's standard output stream is considered for now,
*not* its standard error stream.

To differentiate between warning and error messages,
the `warning_message_type_pattern` suboption may be specified:
the `type` field of the `message_pattern` regexp below must then include
the `warning_message_type_pattern` option's text.

The `message_pattern` suboption specifies the format of the command's messages.
It is a optional [(Ruby) regexp][RubyRE], which if present must at least define
a `file` [named capture group][RubyRENCG].
The only other allowed ones are `line` and `type`, which when specified
enable detection of modified lines and warnings respectively.

**Note**: The default value for this option is often adequate:
it generalizes the quasi-standard [GNU/Emacs-style error format][GNUEerrf],
adding the most frequently used warning syntax to it.

For example:

```yaml
PreCommit:
  CustomScript:
    enabled: true
    command: './bin/custom-script'
    ad_hoc:
      message_pattern: !ruby/regexp /^(?<file>[^:]+):(?<line>[0-9]+):(?<type>[^ ]+)/
      warning_message_type_pattern: warning
```

**Tip**: To get the syntax of the regexps right, a Ruby interpreter like `irb`
can help:

```ruby
require('yaml'); puts YAML.dump(/MY-REGEXP/)
```

Then copy the output line text as the YAML option's value, thereby
omitting the `---` prefix.

[RubyRE]: https://ruby-doc.org/core-2.4.1/Regexp.html
[RubyRENCG]: https://ruby-doc.org/core-2.4.1/Regexp.html#class-Regexp-label-Capturing
[GNUEerrf]: https://www.gnu.org/prep/standards/standards.html#Errors

## Security

While Overcommit can make managing Git hooks easier and more convenient,
this convenience can come at a cost of being less secure.

Since installing Overcommit hooks will allow arbitrary plugin code in your
repository to be executed, you expose yourself to an attack where checking
out code from a third party can result in malicious code being executed
on your system.

As an example, consider the situation where you have an open source project.
An attacker could submit a pull request which adds a `post-checkout` hook
that executes some malicious code. When you fetch and checkout this pull
request, the `post-checkout` hook will be run on your machine, along with
the malicious code that you just checked out.

Overcommit attempts to address this problem by storing a signature of your
configuration and all hook plugin code since the last time it ran. When the
signature changes, a warning is displayed alerting you to which plugins have
changed. It is then up to you to manually verify that the changes are not
malicious, and then continue running the hooks.

The signature is derived from the contents of the plugin's source code itself
and any configuration for the plugin. Thus a change to the plugin's source
code or your local repo's `.overcommit.yml` file could result in a signature
change.

### Disabling Signature Checking

In typical usage, your plugins usually don't change too often, so this warning
shouldn't become a nuisance. However, users who work within proprietary
repositories where all developers who can push changes to the repository
already have a minimum security clearance may wish to disable this check.

While not recommended, you can disable signature verification by setting
`verify_signatures` to `false` in your `.overcommit.yml` file.

**Regardless of whether you have `verify_signatures` disabled for your project,
if you are running Overcommit for the first time you will need to sign your
configuration with `overcommit --sign`**. This needs to happen once so
Overcommit can record in your local git repo's configuration (outside of source
control) that you intend to enable/disable verification. This way if someone
else changes `verify_signatures` you'll be asked to confirm the change.

## Contributing

We love contributions to Overcommit, be they bug reports, feature ideas, or
pull requests. See our [guidelines for contributing](CONTRIBUTING.md) to best
ensure your thoughts, ideas, or code get merged.

## Community

All major discussion surrounding Overcommit happens on the
[GitHub issues list](https://github.com/sds/overcommit/issues).

## Changelog

If you're interested in seeing the changes and bug fixes between each version
of `overcommit`, read the [Overcommit Changelog](CHANGELOG.md).

## License

This project is released under the [MIT license](MIT-LICENSE).

The Overcommit logo is adapted from the [Git Logo by Jason Long][GL], and
is licensed under the [Creative Commons Attribution 3.0 Unported License][CC3].

[GL]: https://git-scm.com/downloads/logos
[CC3]: http://creativecommons.org/licenses/by/3.0/
