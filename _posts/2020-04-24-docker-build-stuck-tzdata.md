---
layout: post
title: Docker build stuck at tzdata prompt? Could be Ubuntu 20.04 and how to fix it.
date: 2020-04-24
category: tech
---

Today our routine `docker build` in our CI got stuck.

```
Setting up tzdata (2019c-3ubuntu1) ...
debconf: unable to initialize frontend: Dialog
debconf: (TERM is not set, so the dialog frontend is not usable.)
debconf: falling back to frontend: Readline
Configuring tzdata
------------------

Please select the geographic area in which you live. Subsequent configuration
questions will narrow this down by presenting a list of cities, representing
the time zones in which they are located.

  1. Africa      4. Australia  7. Atlantic  10. Pacific  13. Etc
  2. America     5. Arctic     8. EurJob Finished
```

The base image we used is `ubuntu:latest`. But Ubuntu just released 20.04 Focal Fossa yesterday, and one of the changes there broke our builds.

Here are 2 options to go around fixing it:

#### #1 Change to ubuntu:18.04

Just change your base image down to an older stable version.

```diff
-FROM ubuntu:latest
+FROM ubuntu:18.04
```

#### #2 DEBIAN_FRONTEND=noninteractive apt-get...

```diff
-RUN apt-get update && \
+RUN DEBIAN_FRONTEND=noninteractive \
+    TZ=Asia/Singapore \
+    apt-get update && 
     apt-get install -y \         
```

I don't go for `ENV DEBIAN_FRONTEND=noninteractive` because that's not an env var I wanna set permanently for the container image.

Anyway that's just a quick fix, I hope they patch it soon!

P/S: It seems like this post is getting 200 clicks per day, if you have spare change, please consider donating to [United Nations' World Food Programme](https://sharethemeal.org/donate) to help people with poor food security. Pay it forward!
