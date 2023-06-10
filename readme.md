# Off-The-Record Whisper

![OTRWhisper logo](./img/logo.png)

Off-The-Record Whisper or **OTRWhisper** is a Wow AddOn to provide a _(poorly)_ secure end-to-end encryption on in-game whisper chat messages.

## ⚠️ WARNING

This current state is **insecure** as this is just a PoC!

Just for fun, the asymmetric keys are done using Deffie Hellman key exchange with prime `2147483647` and generator `2`.

The symmetric encryption algorithm for encrypting/decryption the content of a message is done by a simple XOR loop. _(TODO: use something [from this list](https://github.com/philanc/plc#performance))_