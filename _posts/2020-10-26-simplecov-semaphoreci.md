---
layout: page
title: "How to merge SimpleCov results on SemaphoreCI 2.0"
date: 2020-10-26
category: tech
---

## Background

We have been using [SemaphoreCI](https://semaphoreci.com) at [Talenox](https://www.talenox.com) for over a year now. 

We like Semaphore a lot because of their bare metal performance and their fair per-second pricing, which is different from other CIs charging by maximum parallelisms.

Having sufficient test coverage has helped us in staying clear of nasty problems along the road, I highly encourage other projects to keep it in check too!

Feel free to copy and paste the following scripts and YAMLs, if there are any error and problems, please contact me and let me know.

## Step 1: Setup SimpleCov

Include it in your `Gemfile`, please find the latest version number and replace it: 

```ruby
gem 'simplecov', '~> 0.18.0', require: false
```

To make sure SimpleCov tracks the code coverage in Capybara test, paste this in your `bin/rails` before the existing code:

```ruby
#!/usr/bin/env ruby
if ENV['RAILS_ENV'] == 'test'
  require 'simplecov'
  SimpleCov.start 'rails'
end
# ^^ Copy Above

APP_PATH = File.expand_path('../../config/application', __FILE__)
require_relative '../config/boot'
require 'rails/commands'
```

In your `specs/spec_helper.rb`, paste this between all the `require` and other configuration blocks:

```ruby
if ENV['CI']
  SimpleCov.command_name "#{ENV['SEMAPHORE_JOB_ID']}-#{ENV['TEST_ATTEMPT']}"
end

SimpleCov.start 'rails'
```

## Step 2: Here are the .yaml and .rb

Paste this in `scripts/simplecov-collate.rb` in your project directory:

```ruby
#!/usr/bin/env ruby
require 'simplecov'

SimpleCov.collate Dir["simplecov-resultset/*/.resultset.json"] do
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::SimpleFormatter,
    SimpleCov::Formatter::HTMLFormatter
  ])
end
```

I assume:

1. You already have SimpleCov gem included and configured in your rspec.
2. Your project directory is mounted in `/project-mount` in the Docker image that you used to test. SimpleCov somehow uses absolute path inside their result JSON files, and this is the way to make the merge successful.
3. SemaphoreCI git clones into `~/reponame` when `checkout` command is being run.

Update your `.semaphore/semaphore.yml`:

1. The `epilogue` that runs after every parallel tests, and;
2. The block that runs after ALL the tests.

```yaml
# .semaphore/semaphore.yml
blocks:
  - name: 'Run tests'
    task:
      jobs:
        - name: 'E2E Part 1'
        - name: 'E2E Part 2'
        - name: 'E2E Part 3'
        - name: 'Models'
        - name: 'API'
      # Copy the commands in the epilogue, this runs after every different test.
      epilogue:
        always:
          commands:
            - |
                if [ -d coverage ]; then
                  artifact push job --expire-in 3d --force coverage;
                  COV_DIRNAME=simplecov-resultset/$SEMAPHORE_JOB_ID;
                  sudo chown -R $USER:$USER coverage/;
                  mkdir -p simplecov-resultset;
                  mv coverage $COV_DIRNAME;
                  artifact push workflow --expire-in 2w --force simplecov-resultset;
                fi
  
  # Feel free to copy this block below!
  - name: 'Check codebase quality'
    task:  
      jobs:
        - name: 'Test coverage'
          commands:
            - checkout
            - |
                if ! rbenv install -s; then
                  git -C /home/semaphore/.rbenv/plugins/ruby-build pull &&
                  rbenv install;
                fi
            - sudo mkdir -p /project-mount
            - sudo chown -R $USER:$USER /project-mount
            - cd ~
            - shopt -s dotglob; mv ~/reponame/* /project-mount
            - cd /project-mount
            - artifact pull workflow simplecov-resultset
            - gem install simplecov
            - ruby scripts/simplecov-collate.rb
            - cd coverage/
            - cd /project-mount
            - zip -r coverage-$SEMAPHORE_GIT_SHA coverage/
            - artifact push job --expire-in 2w coverage-$SEMAPHORE_GIT_SHA.zip
```

Once you are done, commit and push to trigger a CI run.

## Step 3: Get your test coverage!

If the configurations are correct and your test suites pass as usual, this is how you can find your test coverage results.

Go into the workflow for the latest commit, you should see there is a new block at the end after the parallel tests.

![Screenshot 3-1 test coverage job](/assets/images/simplecov-semaphore/step3-1.png){: .center-image }

Click **Job artifacts** between the console outputs and the job name. That is not the most obvious place, I know. By the time you read this, the UI may have changed again, but it should be somewhere in the page.

![Screenshot 3-2 job artifacts above the outputs](/assets/images/simplecov-semaphore/step3-2.png){: .center-image }

You should be able to download the zip file here.

![Step 3-3 Download Coverage zip.](/assets/images/simplecov-semaphore/step3-3.png){: .center-image }

Download and unzip it, then open `index.html` file in your browser to view.

Unlike CircleCI, every artifact on SemaphoreCI cannot be viewed directly in the browser, but rather must be downloaded. It is not very convenient.

---

1. **Why `gem install simplecov` separately instead of just using the Docker image I have been using?**

    The Docker images are usually large. Downloading just the gems needed is much quicker than pulling the image all over again. In our case, it takes almost a minute to pull the testing Docker image down, but only 20 seconds to run the whole SimpleCov merging job - from git cloning, to gem install, to uploading artifact.

2. **What if we did not run tests in Docker image?**

    You should be able to replace `/project-mount` with the directory pah the project is git cloned into in previous test jobs.

Thanks for reading. Please let me know if there are changes made to SimpleCov or SemaphoreCI that rendered this guide unusable.
