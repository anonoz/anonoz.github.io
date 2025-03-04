---
layout: post
title: "How to retrieve KLSE, SGX, and gold prices in Google Sheets (Updated for 2025Q1)"
date: 2022-02-28
category: finance
---

For Bursa Malaysia (KLSE) and Singapore Exchange (SGX), we can scrape from some other websites websites like growbeansprout and klsescreener. This is how.

### KLSE & SGX

This is the new formula for KLSE after the site revamp:

```
=IMPORTXML("https://www.klsescreener.com/v2/stocks/view/5176?utm_source="&Settings!B4, "//*[@id='price']")
```

And this is for SGX, assuming column A contains your stock code:

```
=IMPORTXML("https://growbeansprout.com/quote/G3B.SI/", "/html/body/div[1]/main/div[1]/div/div[1]/div[1]/section/div[2]/p[1]")
```

Just remember to replace the stock code with whatever you want, the part right before `.jsp`.

### Gold Prices

You can use this formula to approximate USD per oz:

```
=GOOGLEFINANCE("GLD", "price")*10/POW(0.996,YEARFRAC(TODAY(), "18/11/2004", 1))
```

GLD is the ticker for SPDR gold trust ETF, the largest one out there. They charge 0.4% per annum since inception.

### Changelogs

2025: i3investor started blocking bots, so I switched to use other websites suggested by ChatGPT.