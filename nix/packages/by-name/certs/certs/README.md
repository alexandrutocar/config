<!-- spell-checker: ignore cfssl cfssljson initca -->
# Certs

Contains PKI certificates for the local private network (codenamed `intra.net`).

## Hierarchy

```mermaid
flowchart TD
    A0[intra.net®] 
    A0 --> S1(grafana.intra.net.internal)
    A0 --> S2(intra.net.internal)
    A0 --> S3(openbao.intra.net.internal)
    S2 -->|IKEv2/IPSec| C1(Albedo)
    S2 -->|IKEv2/IPSec| C2(Keqing)
```

## Operation

### Authority

To generate an anchor certificate: 

```bash
cfssl gencert -initca anchor/intra.net.jsonc | cfssljson -bare anchor/intra.net
```

### Consumers

To generate (and sign) a client certificate:

```bash
cfssl gencert -ca anchor/intra.net.pem -ca-key anchor/intra.net-key.pem -config profiles.jsonc -profile client client/[name].jsonc | cfssljson -bare client/[name]
```

To generate (and sign) a server certificate:

```bash
cfssl gencert -ca anchor/intra.net.pem -ca-key anchor/intra.net-key.pem -config profiles.jsonc -profile server server/[name].jsonc | cfssljson -bare server/[name]
```

## Quick Actions

### How to delete previously generated certificates and signing requests?

```sh
find . -type f \( -name \*.pem -o -name \*.csr \) -delete
```