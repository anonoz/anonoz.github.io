---
layout: post
title: "How to use Docker Compose for Rails development: Do not bundle install in Dockerfile.dev"
date: 2019-03-10
category: tech
---

For past 12 months, we have been containerizing Rails apps for our projects, because we needed certain binaries like GnuPG 1, and Docker Swarm's container scheduling for the high availability and scalability offered. To close the dev-prod parity, we develop our app inside Docker container using Docker Compose, and the Dockerfile we use share the same base image and system binaries as the one used for production.

It wasn't easy starting out here.

There are plenty of [bad](https://blog.codeship.com/running-rails-development-environment-docker/) [examples](https://semaphoreci.com/community/tutorials/dockerizing-a-ruby-on-rails-application) [being](https://auth0.com/blog/ruby-on-rails-killer-workflow-with-docker-part-1/) [published](https://nickjanetakis.com/blog/dockerize-a-rails-5-postgres-redis-sidekiq-action-cable-app-with-docker-compose) online, including [Docker's own documentation](https://docs.docker.com/compose/rails/), and I suspect many of them were simply doing blog SEO marketing for their own products, without actually using Docker Compose for the purpose of developing Rails apps on daily basis.

There are 2 problems:

1. Not using separate Dockerfiles for development and production.
2. `bundle install` inside Dockerfile for development.

### Problem with gems installed in the image

Each instruction in a Dockerfile makes up an read-only immutable layer. For demonstration, let's create a huge junk file, add it, and remove it in Dockerfile.

Create a 128MB junk file of random content in _terminal_:
```bash
dd if=/dev/urandom of=junk bs=1M count=128
```

Add and delete the junk file in _Dockerfile_:

```docker
FROM alpine
COPY junk .
RUN rm junk
```

After that, build the Docker image in _terminal_:

```bash
docker build -t rm-junk .
docker image ls
```

You will get:
```
$ docker image ls
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
rm-junk             latest              7caa8295c677        6 seconds ago       139MB
```

In this example, the Dockerfile consists of 3 instructions. Since the layers built are immutable, the 3rd instruction containing `rm` command will not be able to delete the `junk` file in 2nd layer, even when you go `docker run -it rm-junk sh` and you can't find the `junk` file inside.

Each layer also checks against the local cache when being built. From the sample Dockerfile above, if the `junk` file never changes, `RUN rm junk` will not be run again:

```
$ docker build -t rm-junk .
Sending build context to Docker daemon  134.2MB
Step 1/3 : FROM alpine
 ---> 3f53bb00af94
Step 2/3 : COPY newfile .
 ---> Using cache
 ---> a541cb67c5be
Step 3/3 : RUN rm newfile
 ---> Using cache
 ---> c507dcbff10f
Successfully built c507dcbff10f
Successfully tagged rm-junk:latest
```

However, if there is even a tiny change in previous layers, all the subsequent layers will have the cache invalidated and will be run. That means, if you have a patch bump in `Gemfile.lock`, your entire `bundle install` and subsequent instructions will be run from scratch, costing you more space, time, and bandwidth.

If your project is under active development, everytime a single change is made in Gemfile/Gemfile.lock, whether adding a gem or bumping version to [patch vulnerable gems](https://github.com/rubysec/bundler-audit), you will have to rebuild the Docker image and run `bundle install` all over again.

And if you don't clear out the old image layers often enough, you will find your machine quickly running out of disk space soon. For developers in countries with terrible Internet access, this is a serious pain.

Wouldn't it be great to just download the added gem or npm package, instead of 90%+ of all other unchanged stuffs again, just like how they work outside of Docker?


## Use Docker volumes to store dependencies

If you use Docker Compose for development, and Docker Swarm for deployment, just make sure you have 2 separate sets of Dockerfiles and docker-compose.yml. To make life simple, we use `Dockerfile.dev` and `docker-compose.yml` for development, and a `Dockerfile.prod` for production.

Note: I only append all Dockerfiles here with the environment for clarity's sake. You are free to let either development or production's Dockerfile take the vanilla, tailless `Dockerfile` name.

```yaml
# docker-compose.yml
version: '3'
services:
  postgres:
    image: postgres
    ports:
      - 5432
    volumes:
      - postgres:/var/lib/postgresql/data
  web:
    env_file:
      - .env.dev
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: bundle exec rails s -p 3000 -b '0.0.0.0'
    volumes:
      - .:/myapp
      - bundler_gems:/usr/local/bundle/
    ports:
      - "3000:3000"
    links:
      - postgres
      - redis
  redis:
    image: redis
    ports:
      - 6379
    volumes:
      - redis:/data
  resque:
    build:
      context: .
      dockerfile: Dockerfile.dev
    command: bundle exec rake resque:work
    volumes:
      - .:/myapp
      - bundler_gems:/usr/local/bundle/
    links:
      - postgres
      - redis

volumes:
  postgres:
  redis:
  bundler_gems:
```

You can then have your `Dockerfile.dev` sans `bundle install`:

```docker
# Dockerfile.dev
FROM ruby:2.4.5-alpine as builder

RUN apk add --no-cache \
  build-base \
  busybox \
  ca-certificates \
  curl \
  git \
  gnupg1 \
  graphicsmagick \
  libffi-dev \
  libsodium-dev \
  nodejs \
  openssh-client \
  postgresql-dev \
  rsync \
  yarn

RUN mkdir -p /app
WORKDIR /app

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

Now you will need to run bundle install in a separate step to get the gems:

```bash
docker-compose build
docker-compose run --rm web bundle install -j8
docker-compose run --rm web bundle exec rails db:setup
```

After this, you can just run the 2nd command in the listing above whenever there are changes in Gemfile/Gemfile.lock.

## Passing your SSH key in as secret for private gems

Feel free to skip this section if this is irrelevant to you.

Your Rails app may have some private gems hosted on GitHub, Bitbucket, Gitlab. To pull those, you may either:

1. pass in your credentials thru HTTP basic authentication,
2. authenticate with SSH keys -- **we will be doing this because it's safer.**

It is very possible to do these without leaving any secrets or credentials in your repository and your Docker images. There are plenty of ways to go about this, personally, this is how I roll:

1. Make a `.secrets` directory, put it in `.gitignore` and `.dockerignore`.
2. `cp ~/ssh/id_rsa .secrets/host_ssh_key` - we can't just `ln -s` it in because of pesky permission issues.
3. `chmod 600 .secrets/host_ssh_key` to fix permission.
4. Declare the secret in `docker-compose.yml`.
5. Add a step to symlink your secret SSH key in your `Dockerfile.dev`.

Add this part in your `Dockerfile.dev`:

```docker
RUN mkdir ~/.ssh \
  && ln -s /run/secrets/host_ssh_key ~/.ssh/id_rsa \
  && echo  $'\
github.com,192.30.255.112,192.30.255.113 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ== \n\
bitbucket.org,104.192.143.1,104.192.143.2,104.192.143.3 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAubiN81eDcafrgMeLzaFPsw2kNvEcqTKl/VqLat/MaB33pZy0y3rJZtnqwR2qOOvbwKZYKiEO1O6VqNEBxKvJJelCq0dTXWT5pbO2gDXC6h6QDXCaHo6pOHGPUy+YBaGQRGuSusMEASYiWunYN0vCAI8QaXnWMXNMdFP3jHAJH0eDsoiGnLPBlBp4TNm6rYI74nMzgz3B9IikW4WVK+dc8KZJZWYjAuORU3jc1c/NPskD2ASinf8v3xnfXeukU0sJ5N6m5E8VLjObPEO+mN2t/FZTMZLiFqPWc/ALSqnMnnhwrNi2rbfg/rd/IpL8Le3pSBne8+seeFVBoGqzHM9yXw== \n\
  ' >> ~/.ssh/known_hosts
```

And then amend the `docker-compose.yml`:

```diff
--- docker-compose.before.yml  2019-03-10 22:24:50.494973458 +0800
+++ docker-compose.after.yml  2019-03-10 22:25:33.129197452 +0800
@@ -14,6 +14,8 @@
       context: .
       dockerfile: Dockerfile.dev
     command: bundle exec rails s -p 3000 -b '0.0.0.0'
+    secrets:
+      - source: host_ssh_key
     volumes:
       - .:/myapp
       - bundler_gems:/usr/local/bundle/
@@ -40,6 +42,11 @@
       - postgres
       - redis
 
+secrets:
+  host_ssh_key:
+    file: ./local-secrets/host_ssh_key
+
+
 volumes:
   postgres:
   redis:
```

You should be able to bundle install the gems from private repos now.

If you want to pass SSH key in when building Docker image for production, read [Dockerfile for Rails app in production and other lessons learned]({% post_url 2018-05-01-rails-dockerfile %}).
