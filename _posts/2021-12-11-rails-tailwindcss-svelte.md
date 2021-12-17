---
layout: post
title: "How to install Svelte and Tailwindcss with jsbundling and cssbundling in Rails without Webpack"
date: 2021-12-11
category: tech
image:
  path: /assets/images/rails-tailwind-svelte/techtrio1x.png
---

As of the publication date of this guide, Rails 7 is about to be released and with it, comes the new cssbundling-rails and jsbundling-rails gems from the Rails core team.

[cssbundling-rails](https://github.com/rails/cssbundling-rails) allows us to easily use other CSS transpilers such as Tailwind, PostCSS, DartSass apart from what is offered in Ruby gems.

[jsbundling-rails](https://github.com/rails/jsbundling-rails) allows us to use JS compilers other than webpack - which is absolutely painful to work with. 

In this short tutorial, I will be using esbuild, which is easier to configure than webpack for those who only seek to build js files and not replace the whole Sprockets asset pipeline.

This short guide will only cover Svelte and Tailwind, because these are the tools we use in Talenox.

You will need these installed before you proceed: node, yarn, foreman.

### Demo codes

I will put the demo codes on [anonoz/demo-rails6-tailwind-svelte](https://github.com/anonoz/demo-rails6-tailwind-svelte/commits/main) repo. You are free to check the commit logs as you read along, clone it, and play with it. I have removed activerecord, activestorage, actionmailer so there is nothing much to setup.

You can create a simple page to test out the different CSS

```html
<div class="existing-css-file">
  <h1>This is old school sprockets css.</h1>
</div>

<div class="container mx-auto">
  <h1 class="text-3xl text-pink-900">This is Tailwind.</h1>
</div>

<div data-svelte-component="DemoSvelteComponent">
</div>
```

Add append the following into `app/assets/stylesheets/application.css` 

```css
.existing-css-file h1 {
  font-size: 5rem;
  color: #324343;
}
```

Since we have not added Tailwindcss yet, we still have the original browser styles. Over the next few steps we will see how the web page's looks change.

![Screenshot at the end of Step 0](/assets/images/rails-tailwind-svelte/step0.png)

### Step 1: Add the gems and run their setup script

Follow their readmes and add these to your `Gemfile`

```
gem 'jsbundling-rails'
gem 'cssbundling-rails'
```

Then run:

```
bundle
bundle exec rails css:install:tailwind
```

After this step, you can use `bin/dev` to boot up Rails development server and Tailwindcss one shot. You may need to `gem install foreman` to start them with `Procfile.dev`.

Before you proceed, please check the files changed and make sure it did not wipe your codes out. You may want to rename the newly generated js and css files to avoid conflicts with your existing ones.

![Screenshot at the end of Step 1](/assets/images/rails-tailwind-svelte/step1.png)

As you can see in the screenshot above, the custom style for the first H1 is missing - the font size and color are gone.

### Step 1a: Recover existing application.css

As of now, running `rails css:install:tailwind` will delete your existing `app/assets/stylesheets/application.css`. Here is how to recover them:

First rename the output filename for tailwind. Inside `package.json`, change the filename arguments for tailwindcss:

```
"scripts": {
    "build:css": "tailwindcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.tailwind.css"
  }
```

Update your layout file to reference the new CSS file

```
<!-- The original sprockets one -->
<%= stylesheet_link_tag 'application', media: 'all', 'data-turbolinks-track': 'reload' %>
    
<!-- The tailwind 
<%= stylesheet_link_tag "application.tailwind" %>
```

After that, checkout the previous `application.css` from your Git.

```
git checkout -- app/assets/stylesheets/application.css
```

In `app/assets/config/manifest.js`, add back your application.css manually:

```
//= link_tree ../images
//= link_tree ../builds
//= link application.css
```

If you have run `bin/dev` rails server before this step, you may need to clear your `app/assets/builds/` directory because there would be a Tailwind generated `application.css` inside. The new bundling gems do not clear the directories on every reload.

Now your old styling should be back:

![Screenshot at the end of Step 1a](/assets/images/rails-tailwind-svelte/step1a.png)

### Step 2: Add Svelte

First we install `esbuild` through the jsbundling-rails way.

```
bundle exec rails js:install:esbuild
```

We will be using [esbuild-svelte](https://github.com/EMH333/esbuild-svelte) plugin.

```
yarn add esbuild-svelte
```

Add a custom build script, save the following at `esbuild.config.js` in project root directory.

```
#!/usr/bin/env node

var watch = process.argv.includes("--watch");

require('esbuild').build({
    entryPoints: ["app/javascript/application.js"],
    bundle: true,
    outfile: "app/assets/builds/application.js",
    plugins: [require('esbuild-svelte')()],
    logLevel: "info",
    watch: watch
}).catch(() => process.exit(1));
```

Replace the default esbuild build command with the build script supporting Svelte in `package.json`:

```
"scripts": {
    "build:css": "tailwindcss --postcss -i ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/landside.css.erb",
    "build": "node ./esbuild.config.js"
  }
```

Alright, now we need to test if we can build Svelte components. You are free to copy and paste the following codes.

Save this in `app/javascript/svelte/DemoSvelteComponent.svelte`

```html
<script>
  import {
    onMount
  } from 'svelte';

  export let argName;

  onMount(() => {
      if (argName == undefined) {
        argName = "General Kenobi"
      }
    })
</script>
<!--  -->
<h1 class="italic text-blue-700">Hello there, {argName}!</h1>
```

Save this in `app/javascript/application.js`:

```js
import DemoSvelteComponent from './svelte/DemoSvelteComponent.svelte'

window.addEventListener('load', () => {
  if (t = document.querySelector('[data-svelte-component="DemoSvelteComponent"]')) {
    const app = new DemoSvelteComponent({
      target: t
    });
  }
})
```

Restart your `bin/dev` and see if the message appears on the page. You should be seeing **"Hello there, General Kenobi!"**.

![Screenshot at the end of Step 2](/assets/images/rails-tailwind-svelte/step2.png)

### Step 3: Configure Tailwind to parse Svelte codes

Inside `tailwind.config.js`, add the path to Svelte components into purge (Tailwind 2) or content attribute (Tailwind 3):

```
content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/javascript/**/*.svelte'
  ]
```

Restart `bin/dev`, now you should be seeing the text rendered by Svelte styled by Tailwindcss.

![Screenshot at the end of Step 3](/assets/images/rails-tailwind-svelte/step3.png)

I would like to thank Rails core contributors for making it happen, the new workflow has been absolutely joyful to work with.

I hope you have enjoyed this short guide and found it useful! 

In the next post, I will be sharing how we use Ruby on Rails as static site generator to build the new website for Talenox on [https://www.talenox.com](https://www.talenox.com).
