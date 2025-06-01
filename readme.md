# Off-The-Record Whisper

![OTRWhisper logo](./img/logo.png)

Off-The-Record Whisper or **OTRWhisper** is a Wow AddOn to provide a _(poorly)_ secure end-to-end encryption on in-game whisper chat messages.


## Features

- Off-The-Record communication _(Forward secrecy & Deniable authentication)_
- Block all non-OTR incoming whispers
- User only friendlist as OTR


## Limitations

The 'whispers' are limited to those from players _(no battle.net)_ who are on the same _(connected)_ realm.


## ⚠️ WARNING

This current state is **insecure** as this is just a PoC!

Just for fun, the asymmetric keys are done using Deffie Hellman key exchange with prime `1522605027922533360535618378132637429718068114961380688657908494580122963258952897654000350692006139` and generator `2`. This key exchange is done at every message. The random privkey generator is only using 100 bit keys (lua lag frame, need spread)

Key deriviation is using `md5`⚠ ️but atleast its pure lua xD (TODO: sha256??)

The symmetric encryption algorithm for encrypting/decryption the content of a message is done by a simple XOR loop. _(TODO: use something [from this list](https://github.com/philanc/plc#performance))_