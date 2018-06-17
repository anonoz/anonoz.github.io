---
layout: post
title: DIY Docker Layer Caching on CircleCI - How to Deal With Ever-Changing Base Image IDs
date: 2018-06-17
category: tech
---

If you are reading this post, I assumed that you have been building Docker images for deployment on CircleCI. You probably have been asked by their customer success reps to switched from containers plan ($50/container) to their new, unannounced, shockingly expensive Performance Pricing Plan, just to be able to opt into their Docker Layer Caching addon ($15/month). It totally didn't make any sense for us in Prime Technologies to move onto the new plan, get charged 2-3x what we are paying now, just to be able enjoy Docker Layer Caching.

Thanks to [Jon's blog post on CircleCI DLC](https://blog.jondh.me.uk/2018/04/strategies-for-docker-layer-caching-in-circleci/), we managed to do Docker layers caching, without burning our pockets.

## Problem

These are the cache keys I was using to store the docker layers:

```
{% raw %}docker-layer-{{ checksum "Dockerfile-production "}}-{{ checksum "Gemfile.lock"}}
docker-layer-{{ checksum "Dockerfile-production "}}{% endraw %}
```

Shortly after implementing docker layer caching in our build process, the Docker official ruby image has been updated. Turns out, docker build will hit the registry to check if there is newer version of the base image - and if there is, the newer base image will be pulled, and almost the entire cache restored from CircleCI will not be used.

That means we will waste 1 more minute for CircleCI to restore the cache, on top of Docker building all image layers from scratch, resulting in even more time wasted.

This happens often enough that I think manually busting the caches everytime it happens is not worth the effort.

## Solution

The key is to use the base image IDs as part of cache key. This is how the deployment steps can be revised:

1. Check `Dockerfile-production` for base images that will be used (by grepping lines started with `FROM`).
2. Hit Docker Hub API to GET image IDs for the base images.
3. Form the caching key by concatenating content of `Dockerfile-production` with all the base image IDs.
4. Attempt to restore from the cache, docker build, docker push, docker service update xxx, then save the layers into cache.

If they change any of the base images we use, there won't be any cache hits, and we go straight to building the image layers from scratch.

I assume you will be using machine executor type, but if you are using customer Docker image for these steps, make sure you have the tools needed e.g. `jq`, `curl` etc.

Example `steps` in `.circleci/config.yml`:

```yaml
- run:
    name: Check if there are newer base images on Docker Hub
    command: |
      BASE_IMAGE_NAMES=$(grep "^FROM" Dockerfile-production | cut -d' ' -f2 | uniq)
      cp Dockerfile-production docker-layer-caching-key.txt
      for n in $BASE_IMAGE_NAMES; do

        if grep -q ':' <<< "$n"; then
          REPOSITORY=$(cut -d':' -f1 <<< "$n")
          TAG=$(cut -d':' -f2 <<< "$n")
        else
          REPOSITORY=$n
          TAG="latest"
        fi

        # If there is no slash in the repo name, it is an official image,
        # we will need to prepend library/ to it
        if ! grep -q '/' <<< "$REPOSITORY"; then
          REPOSITORY="library/$REPOSITORY"
        fi

        # Source: https://stackoverflow.com/questions/41808763/how-to-determine-the-docker-image-id-for-a-tag-via-docker-hub-api
        TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$REPOSITORY:pull" | jq -r .token)
        IMAGE_DIGEST=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" https://index.docker.io/v2/$REPOSITORY/manifests/$TAG | jq -r .config.digest)

        # Append the newfound IDs to form the key
        echo $IMAGE_DIGEST >> docker-layer-caching-key.txt
      done
- restore_cache:
    keys:
      - {% raw %}docker-layers-{{ checksum "docker-layer-caching-key.txt" }}{% endraw %}
      - {% raw %}docker-layers-{{ checksum "docker-layer-caching-key.txt" }}-{{ checksum "Gemfile.lock" }}{% endraw %}
- run:
    name: Load Docker layer cache
    command: |
      # credits to: https://blog.jondh.me.uk/2018/04/strategies-for-docker-layer-caching-in-circleci/
      set +o pipefail
      if [ -f /home/circleci/docker-caches/${CIRCLE_PROJECT_REPONAME}.tar.gz ]; then
        gunzip -c /home/circleci/docker-caches/${CIRCLE_PROJECT_REPONAME}.tar.gz | docker load;
        docker images;
      fi
- run:
    name: Building & pushing docker image
    command: |
      source env_file
      docker build \
        -f Dockerfile-production \
        -t $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG \
        --build-arg SSH_CHECKOUT_KEY="$(cat ~/.ssh/id_rsa)" \
        .
      docker tag $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG $DOCKER_IMAGE_NAME:latest
      eval $(aws ecr get-login --no-include-email --region ap-southeast-1)
      docker push $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG
      docker push $DOCKER_IMAGE_NAME:latest
- run:
    name: Deploy to cluster
    command: |
      # redacted
- run:
    name: Save Docker layer cache
    command: |
      mkdir -p /home/circleci/docker-caches
      docker build \
        -f Dockerfile-production \
        --tag $DOCKER_IMAGE_NAME \
        --build-arg SSH_CHECKOUT_KEY="$(cat ~/.ssh/id_rsa)" . \
        | grep '\-\-\->' \
        | grep -v 'Using cache' \
        | sed -e 's/[ >-]//g' > /tmp/layers.txt
      docker save $(cat /tmp/layers.txt) | gzip > /home/circleci/docker-caches/${CIRCLE_PROJECT_REPONAME}.tar.gz
- save_cache:
    key: {% raw %}docker-layers-{{ checksum "docker-layer-caching-key.txt" }}{% endraw %}
    paths:
      - /home/circleci/docker-caches
- save_cache:
    key: {% raw %}docker-layers-{{ checksum "docker-layer-caching-key.txt" }}-{{ checksum "Gemfile.lock" }}{% endraw %}
    paths:
      - /home/circleci/docker-caches
```

This is the solution I managed to come up with. If you have other ideas on how to go about this, please let me know. Thanks!
