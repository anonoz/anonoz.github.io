---
layout: post
title: Dockerfile for Rails app in production and other lessons learned
date: 2018-05-01
category: tech
---

**For Singapore residents:** [Sign up with Best Electricity](https://bestelectricity.com.sg/?utm_source=anonoz&utm_medium=social&utm_campaign=anonoz-blog-post) and cut down your electricity bills!

_tl;dr: Scroll all the way down for Dockerfile._

In Prime Technologies, we provide digital solutions for our sister companies under Prime Group. When Singapore Open Electricity Market is about to launch, Prime Group decided to join the fray as Best Electricity Pte Ltd. We are tasked to build the system to support the operations of Best Electricity.

We use Ruby on Rails for almost all our projects. The first projects are deployed on Heroku. For cost and performance reasons, we have deployed few subsequent projects onto AWS, using Chef to configure the servers and Capistrano + CircleCI for deployment. We didn't need high availability and scalability these internal apps, so we kept it simple and went with single EC2 + RDS setup.

For Best Electricity, we wanted to try something different. This is our first public facing application, so as to not lose signups and customers' faith, having the portal highly available is pretty much a must. In August, the market will open up to the entire island, so we set out to make our infrastructure scalable from day one.

There are merits deploying applications in Docker containers. We can take advantage of various tools offered in Docker ecosystem. Docker Swarm makes deployment, scaling, secrets management easy. Docker Compose allows us to develop intercommunicating apps and services locally, while keeping the dev-prod parity small.

But when it comes to writing Dockerfile to build the container for deployment, it is not easy. Plenty of the Dockerfile examples for Ruby on Rails apps are simple, good enough, but we have specific use cases that I believe many other developers share as well. This is the reason I pen them down in this post, and I hope you will be able to benefit from it.

We use 2 Dockerfiles:

* `Dockerfile` for development, used together with `docker-compose` - When you run `docker-compose build` it will use `Dockerfile` in the same directory by default.
* From `Dockerfile` we comment out last few lines to make the base image for use in CircleCI - we have special binaries not found in their convenience images.
* `Dockerfile-production` that builds our application image along with Ruby gems, frontend assets.

### Get rid of the bloats

There are few things that will cause your image to bloat up:

* System dependencies that are only needed to build the native extensions
* Git repositories from private gems or Gems you patched
* Bundler cache

For our project, we use [Docker multistage builds](https://docs.docker.com/develop/develop-images/multistage-build/). The core idea is, there are dependencies that you need to build Ruby Gem native extensions, precompiled assets, but not needed to actually run the application itself. 

In the builder stage, we have additional Alpine Linux packages such as `build-base` that can help us compile native extensions written in C, `yarn` to collect JavaScript libraries.

To illustrate how big of a difference `build-base` makes:

```
FROM ruby:2.4.4-alpine3.7
RUN apk add --no-cache \
  busybox \
  ca-certificates \
  curl \
  gnupg1 \
  graphicsmagick \
  libsodium-dev \
  nodejs \
  postgresql-dev \
  rsync
# Size = 129MB
```

```
FROM ruby:2.4.4-alpine3.7
RUN apk add --no-cache \
  build-base \              # + this line
  busybox \
  ca-certificates \
  curl \
  gnupg1 \
  graphicsmagick \
  libsodium-dev \
  nodejs \
  postgresql-dev \
  rsync
# Size = 273MB
```

That's a difference of 144MB that can be shaved off the final image. Luckily, we only need `build-base` to build the gems, not the actual running of the Rails app.

It takes some trial and errors to find out which packages you can do without in production. Start with the bare minimum packages, then test if your app works, slowly add back the packages that are actually required.

### Private Gems

We have several Gems in private Git repositories. These are the instructions that do the bundling:

```docker
COPY Gemfile Gemfile.lock /app/
ARG SSH_CHECKOUT_KEY
RUN mkdir /root/.ssh/ \
  && echo "${SSH_CHECKOUT_KEY}" > /root/.ssh/id_rsa \
  && chmod 400 /root/.ssh/id_rsa \
  && touch /root/.ssh/known_hosts \
  && echo  $'\
github.com,192.30.255.112,192.30.255.113 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ== \n\
bitbucket.org,104.192.143.1,104.192.143.2,104.192.143.3  ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAubiN81eDcafrgMeLzaFPsw2kNvEcqTKl/VqLat/MaB33pZy0y3rJZtnqwR2qOOvbwKZYKiEO1O6VqNEBxKvJJelCq0dTXWT5pbO2gDXC6h6QDXCaHo6pOHGPUy+YBaGQRGuSusMEASYiWunYN0vCAI8QaXnWMXNMdFP3jHAJH0eDsoiGnLPBlBp4TNm6rYI74nMzgz3B9IikW4WVK+dc8KZJZWYjAuORU3jc1c/NPskD2ASinf8v3xnfXeukU0sJ5N6m5E8VLjObPEO+mN2t/FZTMZLiFqPWc/ALSqnMnnhwrNi2rbfg/rd/IpL8Le3pSBne8+seeFVBoGqzHM9yXw== \n\
  ' >> /root/.ssh/known_hosts \
  && bundle config --global frozen 1 \
  && bundle install --without development test -j4 --retry 3 \
  && rm -rf /root/.ssh/id_rsa \
    /usr/local/bundle/bundler/gems/*/.git \
    /usr/local/bundle/cache/
```

For our projects, we use CircleCI to build our images. CircleCI has its own SSH checkout key that can be added to our private gem repositories on Bitbucket with readonly access right. You can pass the key in into the build environment like this:

```sh
docker build \
  -f Dockerfile-production \
  -t $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG \
  --build-arg SSH_CHECKOUT_KEY="$(cat ~/.ssh/id_rsa)" .
```

There is a reason why all these shell commands need to be joined together into 1 docker `RUN` instruction. Each `RUN` creates a new image layer and they are immutable. If we `RUN echo "${SSH_CHECKOUT_KEY}" > /root/.ssh/id_rsa` and `RUN rm -rf /root/.ssh/id_rsa` subsequently, the 2nd command does not achieve what you want because the private key can still be found inside the previous layer.

The last `rm -rf` command is the one that purges the private checkout key, Git repositories of private gems, and bundler's own cache of gems in general. 

We have no use for bundler caches in Docker images. If Gemfile & Gemfile.lock have been changed, Docker build will not reuse any layers built after that `COPY Gemfile Gemfile.lock /app/`. Sadly, that means all the Gems need to be bundled from scratch even if only tiny changes are made, this is why `bundle install --without development test -j4 --retry 3` - 4 parallel downloads and native ext compilations speed things up a lot!

### Non-Ruby gems e.g. wkhtmltopdf-binary

Our Rails app depends on `wicked-pdf` gem to generate PDFs and in turn, it depends on `wkhtmltopdf` binary. Inside the gem's readme, it simply asks readers to add `gem 'wkhtmltopdf-binary'` into the Gemfile. The "gem" is actually just a ferry of 3-4 wkhtmltopdf binaries compiled for Mac (Darwin), Linux x86, Linux AMD64. Binaries that are not used waste space on our image. We only need one that works on Alpine.

Fortunately [someone has made it work on Alpine and published an image with that binary](https://beuke.org/docker-alpine-wkhtmltopdf/). According to the blog post, compiling the dependencies required for wkhtmltopdf take 4 hours. Thanks to Docker multistage build, we can just use that image as a stage, and copy the binary file over to our final image. I am too lazy to find out the specific directories to copy over for the `lib-*` packages, so I copy that instruction over from his Dockerfile and put it in our own Dockerfile-production.

To preserve the flexibility of being able to do development in non-Linux environments, we simply shift `gem 'wkhtmltopdf-binary'` into the development & test group of the Gemfile.

```ruby
# config/initializers/wicked_pdf.rb
if File.exists?('/bin/wkhtmltopdf')
  WickedPdf.config = {
    exe_path: '/bin/wkhtmltopdf'
  }
end
```

### References

Blog posts I read that got me onboard:

1. [EngineYard - Using Docker for Rails in a Production Environment](https://www.engineyard.com/blog/using-docker-for-rails)
2. [Codeship - Deploying Your Docker Rails App](https://blog.codeship.com/deploying-docker-rails-app/)
3. [Minimal Wkthmltopdf Docker Container](https://beuke.org/docker-alpine-wkhtmltopdf/)

### Appendix - Dockerfile-production

```docker
# We are using wkhtmltopdf to generate PDF files. Unfortunately according to 
# madnight, compiling wkhtmltopdf from scratch will take hours even with the
# largest ec2 instance. So here we take the precompiled binary from the other
# image available on Dockerfile - we will get to this in final stage.
#
FROM madnight/docker-alpine-wkhtmltopdf as wkhtmltopdf_image

# Builder stage
FROM ruby:2.4.4-alpine3.7 as builder

ENV CA_CERTS_PATH /etc/ssl/certs/
ENV RAILS_ENV production
ENV RAILS_LOG_TO_STDOUT true
ENV RAILS_SERVE_STATIC_FILES true

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

COPY Gemfile Gemfile.lock /app/
ARG SSH_CHECKOUT_KEY
RUN mkdir /root/.ssh/ \
  && echo "${SSH_CHECKOUT_KEY}" > /root/.ssh/id_rsa \
  && chmod 400 /root/.ssh/id_rsa \
  && touch /root/.ssh/known_hosts \
  && echo  $'\
github.com,192.30.255.112,192.30.255.113 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ== \n\
bitbucket.org,104.192.143.1,104.192.143.2,104.192.143.3  ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAubiN81eDcafrgMeLzaFPsw2kNvEcqTKl/VqLat/MaB33pZy0y3rJZtnqwR2qOOvbwKZYKiEO1O6VqNEBxKvJJelCq0dTXWT5pbO2gDXC6h6QDXCaHo6pOHGPUy+YBaGQRGuSusMEASYiWunYN0vCAI8QaXnWMXNMdFP3jHAJH0eDsoiGnLPBlBp4TNm6rYI74nMzgz3B9IikW4WVK+dc8KZJZWYjAuORU3jc1c/NPskD2ASinf8v3xnfXeukU0sJ5N6m5E8VLjObPEO+mN2t/FZTMZLiFqPWc/ALSqnMnnhwrNi2rbfg/rd/IpL8Le3pSBne8+seeFVBoGqzHM9yXw== \n\
  ' >> /root/.ssh/known_hosts \
  && bundle config --global frozen 1 \
  && bundle install --without development test -j4 --retry 3 \
  && rm -rf /root/.ssh/id_rsa \
    /usr/local/bundle/bundler/gems/*/.git \
    /usr/local/bundle/cache/

COPY package.json yarn.lock /app/
RUN yarn install

COPY . /app/
RUN bundle exec rails \
  AWS_ACCESS_KEY_ID=placeholder \
  AWS_SECRET_ACCESS_KEY=placeholder \
  DATABASE_URL=postgresql:does_not_exist \
  SECRET_KEY_BASE=placeholder \
  assets:precompile

# Packaging final app without node_modules & the development tools
FROM ruby:2.4.4-alpine3.7

ENV CA_CERTS_PATH /etc/ssl/certs/
ENV RAILS_ENV production
ENV RAILS_SERVE_STATIC_FILES true
ENV RAILS_LOG_TO_STDOUT true

RUN apk add --no-cache \
  busybox \
  ca-certificates \
  curl \
  gnupg1 \
  graphicsmagick \
  libsodium-dev \
  nodejs \
  postgresql-dev \
  rsync

# Copied pasted from Dockerfile in madnight/docker-alpine-wkhtmltopdf
RUN apk add --update --no-cache \
    libgcc libstdc++ libx11 glib libxrender libxext libintl \
    libcrypto1.0 libssl1.0 \
    ttf-dejavu ttf-droid ttf-freefont ttf-liberation ttf-ubuntu-font-family

COPY --from=wkhtmltopdf_image /bin/wkhtmltopdf /bin/

RUN mkdir -p /app
WORKDIR /app

COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder /app/ /app/
COPY --from=builder /app/config/gpg/ /root/.gnupg/

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

### Appendix - Dockerfile for development and testing

```docker
FROM madnight/docker-alpine-wkhtmltopdf as wkhtmltopdf_image

FROM ruby:2.4.4-alpine3.7

RUN mkdir -p /app
WORKDIR /app

# System level dependencies
RUN apk add --no-cache \
  build-base \
  busybox \
  ca-certificates \
  chromium \
  chromium-chromedriver \
  curl \
  git \
  gnupg1 \
  gpgme \
  less \
  libffi-dev \
  libsodium-dev \
  nodejs \
  openssh-client \
  postgresql-dev \
  rsync \
  yarn

ENV CHROME_BIN=/usr/bin/chromium-browser
ENV CHROME_PATH=/usr/lib/chromium/
ENV CHROME_NO_SANDBOX=true

# For wkhtmltopdf
RUN apk add --update --no-cache \
    libgcc libstdc++ libx11 glib libxrender libxext libintl \
    libcrypto1.0 libssl1.0 \
    ttf-dejavu ttf-droid ttf-freefont ttf-liberation ttf-ubuntu-font-family

COPY --from=wkhtmltopdf_image /bin/wkhtmltopdf /bin/

# Comment out everything below, then build the image for CI
# 
# Use secrets in docker-compose.yml to make your SSH key available.
#
RUN mkdir ~/.ssh \
  && ln -s /run/secrets/host_ssh_key ~/.ssh/id_rsa \
  && echo  $'\
github.com,192.30.255.112,192.30.255.113 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ== \n\
bitbucket.org,104.192.143.1,104.192.143.2,104.192.143.3 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAubiN81eDcafrgMeLzaFPsw2kNvEcqTKl/VqLat/MaB33pZy0y3rJZtnqwR2qOOvbwKZYKiEO1O6VqNEBxKvJJelCq0dTXWT5pbO2gDXC6h6QDXCaHo6pOHGPUy+YBaGQRGuSusMEASYiWunYN0vCAI8QaXnWMXNMdFP3jHAJH0eDsoiGnLPBlBp4TNm6rYI74nMzgz3B9IikW4WVK+dc8KZJZWYjAuORU3jc1c/NPskD2ASinf8v3xnfXeukU0sJ5N6m5E8VLjObPEO+mN2t/FZTMZLiFqPWc/ALSqnMnnhwrNi2rbfg/rd/IpL8Le3pSBne8+seeFVBoGqzHM9yXw== \n\
  ' >> ~/.ssh/known_hosts

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```
