---
layout: post
title: "Watch out: Google search does not respect language HTTP headers"
date: 2019-03-16
category: tech
---

I was googling 'MDN' for Mozilla Developer Network documentations. It showed me the Burmese site as top result.

But my device is set to use English, and my browsers specifically requested for contents to be shown in English, Simplified Chinese, any other Chinese, and Malay, in that particular order. I don't know any Burmese.

![Google Search Results of MDN](/assets/images/google-mdn-accept-lang.png)

It just so happens that Malaysia's ISO 3166-1 alpha-2 country code (MY) happens to be the same as Burmese ISO 639-1 language code (MY). Malay language's ISO code is MS.

MDN did not do anything wrong, they chose to use `/$locale/*` for their paths, and they have set `<html lang="my">` and `content-language` response header correctly. 

So Google chose to ignore:

1. Client's accept-langugage request header.
2. Server's content-language response header.
3. HTML tag lang attribute.

And simply:

1. Determine your country from client IP address.
2. Parse the URL and just guess the first part must be a country code, it cannot possibly be language code or locale string amirite?

Google is not the only offender, Facebook too:

![Facebook knows that you don't know Malay, and renders Malay anyway.](/assets/images/facebook-language-ignored.png)

Please Google and Facebook, if my browser has explicitly told you what language I would like to be shown, respect it. If I want English, give me English. Just because I am accessing from Malaysia, does not necessarily mean I understand Malay (Saya boleh cakap bahasa tapi dia orang mungkin orang asing mah).