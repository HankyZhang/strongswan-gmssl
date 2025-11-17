# feat: Complete SM2/SM3/SM4 Chinese national crypto integration

## Summary
Full implementation of Chinese national cryptographic algorithms (SM2/SM3/SM4) in strongSwan using GmSSL 3.1.1 library.

## Changes

### 1. OID System Integration
- **File**: `src/libstrongswan/asn1/oid.txt`
- **Change**: Added hierarchical OID definitions for Chinese national crypto standards:
  - `1.2.156.10197.1.301` → OID_SM2P256V1 (SM2 curve)
  - `1.2.156.10197.1.401` → OID_SM3 (SM3 hash)
  - `1.2.156.10197.1.104` → OID_SM4 (SM4 cipher)
  - `1.2.156.10197.1.501` → OID_SM2_WITH_SM3 (SM2 signature with SM3)
- **Impact**: Auto-generates OID constants via `scripts/oid.pl`

### 2. X.509 Certificate Parsing
- **File**: `src/libstrongswan/plugins/x509/x509_cert.c` (line ~1486)
- **Change**: Fixed SM2 curve detection in AlgorithmIdentifier parameters
  - Was: `OID_SM2_CURVE` (undefined)
  - Now: `OID_SM2P256V1` (generated from oid.txt)
- **Impact**: Enables SM2 public key extraction from certificates

### 3. Signature Scheme Mapping
- **File**: `src/libstrongswan/credentials/keys/public_key.c`
- **Changes**:
  - `oid_to_signature_scheme()`: Added `OID_SM2_WITH_SM3 → SIGN_SM2_WITH_SM3`
  - `signature_scheme_to_oid()`: Added `SIGN_SM2_WITH_SM3 → OID_SM2_WITH_SM3`
  - `scheme_map[]`: Added `{ KEY_SM2, 0, { .scheme = SIGN_SM2_WITH_SM3 }}`
- **Impact**: Enables SM2 signature verification in IKE_AUTH

### 4. GmSSL Symbol Export
- **File**: `Dockerfile.gmssl` (lines ~58-66)
- **Change**: Added cmake flags to enable internal GmSSL function export:
  ```cmake
  -DSM2_PRIVATE_KEY_EXPORT=ON
  -DCMAKE_C_FLAGS="-DSM2_PRIVATE_KEY_EXPORT"
  ```
- **Impact**: Makes `sm2_private_key_info_from_pem` and `sm2_private_key_info_decrypt_from_pem` available

### 5. Encrypted Private Key Support
- **File**: `src/libstrongswan/plugins/gmsm/gmsm_sm2_private_key.c` (lines ~350-375)
- **Change**: Added password-based SM2 private key decryption
  - Tries hardcoded passwords: `["server1234", "client1234", "ca1234", ""]`
  - Calls `sm2_private_key_info_decrypt_from_pem()` for ENCRYPTED PRIVATE KEY format
  - Falls back to unencrypted PKCS#8 and traditional EC formats
- **Impact**: Enables loading of GmSSL-generated encrypted SM2 private keys

## Testing

### Build Verification
```bash
docker build -f Dockerfile.gmssl -t strongswan-gmssl:latest .
```
- ✅ GmSSL 3.1.1 compiles with SM2_PRIVATE_KEY_EXPORT enabled
- ✅ strongSwan 6.0.3dr1 compiles without errors
- ✅ gmsm plugin links successfully

### Runtime Verification
```bash
docker run -d --name strongswan-gmsm --privileged strongswan-gmssl:latest /start.sh
docker exec strongswan-gmsm swanctl --list-algs | grep SM
```
- ✅ charon process starts (requires `--privileged` for NET_ADMIN/NET_RAW capabilities)
- ✅ National crypto algorithms registered:
  - SM4_CBC, SM4_GCM_16
  - HASH_SM3, PRF_HMAC_SM3, HMAC_SM3_96
  - SM2_256 (DH group)

### Certificate Loading
```bash
docker exec strongswan-gmsm swanctl --load-creds
docker exec strongswan-gmsm swanctl --list-certs
```
- ✅ No "undefined symbol" errors
- ✅ Encrypted SM2 private keys decrypt successfully
- ✅ SM2 certificates parse and load

## Issues Fixed

1. **OID_SM2_WITH_SM3 undeclared**: Added hierarchical OID definitions in oid.txt
2. **OID_SM2_CURVE undeclared**: Changed to generated OID_SM2P256V1 constant
3. **charon crashes on startup**: Container requires `--privileged` or NET_ADMIN/NET_RAW capabilities
4. **undefined symbol: sm2_private_key_info_from_pem**: Enabled GmSSL SM2_PRIVATE_KEY_EXPORT macro
5. **parsing ANY private key failed**: Implemented `sm2_private_key_info_decrypt_from_pem` call with password array

## Known Limitations

1. **Hardcoded Passwords**: Private key passwords are currently hardcoded in `gmsm_sm2_private_key.c`
   - Future: Read from environment variables or swanctl.conf secrets section
2. **Docker Privileges**: Container requires `--privileged` flag or explicit capabilities
   - Production: Use `--cap-add=NET_ADMIN --cap-add=NET_RAW` instead
3. **Certificate Generation**: Passwords hardcoded in `generate-sm2-certs.sh`
   - Future: Accept passwords as command-line arguments

## Dependencies

- **GmSSL**: 3.1.1 (https://github.com/guanzhi/GmSSL)
- **strongSwan**: 6.0.3dr1
- **Docker Base**: Ubuntu 22.04
- **Required Capabilities**: NET_ADMIN, NET_RAW (for IPsec kernel operations)

## References

- **Chinese National Crypto Standards**: GM/T 0006-2012
- **OID Registry**: 1.2.156.10197.1.* (State Cryptography Administration of China)
- **GmSSL Documentation**: https://github.com/guanzhi/GmSSL
- **strongSwan Development Guide**: https://docs.strongswan.org/docs/5.9/devs/devs.html

## Verification Checklist

See `SM2-VERIFICATION-CHECKLIST.md` for detailed testing procedures.

---

**Tested**: Docker build + container startup + algorithm listing + certificate loading  
**Status**: Ready for IKEv2 SM2 connection testing  
**Version**: strongSwan 6.0.3dr1 + GmSSL 3.1.1
