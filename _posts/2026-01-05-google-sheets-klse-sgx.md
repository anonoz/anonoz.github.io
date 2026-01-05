---
layout: post
title: "How to retrieve KLSE, SGX, and gold prices in Google Sheets (Updated for 2026Q1)"
date: 2026-01-05
category: finance
redirect_from:
  - /finance/2022/02/28/google-sheets-klse-sgx.html
---

For Bursa Malaysia (KLSE) and Singapore Exchange (SGX), we can scrape from some other websites websites like growbeansprout and klsescreener. This is how.

### KLSE & SGX

This is the new formula for KLSE after the site revamp, replace 5176 with whatever ticker you want:

```
=IMPORTXML("https://www.klsescreener.com/v2/stocks/view/5176, "//*[@id='price']")
```

And this is for SGX, just replace the stock code (e.g. `G3B`, `CFA`) with whatever ticker you want:

```
=IMPORTXML("https://growbeansprout.com/quote/G3B.SI", "//p[@class='text-3xl font-medium']")
```

### Gold Prices

You can use this formula to approximate USD per oz:

```
=GOOGLEFINANCE("GLD", "price")*10/POW(0.996,YEARFRAC(TODAY(), "18/11/2004", 1))
```

GLD is the ticker for SPDR gold trust ETF, the largest one out there. They charge 0.4% per annum since inception.

### Changelogs

2025: i3investor started blocking bots, so I switched to use other websites suggested by ChatGPT.
