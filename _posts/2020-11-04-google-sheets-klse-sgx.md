---
layout: page
title: "How to retrieve KLSE, SGX, and gold prices in Google Sheets (Updated for 2020)"
date: 2020-11-04
category: tech
---

For Bursa Malaysia (KLSE) and Singapore Exchange (SGX), we can scrape from [i3investor](https://klse.i3investor.com/index.jsp) websites. This is how.

This is the formula for KLSE:

```
=index(ImportXML("https://klse.i3investor.com/servlets/stk/5099.jsp", "//td[contains(@class, 'big16')]"), 1, 1)
```

And this is for SGX:

```
=index(ImportXML("https://sgx.i3investor.com/servlets/stk/g3b.jsp", "//td[contains(@class, 'big16')]"), 1, 1)
```

Just remember to replace the stock code with whatever you want, the part right before `.jsp`.

### Gold Prices

First, install ImportJSON functions from [https://github.com/bradjasper/ImportJSON](https://github.com/bradjasper/ImportJSON) into your Google Sheets script editor.

Then, you can use this formula to fetch USD per oz:

```
=index(ImportJSON("https://data-asg.goldprice.org/dbXRates/USD", "/items"), 2, 2)
```