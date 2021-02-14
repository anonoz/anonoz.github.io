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

You can use this formula to approximate USD per oz:

```
=GOOGLEFINANCE("GLD", "price")*10/POW(0.996,YEARFRAC(TODAY(), "18/11/2004", 1))
```

GLD is the ticker for SPDR gold trust ETF, the largest one out there. They charge 0.4% per annum since inception.
