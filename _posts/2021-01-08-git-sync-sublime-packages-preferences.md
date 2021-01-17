---
layout: page
title: "How to sync Sublime Text packages and preferences with Git"
description: Works on Linux, Mac.
date: 2021-01-17
category: tech
image:
  path: /assets/images/sublime-text.png
---

![Sublime Text](/assets/images/sublime-text.png)

It is possible and even pleasurable to sync Sublime Text packages and preferences across multiple workstations from different OS with Git. Here is how.

Outline:

1. Find out your Sublime Text preferences directory path on Workstation A.
2. Initialise a Git repository there.
3. Push to a remote repository of your choice.
4. Find out where the preferences directory is on your destination - Workstation B.

### Pushing it

Tips: On Mac, just replace `Ctrl` with `Cmd` key.

1. Run `Ctrl + Shift + P` on Windows/Linux, select **Preferences: Settings**.
2. Once the new is opened, `Ctrl + Shift + P` and select **File: Copy Path**.
3. Open a terminal, `cd` to that path excluding the ending file name.
4. Go ahead and git init, add, commit that directory.

### Pulling it

1. Assuming you are working on a fresh installation of Sublime Text, `Ctrl + Shift + P` and select **Install Package Control**.
2. Repeat the steps 1-3 from above.
3. Close your Sublime Text.
4. `git clone $gitremoteurl .` when you are in that `../Packages/User` directory.
5. Open your Sublime Text, now wait for a few minutes for Package Control to download all the missing packages.

### Better way to do it

You can install the `SublimeGit` package and just run Git inside the Preferences JSON text file. That way you won't need to touch terminal at all.

