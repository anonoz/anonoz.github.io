---
layout: page
title: "Why AirAsia's BigPay is not that safe"
description: And how to protect yourself better
date: 2020-11-08
category: security
image:
  path: /assets/images/bigpay/bigpay-sms.jpeg
---

![BigPay marketing photo](/assets/images/bigpay/bigpay-marketing.png)

In the past few months, I have received approximately 5-6 WhatsApp scam calls from different numbers, pretending to be from BigPay and Hotlink wanting to give me Covid-19 relief funds distributed by Malaysian government.

I can tell it is the same dude calling me using different numbers, he speaks fluent Malay. When I got the 2nd call onward, I just started trolling him by keep on replying him the wrong 6 digits SMS OTP that they have prompted BigPay to send me. The scammer is more patient than I expected, even after giving him the wrong OTP many times in a row, he did not hang up when I was trolling him.

This got me thinking, why is BigPay being targeted by scammers far more than any other banks out there? There are 2 reasons I am guessing right now:

1. BigPay has only 1 factor of authentication.
2. BigPay uses only English.

### A primer on Factors of Authentication

There are 3 main factors being used right now:

1. **What you know.** Examples: passwords, PIN codes, your mother's maiden name.
2. **What you have.** Examples: handphone to receive SMS one-time password, time-based one time password like Google Authenticator, or Yubikey.
3. **What you are.** Examples: fingerprint, face recognition, iris scans.

The crux is, if somebody has your password to a system, chances are it is not hard for them to also have your PIN code. So having a login flow of asking password and PIN code in a row is not much more secure than just asking for 1 password.

Similarly, if someone gets hold on your credit card, chances are they can get your NRIC without much difficulty. Having a checkout page that asks for credit card numbers and NRIC together won't make much sense.

However, having 2 or 3 factors of authentication together make it significantly tougher for adversaries to gain access to a system. This is why banks often ask for something only you know in your head - password, and something you have in your pocket - a phone that can receive SMS TAC, when we try to complete an outgoing transaction. It is just much much safer.

Unfortunately, BigPay only uses 1 factor of authentication - what you have. This makes them significantly less safe than the big banks they want to challenge against.

### The passcode reset flow

![Pick a country, enter phone number, key in SMS one time password](/assets/images/bigpay/login-flow.png)

A normal login flow on a new device would be:

1. Pick a country.
2. Enter phone number.
3. Wait for SMS OTP on the phone that you have.

![Forgot password](/assets/images/bigpay/forgot-passcode.png)

1. Key in the 6 digits passcode if you remember.
2. But what if you forgot it? Just key in the MyKad NRIC number and your house postcode. Both are available on your MyKad, and your cellular network provider.
3. Tada! You can now reset the passcode.

Unlike other banks in Malaysia, they will first ask for password or biometrics, and they only send out SMS OTP before confirming a transaction. BigPay relies entirely on both your phone and your MyKad - something you tend to bring out together.

Once you logged in, the app has a tab that shows user their primary account number, expiry dates, and the 3-digits card verification codes.

![Card tab showing 16 digits PAN, expiry dates, CVC](/assets/images/bigpay/card-info.png)

### English only

![SMS with 6 digits one time code and "Don't share it with anyone, not even BigPay"](/assets/images/bigpay/bigpay-sms.jpeg)

To BigPay's credit, the one-time password SMS did say "Don't share it with anyone, even BigPay", so why do people still fall for it? 

My guess is they go after the population with weak English grasp.

After switching my phone's language to Malay, the app did not localise and is still in English. If someone is not proficient in English, they might just read the 6 digits blindly as instructed.

BigPay could do better by having us select preferred communication language when we sign up. 

### Do you trust your cellular network provider?

Twitter CEO Jack Dorsey has his Twitter account [hacked with SIM-jacking](https://www.nytimes.com/2019/09/05/technology/sim-swap-jack-dorsey-hack.html). It happens pretty often in the US, but not so much in Malaysia and Singapore. Again, it is a very possible attack scenario.

Our telcos are the weakest links to our BigPay accounts. I will not store more than RM1000 in BigPay once they are a fully fledged digital bank, if they do not incorporate 2FA/3FA in their authentication flow.

### Security advices

When I was living in Singapore back in 2018, I have my entire Maybank account emptied by the iTunes scam. Many people in [Singapore](https://www.channelnewsasia.com/news/singapore/apple-itunes-fraudulent-charges-banks-continue-to-assist-victims-10554658) and [Malaysia](https://www.nst.com.my/news/nation/2020/04/581238/cimb-customers-seek-clarification-direct-debit-transactions) are affected. The transactions are not done by iTunes of course, it was just the fraud syndicate using iTunes as the merchant name on statement. 

Because I did not have a credit card, I just use my ATM debit card daily. It takes about 90 days for the bank to dispute the fraudulent transactions and refund the monies back to my saving account, if I did not have a 2nd bank account, I would not have enough money to survive 4 weeks until the next paycheck.

Hence, as of 2020, I still recommend you to use BigPay debit card over the usual ATM debit cards.

Takeaway advices:

1. Unlink all credit and debit cards from your BigPay account, and top up only thru bank login everytime. Yes it is inconvenient, but it is very important to limit your losses to just the BigPay balance.
2. Deactivate or reduce spending limit to RM0 for all your existing bank ATM cum debit cards. Don't get your bank account emptied.
3. Get a credit card - banks are less likely to authorize fraudulent transactions when it is their money. You do not have to pay the bank once you have submitted your dispute form.
4. Have a 2nd bank account somewhere with 1 month of living expenses.