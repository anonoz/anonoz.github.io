---
layout: post
title: "Malaysia Vaccine Certificate Verifier is Useless"
date: 2021-07-15
category: tech
image:
  path: /assets/images/vaccine-certificate/fakecert-dylan.jpg
---

Update: They have fixed this for iOS on 23rd July 2021, 1 week after the publication of this blog post.

In Malaysia, we use MySejahtera to perform contact tracing, vaccination appointments, and vaccine certification. Malaysia government has also provided another app - Vaccine Certificate Verifier - to allow the public to scan the vaccine certificate QR code in MySej app. This app will be used a lot when enough people are vaccinated and [shops reopen](https://www.thestar.com.my/news/nation/2021/07/15/pm-consider-relaxing-movement-control-for-those-who-have-received-two-covid-19-vaccine-doses).

I show you why this app is useless and harmful in its present form, as of 15th July 2021.

<video src="/assets/images/vaccine-certificate/app-demo.mp4" controls></video>

Maybe you expect the app to at least verify the website comes from MOH. It doesn't, it's just a simple QR code reader. The fake cert is obviously not on Ministry on Health's server, but mine. You can try scan this:

![Fake vaccine certificate QR code](/assets/images/vaccine-certificate/fake-qr.png){: .center-image }

Thankfully the fix should be trivial. Just check for the hostname in the QR code, and make sure HTTPS is always used.

Hope you guys fix it soon before we move onto reopening!

_Opengraph photo credit: Dylan Damsma_
