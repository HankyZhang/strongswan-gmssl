# strongSwan原始加密算法调用流程图（未修改版本）

## 完整的IKE/ESP协商和数据传输流程

### 1. 总体架构流程

```
┌─────────────────────────────────────────────────────────────────────┐
│                    IKE_SA_INIT 阶段                                  │
│                 (协商加密算法和密钥交换)                               │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  1. 发起方准备提案列表                      │
        │  src/libcharon/sa/ikev2/tasks/ike_init.c   │
        │  build_payloads() 第340行                  │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  2. 加载配置的算法提案                      │
        │  ike_cfg->get_proposals(ike_cfg)           │
        │  读取: aes256-sha256-modp2048              │
        │  └─ ENCR_AES_CBC (256位)                   │
        │  └─ AUTH_HMAC_SHA2_256_128                 │
        │  └─ PRF_HMAC_SHA2_256                      │
        │  └─ MODP_2048                              │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  3. 发送IKE_SA_INIT请求                    │
        │  包含SA载荷（多个提案）                     │
        │  SA Payload:                               │
        │    Proposal 1: aes256-sha256-modp2048      │
        │    Proposal 2: aes128-sha256-modp2048      │
        │    Proposal 3: aes256-sha1-modp1536        │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  4. 响应方选择提案                          │
        │  src/libcharon/sa/ikev2/tasks/ike_init.c   │
        │  process_sa_payload() 第490行              │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  5. 算法提案选择（核心）                    │
        │  src/libcharon/config/ike_cfg.c            │
        │  select_proposal() 第361行                 │
        │    └→ proposal_select()                    │
        │       src/libstrongswan/crypto/proposal/   │
        │       proposal.c 第1430行                  │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  提案选择算法详解：                         │
        │                                            │
        │  for each 本地配置的提案:                  │
        │    for each 对端发送的提案:                │
        │      比较各种算法类型:                     │
        │        ✓ ENCRYPTION_ALGORITHM              │
        │        ✓ INTEGRITY_ALGORITHM               │
        │        ✓ PSEUDO_RANDOM_FUNCTION            │
        │        ✓ KEY_EXCHANGE_METHOD               │
        │      if 所有类型都匹配:                    │
        │        return 匹配的提案                   │
        │  return NULL (协商失败)                    │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  6. 选中提案示例                            │
        │  selected proposal:                        │
        │    ENCR_AES_CBC (256位)                    │
        │    AUTH_HMAC_SHA2_256_128                  │
        │    PRF_HMAC_SHA2_256                       │
        │    MODP_2048                               │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  7. 创建密码算法实例                        │
        │  src/libcharon/sa/ikev2/keymat_v2.c        │
        │  derive_ike_keys() 第240行                 │
        └────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────────────┐
│  算法实例化过程（使用crypto_factory）                                  │
├───────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  this->prf_alg = proposal->get_algorithm(                            │
│                      proposal, PSEUDO_RANDOM_FUNCTION, ...);          │
│  // prf_alg = PRF_HMAC_SHA2_256                                      │
│                                                                       │
│  this->prf = lib->crypto->create_prf(lib->crypto, this->prf_alg);    │
│  // 调用crypto_factory创建PRF实例                                    │
│  └→ src/libstrongswan/crypto/crypto_factory.c                        │
│     create_prf() 第580行                                             │
│       └→ 查找已注册的PRF构造函数                                      │
│          for each plugin (openssl, gcrypt, ...):                     │
│            if plugin->create_prf(PRF_HMAC_SHA2_256):                 │
│              return prf实例                                          │
│                                                                       │
│  // 如果使用OpenSSL插件：                                             │
│  └→ src/libstrongswan/plugins/openssl/openssl_hmac.c                 │
│     openssl_hmac_create() 第200行                                    │
│       └→ 调用OpenSSL库: HMAC_Init_ex(..., EVP_sha256(), ...)         │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────────────┐
│  类似创建其他算法实例：                                                │
│                                                                       │
│  1. 加密器 (Crypter)                                                  │
│     enc_alg = ENCR_AES_CBC, enc_size = 256                           │
│     crypter = lib->crypto->create_crypter(lib->crypto, enc_alg,      │
│                                            enc_size);                 │
│     └→ openssl_crypter_create()                                      │
│        └→ EVP_CIPHER_CTX_new()                                       │
│           EVP_CipherInit_ex(..., EVP_aes_256_cbc(), ...)             │
│                                                                       │
│  2. 完整性算法 (Signer)                                               │
│     int_alg = AUTH_HMAC_SHA2_256_128                                 │
│     signer = lib->crypto->create_signer(lib->crypto, int_alg);       │
│     └→ openssl_hmac_create()                                         │
│        └→ HMAC_Init_ex(..., EVP_sha256(), ...)                       │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  8. DH密钥交换                              │
        │  lib->crypto->create_ke(lib->crypto,       │
        │                         MODP_2048)         │
        │  └→ 生成DH公钥/私钥对                       │
        │     计算共享密钥 g^(ab) mod p              │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  9. 密钥派生（使用PRF-HMAC-SHA256）         │
        │  keymat_v2.c::derive_ike_keys() 第330行    │
        └────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────────────┐
│  密钥派生详细过程：                                                    │
│                                                                       │
│  // 步骤1: 计算SKEYSEED                                               │
│  SKEYSEED = prf(Ni | Nr, g^ir)                                       │
│                                                                       │
│  prf = lib->crypto->create_kdf(lib->crypto, KDF_PRF,                 │
│                                 PRF_HMAC_SHA2_256);                   │
│  prf->set_param(prf, KDF_PARAM_KEY, nonce_concat);  // Ni | Nr       │
│  prf->set_param(prf, KDF_PARAM_SALT, dh_secret);    // g^ir          │
│  prf->get_bytes(prf, key_size, &skeyseed);                           │
│  // 调用OpenSSL: HMAC(EVP_sha256(), key=Ni|Nr, data=g^ir)            │
│                                                                       │
│  // 步骤2: 使用PRF+派生所有密钥                                        │
│  prf_plus = lib->crypto->create_kdf(lib->crypto, KDF_PRF_PLUS,       │
│                                      PRF_HMAC_SHA2_256);              │
│  prf_plus->set_param(prf_plus, KDF_PARAM_KEY, skeyseed);             │
│  prf_plus->set_param(prf_plus, KDF_PARAM_SALT, seed);                │
│  // seed = Ni | Nr | SPIi | SPIr                                     │
│                                                                       │
│  // 派生密钥材料                                                      │
│  keymat.len = 3 * key_size  // SK_d, SK_pi, SK_pr                   │
│              + sk_ai.len    // SK_ai (HMAC-SHA256 密钥32字节)         │
│              + sk_ar.len    // SK_ar (HMAC-SHA256 密钥32字节)         │
│              + sk_ei.len    // SK_ei (AES-256 密钥32字节)            │
│              + sk_er.len;   // SK_er (AES-256 密钥32字节)            │
│                                                                       │
│  prf_plus->allocate_bytes(prf_plus, keymat.len, &keymat);            │
│  // PRF+(SKEYSEED, seed) 使用HMAC-SHA256迭代生成足够长度的密钥材料    │
│  // T1 = HMAC-SHA256(SKEYSEED, seed | 0x01)                          │
│  // T2 = HMAC-SHA256(SKEYSEED, T1 | seed | 0x02)                     │
│  // T3 = HMAC-SHA256(SKEYSEED, T2 | seed | 0x03)                     │
│  // ...                                                              │
│  // keymat = T1 | T2 | T3 | ...                                     │
│                                                                       │
│  // 步骤3: 分割密钥材料                                               │
│  chunk_split(keymat, "ammmmaa",                                      │
│      key_size, &this->skd,      // SK_d: 用于ESP密钥派生 (32字节)    │
│      sk_ai.len, &sk_ai,         // SK_ai: IKE完整性(发起方) (32字节) │
│      sk_ar.len, &sk_ar,         // SK_ar: IKE完整性(响应方) (32字节) │
│      sk_ei.len, &sk_ei,         // SK_ei: IKE加密(发起方) (32字节)   │
│      sk_er.len, &sk_er,         // SK_er: IKE加密(响应方) (32字节)   │
│      key_size, &sk_pi,          // SK_pi: 认证(发起方) (32字节)      │
│      key_size, &sk_pr);         // SK_pr: 认证(响应方) (32字节)      │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  10. 设置IKE加密/完整性密钥                 │
        │  aead_i->set_key(sk_ai | sk_ei)            │
        │  aead_r->set_key(sk_ar | sk_er)            │
        │                                            │
        │  OpenSSL调用：                             │
        │  EVP_CipherInit_ex(ctx, EVP_aes_256_cbc(), │
        │                    ..., sk_ei, ...)        │
        │  HMAC_Init_ex(ctx, EVP_sha256(),           │
        │               sk_ai, 32)                   │
        └────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    IKE_AUTH 阶段                                     │
│                  (身份认证和授权)                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  11. 计算认证数据                           │
        │  src/libcharon/sa/ikev2/authenticators/    │
        │  pubkey_authenticator.c                    │
        │  build() 第310行                           │
        └────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────────────┐
│  认证数据生成过程：                                                    │
│                                                                       │
│  // 1. 选择签名方案                                                   │
│  select_signature_schemes(keymat, auth, private_key)                 │
│  └→ 如果是RSA密钥: SIGN_RSA_EMSA_PKCS1_SHA2_256                       │
│  └→ 如果是ECDSA密钥: SIGN_ECDSA_256/384/521                          │
│                                                                       │
│  // 2. 计算待签名数据（使用PRF-HMAC-SHA256）                          │
│  keymat->get_auth_octets(keymat, FALSE,                              │
│                          ike_sa_init, nonce, ..., &octets);          │
│  └→ prf->set_key(prf, SK_p)                                          │
│     prf->allocate_bytes(prf, id_data, &id_hash)                      │
│     octets = ike_sa_init | nonce | prf(SK_p, IDi')                  │
│     // 调用OpenSSL: HMAC(EVP_sha256(), SK_pi, IDi')                  │
│                                                                       │
│  // 3. 对octets进行哈希（如果签名方案需要）                           │
│  hasher = lib->crypto->create_hasher(lib->crypto, HASH_SHA256);      │
│  hasher->get_hash(hasher, octets, hash);                             │
│  // 调用OpenSSL: EVP_DigestInit_ex(..., EVP_sha256(), ...)           │
│  //              EVP_DigestUpdate(...)                               │
│  //              EVP_DigestFinal_ex(...)                             │
│                                                                       │
│  // 4. 使用私钥签名                                                   │
│  private->sign(private, SIGN_RSA_EMSA_PKCS1_SHA2_256,                │
│                NULL, octets, &signature)                             │
│  └→ src/libstrongswan/plugins/openssl/                               │
│     openssl_rsa_private_key.c 第250行                                │
│     └→ RSA_sign(NID_sha256, hash, hash_len, sig, ...)                │
│        // 调用OpenSSL: RSA-PKCS1签名                                 │
│        // 或 ECDSA_sign(0, hash, hash_len, sig, ...)                 │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  12. 发送AUTH载荷                           │
        │  包含签名数据                               │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  13. 对端验证签名                           │
        │  pubkey_authenticator.c                    │
        │  process() 第570行                         │
        └────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────────────┐
│  签名验证过程：                                                        │
│                                                                       │
│  // 1. 加载对端公钥（从证书）                                         │
│  public = lib->credmgr->create_public_enumerator(...)                │
│                                                                       │
│  // 2. 验证证书链（使用SHA256哈希）                                   │
│  src/libstrongswan/plugins/x509/x509_cert.c                          │
│  issued_by() 第1718行                                                │
│  └→ key->verify(key, SIGN_RSA_EMSA_PKCS1_SHA2_256,                   │
│                 NULL, tbsCertificate, signature)                     │
│     └→ openssl_rsa_public_key.c                                      │
│        └→ RSA_verify(NID_sha256, hash, hash_len,                     │
│                      sig, sig_len, rsa)                              │
│           // 先SHA256哈希tbsCertificate                              │
│           // 再RSA验证签名                                           │
│                                                                       │
│  // 3. 验证AUTH载荷的签名                                             │
│  keymat->get_auth_octets(keymat, TRUE, ..., &octets);                │
│  // 计算待验证数据（同发送方）                                        │
│                                                                       │
│  public->verify(public, SIGN_RSA_EMSA_PKCS1_SHA2_256,                │
│                 NULL, octets, signature)                             │
│  └→ RSA_verify(NID_sha256, hash, hash_len, sig, ...)                 │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                  CREATE_CHILD_SA 阶段                                │
│                  (建立ESP安全关联)                                    │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  14. ESP提案协商                            │
        │  类似IKE提案选择                            │
        │  选中: aes256-sha256                       │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  15. ESP密钥派生                            │
        │  keymat_v2.c::derive_child_keys() 第540行  │
        └────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────────────┐
│  ESP密钥派生过程：                                                     │
│                                                                       │
│  // 使用存储的SK_d和PRF-HMAC-SHA256                                   │
│  prf_plus = lib->crypto->create_kdf(lib->crypto, KDF_PRF_PLUS,       │
│                                      PRF_HMAC_SHA2_256);              │
│  prf_plus->set_param(prf_plus, KDF_PARAM_KEY, this->skd);            │
│  // this->skd 是IKE_SA_INIT阶段派生的SK_d                             │
│                                                                       │
│  seed = [dh_secret] | nonce_i | nonce_r                              │
│  // dh_secret: 如果使用PFS (Perfect Forward Secrecy)                 │
│  prf_plus->set_param(prf_plus, KDF_PARAM_SALT, seed);                │
│                                                                       │
│  // 派生ESP密钥                                                       │
│  keymat.len = 2 * enc_size + 2 * int_size                            │
│             = 2 * 32 + 2 * 32  // AES-256 + HMAC-SHA256              │
│             = 128 字节                                                │
│                                                                       │
│  prf_plus->allocate_bytes(prf_plus, keymat.len, &keymat);            │
│  // PRF+(SK_d, Ni | Nr) 使用HMAC-SHA256                              │
│                                                                       │
│  chunk_split(keymat, "aaaa",                                         │
│      enc_size, &encr_i,      // ESP加密密钥(发起方→响应方) (32字节)  │
│      int_size, &integ_i,     // ESP完整性密钥(发起方→响应方) (32字节)│
│      enc_size, &encr_r,      // ESP加密密钥(响应方→发起方) (32字节)  │
│      int_size, &integ_r);    // ESP完整性密钥(响应方→发起方) (32字节)│
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  16. 创建ESP上下文                          │
        │  设置加密/完整性密钥                        │
        │  crypter->set_key(encr_i)                  │
        │  signer->set_key(integ_i)                  │
        └────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────────┐
│                    ESP数据传输阶段                                    │
│              (实际IP数据包的加密和完整性保护)                          │
└─────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  17. ESP加密（发送数据包）                  │
        │  src/libipsec/esp_packet.c                 │
        │  encrypt() 第289行                         │
        └────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────────────┐
│  ESP加密详细流程：                                                     │
│                                                                       │
│  // 1. 获取AEAD对象（包含crypter和signer）                            │
│  aead = esp_context->get_aead(esp_context);                          │
│  // aead内部包含：                                                    │
│  //   - crypter: AES-256-CBC加密器                                   │
│  //   - signer: HMAC-SHA256签名器                                    │
│  //   - iv_gen: IV生成器                                             │
│                                                                       │
│  // 2. 获取IV                                                         │
│  iv_gen = aead->get_iv_gen(aead);                                    │
│  iv_gen->get_iv(iv_gen, seq, iv.len, iv.ptr);                       │
│  // 生成16字节随机IV（用于AES-CBC）                                   │
│                                                                       │
│  // 3. 构造ESP数据包                                                  │
│  //    [SPI(4)] [Seq(4)] [IV(16)] [加密数据] [ICV(16)]               │
│  writer->write_uint32(writer, spi);                                  │
│  writer->write_uint32(writer, seq);                                  │
│  writer->write_data(writer, iv);                                     │
│                                                                       │
│  // 4. 准备明文                                                       │
│  plaintext = [IP数据包] [padding] [pad_len(1)] [next_header(1)]     │
│  // padding使数据长度是16字节（AES块大小）的倍数                      │
│                                                                       │
│  // 5. AES-CBC加密                                                    │
│  aad = chunk_create(data.ptr, 8);  // AAD = SPI + Seq                │
│  aead->encrypt(aead, plaintext, aad, iv, &icv);                      │
│  └→ crypter->encrypt(crypter, plaintext, iv, &ciphertext)            │
│     └→ openssl_crypter.c                                             │
│        └→ EVP_EncryptInit_ex(ctx, EVP_aes_256_cbc(), NULL,           │
│                              NULL, iv.ptr)                            │
│           EVP_EncryptUpdate(ctx, out, &len, in, in_len)              │
│           EVP_EncryptFinal_ex(ctx, out+len, &len)                    │
│           // OpenSSL AES-256-CBC加密                                 │
│                                                                       │
│  // 6. 计算HMAC-SHA256                                                │
│  └→ signer->get_signature(signer, data, icv.ptr)                     │
│     └→ openssl_hmac.c                                                │
│        └→ HMAC_Init_ex(ctx, integ_key, 32, EVP_sha256(), NULL)       │
│           HMAC_Update(ctx, spi_seq, 8)    // AAD                     │
│           HMAC_Update(ctx, iv, 16)                                   │
│           HMAC_Update(ctx, ciphertext, len)                          │
│           HMAC_Final(ctx, icv, &icv_len)                             │
│           // 生成32字节HMAC，取前16字节                               │
│                                                                       │
│  // 7. 组装最终ESP包                                                  │
│  [SPI][Seq][IV][密文][ICV(16)]                                       │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  18. 发送加密的ESP数据包                    │
        │  通过网络发送                               │
        └────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  19. ESP解密（接收数据包）                  │
        │  esp_packet.c::decrypt() 第228行           │
        └────────────────────────────────────────────┘
                              ↓
┌───────────────────────────────────────────────────────────────────────┐
│  ESP解密详细流程：                                                     │
│                                                                       │
│  // 1. 解析ESP头部                                                    │
│  reader->read_uint32(reader, &spi);                                  │
│  reader->read_uint32(reader, &seq);                                  │
│  reader->read_data(reader, 16, &iv);                                 │
│  reader->read_data_end(reader, 16, &icv);                            │
│  ciphertext = reader->peek(reader);  // 剩余的就是密文               │
│                                                                       │
│  // 2. 验证序列号（防重放）                                           │
│  esp_context->verify_seqno(esp_context, seq);                        │
│                                                                       │
│  // 3. 验证HMAC-SHA256                                                │
│  aad = chunk_create(data.ptr, 8);  // SPI + Seq                      │
│  signer->verify_signature(signer,                                    │
│      chunk_cat("ccc", aad, iv, ciphertext), icv);                    │
│  └→ openssl_hmac.c                                                   │
│     └→ HMAC_Init_ex(ctx, integ_key, 32, EVP_sha256(), NULL)          │
│        HMAC_Update(ctx, spi_seq, 8)                                  │
│        HMAC_Update(ctx, iv, 16)                                      │
│        HMAC_Update(ctx, ciphertext, len)                             │
│        HMAC_Final(ctx, computed_icv, &len)                           │
│        return memcmp(icv, computed_icv, 16) == 0                     │
│        // 如果ICV不匹配，返回FAILED，丢弃数据包                       │
│                                                                       │
│  // 4. AES-CBC解密（仅在ICV验证通过后）                               │
│  crypter->decrypt(crypter, ciphertext, iv, &plaintext);              │
│  └→ openssl_crypter.c                                                │
│     └→ EVP_DecryptInit_ex(ctx, EVP_aes_256_cbc(), NULL,              │
│                           NULL, iv.ptr)                               │
│        EVP_DecryptUpdate(ctx, out, &len, in, in_len)                 │
│        EVP_DecryptFinal_ex(ctx, out+len, &len)                       │
│        // OpenSSL AES-256-CBC解密                                    │
│                                                                       │
│  // 5. 移除填充                                                       │
│  pad_len = plaintext.ptr[plaintext.len - 2];                         │
│  next_header = plaintext.ptr[plaintext.len - 1];                     │
│  plaintext.len -= (pad_len + 2);                                     │
│                                                                       │
│  // 6. 提取原始IP数据包                                               │
│  ip_packet = ip_packet_create(plaintext);                            │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
                              ↓
        ┌────────────────────────────────────────────┐
        │  20. 传递给网络栈                           │
        │  原始IP数据包送往上层处理                   │
        └────────────────────────────────────────────┘
```

---

## 2. 算法提案选择详细流程

```
┌─────────────────────────────────────────────────────────────────────┐
│  提案选择算法 (proposal_select)                                      │
│  src/libstrongswan/crypto/proposal/proposal.c 第1430行              │
└─────────────────────────────────────────────────────────────────────┘

输入：
  - configured: 本地配置的提案列表
    例如: [aes256-sha256-modp2048, aes128-sha256-modp2048, aes128-sha1-modp1536]
  
  - supplied: 对端发送的提案列表
    例如: [aes256-sha384-ecp256, aes256-sha256-modp2048, aes128-sha1-modp1536]
  
  - flags: 选择标志
    PROPOSAL_PREFER_SUPPLIED: 优先使用对端的提案顺序
    PROPOSAL_SKIP_PRIVATE: 跳过私有算法（>= 1024）

算法流程：

1. 确定遍历顺序
   if (flags & PROPOSAL_PREFER_SUPPLIED):
       prefer_list = supplied      // 优先级列表
       match_list = configured      // 匹配列表
   else:
       prefer_list = configured     // 默认：优先本地配置
       match_list = supplied

2. 双层循环匹配
   for each proposal in prefer_list:
       for each match in match_list:
           
           // 调用 proposal->select(proposal, match, flags)
           // └→ src/libstrongswan/crypto/proposal/proposal.c 第484行
           
           selected = select_algos(proposal, match)
           
           if (selected != NULL):
               return selected  // 找到匹配，立即返回
   
   return NULL  // 没有找到匹配的提案

3. select_algos() 算法匹配过程
   // src/libstrongswan/crypto/proposal/proposal.c 第419行
   
   // 获取两个提案的所有算法类型
   types = merge_types(proposal, match)
   // 例如: [ENCRYPTION_ALGORITHM, INTEGRITY_ALGORITHM, 
   //        PSEUDO_RANDOM_FUNCTION, KEY_EXCHANGE_METHOD]
   
   for each type in types:
       
       // 对每种算法类型，找到匹配的算法
       if (!select_algo(proposal, match, type, flags, &alg, &ks)):
           return FALSE  // 某个类型没有匹配，提案不兼容
       
       if (alg != 0):
           selected->add_algorithm(selected, type, alg, ks)
   
   return TRUE  // 所有类型都匹配

4. select_algo() 单个算法类型匹配
   // src/libstrongswan/crypto/proposal/proposal.c 第318行
   
   // 获取proposal中type类型的所有算法
   e1 = proposal->create_enumerator(proposal, type)
   // 例如type=ENCRYPTION_ALGORITHM: [ENCR_AES_CBC_256, ENCR_AES_CBC_128]
   
   // 获取match中type类型的所有算法
   e2 = match->create_enumerator(match, type)
   // 例如: [ENCR_AES_CBC_256, ENCR_AES_CBC_192]
   
   // 双层循环查找匹配
   while (e1->enumerate(e1, &alg1, &ks1)):
       e2->reset()
       while (e2->enumerate(e2, &alg2, &ks2)):
           if (alg1 == alg2 && ks1 == ks2):
               
               // 检查是否跳过私有算法
               if ((flags & PROPOSAL_SKIP_PRIVATE) && alg1 >= 1024):
                   continue  // 跳过私有算法
               
               *alg = alg1
               *ks = ks1
               return TRUE  // 找到匹配
   
   return FALSE  // 没有匹配的算法
```

### 示例：具体的提案匹配过程

```
配置的提案（本地）：
  Proposal 1: aes256-sha256-modp2048
    - ENCR_AES_CBC (256位)
    - AUTH_HMAC_SHA2_256_128
    - PRF_HMAC_SHA2_256
    - MODP_2048

  Proposal 2: aes128-sha256-modp2048
    - ENCR_AES_CBC (128位)
    - AUTH_HMAC_SHA2_256_128
    - PRF_HMAC_SHA2_256
    - MODP_2048

接收的提案（对端）：
  Proposal 1: aes256-sha384-ecp256
    - ENCR_AES_CBC (256位)
    - AUTH_HMAC_SHA2_384_192
    - PRF_HMAC_SHA2_384
    - ECP_256

  Proposal 2: aes256-sha256-modp2048
    - ENCR_AES_CBC (256位)
    - AUTH_HMAC_SHA2_256_128
    - PRF_HMAC_SHA2_256
    - MODP_2048

匹配过程：

第1轮：配置提案1 vs 接收提案1
  ✓ ENCRYPTION: ENCR_AES_CBC(256) == ENCR_AES_CBC(256) ✓
  ✗ INTEGRITY: AUTH_HMAC_SHA2_256_128 != AUTH_HMAC_SHA2_384_192 ✗
  → 不匹配，继续

第2轮：配置提案1 vs 接收提案2
  ✓ ENCRYPTION: ENCR_AES_CBC(256) == ENCR_AES_CBC(256) ✓
  ✓ INTEGRITY: AUTH_HMAC_SHA2_256_128 == AUTH_HMAC_SHA2_256_128 ✓
  ✓ PRF: PRF_HMAC_SHA2_256 == PRF_HMAC_SHA2_256 ✓
  ✓ KE: MODP_2048 == MODP_2048 ✓
  → 匹配成功！

选中的提案：
  - ENCR_AES_CBC (256位)
  - AUTH_HMAC_SHA2_256_128
  - PRF_HMAC_SHA2_256
  - MODP_2048

日志输出：
  DBG2(DBG_CFG, "received proposals: IKE:AES_CBC_256/HMAC_SHA2_384_192/..., 
                                     IKE:AES_CBC_256/HMAC_SHA2_256_128/...")
  DBG2(DBG_CFG, "configured proposals: IKE:AES_CBC_256/HMAC_SHA2_256_128/..., 
                                       IKE:AES_CBC_128/HMAC_SHA2_256_128/...")
  DBG1(DBG_CFG, "selected proposal: IKE:AES_CBC_256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/MODP_2048")
```

---

## 3. crypto_factory工作原理

```
┌─────────────────────────────────────────────────────────────────────┐
│  crypto_factory - 算法工厂模式                                       │
│  src/libstrongswan/crypto/crypto_factory.c                          │
└─────────────────────────────────────────────────────────────────────┘

插件注册阶段（启动时）：

1. 加载插件
   plugin_loader->load_plugins(plugin_loader, "openssl gcrypt ...")
   
2. 每个插件注册算法构造函数
   // 例如：openssl插件
   // src/libstrongswan/plugins/openssl/openssl_plugin.c
   
   METHOD(plugin_t, get_features, int,
       private_openssl_plugin_t *this, plugin_feature_t *features[])
   {
       static plugin_feature_t f[] = {
           // 注册加密器
           PLUGIN_REGISTER(CRYPTER, openssl_crypter_create),
               PLUGIN_PROVIDE(CRYPTER, ENCR_AES_CBC, 16),
               PLUGIN_PROVIDE(CRYPTER, ENCR_AES_CBC, 24),
               PLUGIN_PROVIDE(CRYPTER, ENCR_AES_CBC, 32),
               PLUGIN_PROVIDE(CRYPTER, ENCR_3DES, 24),
           
           // 注册哈希器
           PLUGIN_REGISTER(HASHER, openssl_hasher_create),
               PLUGIN_PROVIDE(HASHER, HASH_SHA1),
               PLUGIN_PROVIDE(HASHER, HASH_SHA256),
               PLUGIN_PROVIDE(HASHER, HASH_SHA384),
               PLUGIN_PROVIDE(HASHER, HASH_SHA512),
           
           // 注册PRF
           PLUGIN_REGISTER(PRF, openssl_hmac_prf_create),
               PLUGIN_PROVIDE(PRF, PRF_HMAC_SHA1),
               PLUGIN_PROVIDE(PRF, PRF_HMAC_SHA2_256),
               PLUGIN_PROVIDE(PRF, PRF_HMAC_SHA2_384),
           
           // ... 更多算法
       };
       *features = f;
       return countof(f);
   }

3. crypto_factory维护构造函数列表
   // 内部数据结构
   struct private_crypto_factory_t {
       hashtable_t *crypters;      // 加密器构造函数表
       hashtable_t *hashers;       // 哈希器构造函数表
       hashtable_t *prfs;          // PRF构造函数表
       hashtable_t *signers;       // 签名器构造函数表
       // ...
   };
   
   // 注册过程
   add_algorithm(this->crypters, ENCR_AES_CBC, 
                 openssl_crypter_create, "openssl");

运行时创建算法实例：

1. 请求创建加密器
   crypter = lib->crypto->create_crypter(lib->crypto, 
                                         ENCR_AES_CBC, 32);
   
2. crypto_factory查找构造函数
   METHOD(crypto_factory_t, create_crypter, crypter_t*,
       private_crypto_factory_t *this, 
       encryption_algorithm_t algo, size_t key_size)
   {
       enumerator_t *enumerator;
       entry_t *entry;
       crypter_t *crypter = NULL;
       
       // 从哈希表中查找
       enumerator = this->crypters->create_enumerator(this->crypters);
       while (enumerator->enumerate(enumerator, NULL, &entry))
       {
           if (entry->algo == algo)
           {
               // 找到构造函数，调用创建实例
               crypter = entry->create(algo, key_size);
               if (crypter)
               {
                   break;  // 成功创建，返回
               }
           }
       }
       enumerator->destroy(enumerator);
       
       return crypter;
   }

3. 调用插件的构造函数
   // openssl_crypter_create()
   // src/libstrongswan/plugins/openssl/openssl_crypter.c
   
   crypter_t *openssl_crypter_create(encryption_algorithm_t algo,
                                      size_t key_size)
   {
       private_openssl_crypter_t *this;
       
       INIT(this,
           .public = {
               .encrypt = _encrypt,
               .decrypt = _decrypt,
               .get_block_size = _get_block_size,
               .get_iv_size = _get_iv_size,
               .get_key_size = _get_key_size,
               .set_key = _set_key,
               .destroy = _destroy,
           },
           .algorithm = algo,
           .key_size = key_size,
       );
       
       // 选择OpenSSL的EVP cipher
       switch (algo)
       {
           case ENCR_AES_CBC:
               switch (key_size)
               {
                   case 16:
                       this->cipher = EVP_aes_128_cbc();
                       break;
                   case 24:
                       this->cipher = EVP_aes_192_cbc();
                       break;
                   case 32:
                       this->cipher = EVP_aes_256_cbc();
                       break;
               }
               break;
           // ... 其他算法
       }
       
       // 初始化OpenSSL上下文
       this->ctx = EVP_CIPHER_CTX_new();
       
       return &this->public;
   }
```

---

## 4. 关键数据结构

### proposal_t (算法提案)

```c
struct proposal_t {
    protocol_id_t protocol;     // PROTO_IKE, PROTO_ESP, PROTO_AH
    uint8_t number;             // 提案编号
    uint64_t spi;               // SPI
    
    // 算法列表（按类型分组）
    // 例如：
    // ENCRYPTION_ALGORITHM: [ENCR_AES_CBC_256, ENCR_AES_CBC_128]
    // INTEGRITY_ALGORITHM: [AUTH_HMAC_SHA2_256_128]
    // PSEUDO_RANDOM_FUNCTION: [PRF_HMAC_SHA2_256]
    // KEY_EXCHANGE_METHOD: [MODP_2048]
    
    // 方法
    void (*add_algorithm)(proposal_t *this, transform_type_t type,
                         uint16_t alg, uint16_t key_size);
    enumerator_t* (*create_enumerator)(proposal_t *this,
                                        transform_type_t type);
    proposal_t* (*select)(proposal_t *this, proposal_t *other,
                         proposal_selection_flag_t flags);
};
```

### crypter_t (加密器接口)

```c
struct crypter_t {
    bool (*encrypt)(crypter_t *this, chunk_t data, chunk_t iv,
                    chunk_t *encrypted);
    bool (*decrypt)(crypter_t *this, chunk_t data, chunk_t iv,
                    chunk_t *decrypted);
    size_t (*get_block_size)(crypter_t *this);
    size_t (*get_iv_size)(crypter_t *this);
    size_t (*get_key_size)(crypter_t *this);
    bool (*set_key)(crypter_t *this, chunk_t key);
    void (*destroy)(crypter_t *this);
};
```

### hasher_t (哈希器接口)

```c
struct hasher_t {
    bool (*get_hash)(hasher_t *this, chunk_t chunk, uint8_t *hash);
    bool (*allocate_hash)(hasher_t *this, chunk_t chunk, chunk_t *hash);
    size_t (*get_hash_size)(hasher_t *this);
    bool (*reset)(hasher_t *this);
    void (*destroy)(hasher_t *this);
};
```

---

## 5. 总结

这个流程图展示了strongSwan原始代码中的算法调用流程：

1. **提案选择**：通过双层循环匹配本地和对端提案
2. **算法实例化**：通过crypto_factory的工厂模式创建算法实例
3. **密钥派生**：使用PRF-HMAC-SHA256派生所有密钥
4. **认证**：使用RSA/ECDSA签名，配合SHA256哈希
5. **ESP加密**：使用AES-CBC加密，HMAC-SHA256完整性保护

所有算法都通过OpenSSL插件调用OpenSSL库实现。

**要集成国密算法，需要**：
1. 创建gmsm插件（类似openssl插件）
2. 注册SM2/SM3/SM4算法到crypto_factory
3. 添加算法枚举值
4. 在提案选择中支持国密算法关键字
