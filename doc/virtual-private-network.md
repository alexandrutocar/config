# Virtual Private Network

## Albedo

Albedo relies on connectivity with the private network for its DNS and binary cache. In case of an dynamic IP address change affecting Aether, change its endpoint to reflect the change.

```bash
sudo wg set wg-internet peer <public-key> endpoint <new ip address>:51820
```