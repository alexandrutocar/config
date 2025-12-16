# Public (Private) Key Infrastructure

## Certificate Authority Management

To generate Certificate Authority Root Certificate:

```bash
cfssl gencert -initca ca.json | cfssljson -bare ca
```

To generate Certificate Authority Intermediate Certificate:

```bash
cfssl genkey -profile inter --config profiles.jsonc -initca ca/inter/int0.jsonc  | cfssljson -bare ca/inter/int0
```

To generate Signed Server Certificate:

```bash
cfssl gencert -ca ca/inter/int0.pem -ca-key ca/inter/int0-key.pem -config profiles.jsonc -profile server ca/server/aether.ip.jsonc | cfssljson -bare ca/server/aether.ip
```

To generate Signed Client Certificate (used for mTLS):

```bash
cfssl gencert -ca ca/inter/int0.pem -ca-key ca/inter/int0-key.pem -config profiles.jsonc -profile client ca/client/alex@aether.ip.jsonc | cfssljson -bare ca/client/alex@aether.ip
```

## Certificate Profiles for Apple Devices

Configuration Profile Reference is available [here](https://developer.apple.com/business/documentation/Configuration-Profile-Reference.pdf).

Mobile configuration require this specific encoding, and line-length for certificates:

```bash
openssl x509 -outform der -in x0.pem | base64 | fold -w 52 > x0.der.b64
```

```bash
openssl x509 -outform der -in int0.pem | base64 | fold -w 52 > int0.der.b64
```
