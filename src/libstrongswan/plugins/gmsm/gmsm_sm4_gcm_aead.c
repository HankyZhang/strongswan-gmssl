/*
 * Simplified SM4-GCM AEAD implementation leveraging existing gcm_aead logic.
 * For initial integration we reuse AES-CBC crypter for block operations like gcm_aead does,
 * but switch algorithm mapping to SM4 CBC to derive GHASH key while providing ENCR_SM4_GCM_ICV16 externally.
 */
#include "gmsm_sm4_gcm_aead.h"
#include "gmsm_sm4_crypter.h"

#include <crypto/crypters/crypter.h>
#include <crypto/iv/iv_gen_seq.h>
#include <utils/debug.h>

#define BLOCK_SIZE 16
#define NONCE_SIZE 12
#define IV_SIZE 8
#define SALT_SIZE (NONCE_SIZE - IV_SIZE)

typedef struct private_gmsm_sm4_gcm_aead_t private_gmsm_sm4_gcm_aead_t;

struct private_gmsm_sm4_gcm_aead_t {
    gmsm_sm4_gcm_aead_t public;
    crypter_t *crypter; /* underlying SM4-CBC for GCTR */
    iv_gen_t *iv_gen;
    size_t icv_size;
    char salt[SALT_SIZE];
    char h[BLOCK_SIZE];
};

/* Minimal GF(2^128) helpers copied/adapted from gcm_aead.c */
static void sr_block(char *block)
{
    for (int i = BLOCK_SIZE - 1; i >= 0; i--) {
        unsigned char carry = (i ? (block[i-1] & 0x01) : 0);
        block[i] >>= 1;
        if (carry) { block[i] |= 0x80; }
    }
}
static void mult_block(char *x, char *y, char *res)
{
    char z[BLOCK_SIZE];
    char v[BLOCK_SIZE];
    memset(z, 0, BLOCK_SIZE);
    memcpy(v, y, BLOCK_SIZE);
    for (int byte = 0; byte < BLOCK_SIZE; byte++) {
        for (int bit = 7; bit >= 0; bit--) {
            if (x[byte] & (1 << bit)) { for (int k=0;k<BLOCK_SIZE;k++) z[k]^=v[k]; }
            unsigned char lsb = v[BLOCK_SIZE-1] & 0x01;
            sr_block(v);
            if (lsb) { v[0] ^= 0xE1; }
        }
    }
    memcpy(res, z, BLOCK_SIZE);
}
static void ghash(private_gmsm_sm4_gcm_aead_t *this, chunk_t x, char *res)
{
    char y[BLOCK_SIZE];
    memset(y,0,BLOCK_SIZE);
    while (x.len) {
        for (int i=0;i<BLOCK_SIZE && i<(int)x.len;i++) y[i]^=x.ptr[i];
        mult_block(y,this->h,y);
        x = chunk_skip(x,BLOCK_SIZE);
    }
    memcpy(res,y,BLOCK_SIZE);
}
static bool gctr(private_gmsm_sm4_gcm_aead_t *this, char *icb, chunk_t x)
{
    char cb[BLOCK_SIZE];
    char iv[BLOCK_SIZE];
    char tmp[BLOCK_SIZE];
    memset(iv,0,BLOCK_SIZE);
    memcpy(cb,icb,BLOCK_SIZE);
    while (x.len) {
        memcpy(tmp,cb,BLOCK_SIZE);
        if (!this->crypter->encrypt(this->crypter, chunk_from_thing(tmp), chunk_from_thing(iv), NULL))
            return FALSE;
        memxor(x.ptr,tmp,min(BLOCK_SIZE,x.len));
        chunk_increment(chunk_from_thing(cb));
        x = chunk_skip(x,BLOCK_SIZE);
    }
    return TRUE;
}
static void create_j(private_gmsm_sm4_gcm_aead_t *this, char *iv, char *j)
{
    memcpy(j,this->salt,SALT_SIZE);
    memcpy(j+SALT_SIZE,iv,IV_SIZE);
    htoun32(j+SALT_SIZE+IV_SIZE,1);
}
static bool create_h(private_gmsm_sm4_gcm_aead_t *this, char *h)
{
    char zero[BLOCK_SIZE];
    memset(zero,0,BLOCK_SIZE);
    memset(h,0,BLOCK_SIZE);
    return this->crypter->encrypt(this->crypter, chunk_create(h,BLOCK_SIZE), chunk_from_thing(zero), NULL);
}
static bool crypt_do(private_gmsm_sm4_gcm_aead_t *this, char *j, chunk_t in, chunk_t out)
{
    char icb[BLOCK_SIZE];
    memcpy(icb,j,BLOCK_SIZE);
    chunk_increment(chunk_from_thing(icb));
    if (in.ptr!=out.ptr) { out.len=in.len; memcpy(out.ptr,in.ptr,in.len); }
    return gctr(this,icb,out);
}
static bool create_icv(private_gmsm_sm4_gcm_aead_t *this, chunk_t assoc, chunk_t crypt, char *j, char *icv)
{
    size_t ap=(BLOCK_SIZE - (assoc.len % BLOCK_SIZE)) % BLOCK_SIZE;
    size_t cp=(BLOCK_SIZE - (crypt.len % BLOCK_SIZE)) % BLOCK_SIZE;
    chunk_t comb = chunk_alloc(assoc.len+ap+crypt.len+cp+BLOCK_SIZE);
    char *pos = comb.ptr;
    memcpy(pos,assoc.ptr,assoc.len); pos+=assoc.len; memset(pos,0,ap); pos+=ap;
    memcpy(pos,crypt.ptr,crypt.len); pos+=crypt.len; memset(pos,0,cp); pos+=cp;
    memset(pos,0,4); pos+=4; htoun32(pos,assoc.len*8); pos+=4;
    memset(pos,0,4); pos+=4; htoun32(pos,crypt.len*8); pos+=4;
    ghash(this, comb, pos - BLOCK_SIZE);
    free(comb.ptr);
    char s[BLOCK_SIZE]; memcpy(s,pos-BLOCK_SIZE,BLOCK_SIZE);
    if (!gctr(this,j,chunk_from_thing(s))) return FALSE;
    memcpy(icv,s,this->icv_size);
    return TRUE;
}
static bool verify_icv(private_gmsm_sm4_gcm_aead_t *this, chunk_t assoc, chunk_t crypt, char *j, char *icv)
{
    char tmp[this->icv_size];
    return create_icv(this,assoc,crypt,j,tmp) && memeq_const(tmp,icv,this->icv_size);
}

METHOD(aead_t, encrypt, bool,
    private_gmsm_sm4_gcm_aead_t *this, chunk_t plain, chunk_t assoc, chunk_t iv, chunk_t *encrypted)
{
    char j[BLOCK_SIZE]; create_j(this,iv.ptr,j);
    if (encrypted)
    {
        *encrypted = chunk_alloc(plain.len + this->icv_size);
        return crypt_do(this,j,plain,*encrypted) &&
               create_icv(this,assoc,chunk_create(encrypted->ptr, encrypted->len - this->icv_size), j, encrypted->ptr + encrypted->len - this->icv_size);
    }
    return crypt_do(this,j,plain,plain) && create_icv(this,assoc,plain,j,plain.ptr+plain.len);
}
METHOD(aead_t, decrypt, bool,
    private_gmsm_sm4_gcm_aead_t *this, chunk_t encrypted, chunk_t assoc, chunk_t iv, chunk_t *plain)
{
    if (encrypted.len < this->icv_size) return FALSE; char j[BLOCK_SIZE]; create_j(this,iv.ptr,j);
    encrypted.len -= this->icv_size;
    if (!verify_icv(this,assoc,encrypted,j,encrypted.ptr+encrypted.len)) return FALSE;
    if (plain)
    { *plain = chunk_alloc(encrypted.len); return crypt_do(this,j,encrypted,*plain); }
    return crypt_do(this,j,encrypted,encrypted);
}
METHOD(aead_t, get_block_size, size_t, private_gmsm_sm4_gcm_aead_t *this) { return 1; }
METHOD(aead_t, get_icv_size, size_t, private_gmsm_sm4_gcm_aead_t *this) { return this->icv_size; }
METHOD(aead_t, get_iv_size, size_t, private_gmsm_sm4_gcm_aead_t *this) { return IV_SIZE; }
METHOD(aead_t, get_iv_gen, iv_gen_t*, private_gmsm_sm4_gcm_aead_t *this) { return this->iv_gen; }
METHOD(aead_t, get_key_size, size_t, private_gmsm_sm4_gcm_aead_t *this) { return this->crypter->get_key_size(this->crypter) + SALT_SIZE; }
METHOD(aead_t, set_key, bool, private_gmsm_sm4_gcm_aead_t *this, chunk_t key)
{
    memcpy(this->salt, key.ptr + key.len - SALT_SIZE, SALT_SIZE);
    key.len -= SALT_SIZE;
    return this->crypter->set_key(this->crypter, key) && create_h(this,this->h);
}
METHOD(aead_t, destroy, void, private_gmsm_sm4_gcm_aead_t *this)
{
    DESTROY_IF(this->crypter); this->iv_gen->destroy(this->iv_gen);
    memwipe(this->salt,sizeof(this->salt)); memwipe(this->h,sizeof(this->h)); free(this);
}

aead_t *gmsm_sm4_gcm_aead_create(encryption_algorithm_t algo, size_t key_size, size_t salt_size)
{
    if (algo != ENCR_SM4_GCM_ICV16) return NULL;
    if (key_size == 0) key_size = 16; /* SM4 fixed key size */
    if (key_size != 16) return NULL; /* SM4 only 128-bit */
    if (salt_size && salt_size != SALT_SIZE) return NULL;
    private_gmsm_sm4_gcm_aead_t *this;
    INIT(this,
        .public = { .aead = { .encrypt = _encrypt, .decrypt = _decrypt, .get_block_size = _get_block_size, .get_icv_size = _get_icv_size, .get_iv_size = _get_iv_size, .get_iv_gen = _get_iv_gen, .get_key_size = _get_key_size, .set_key = _set_key, .destroy = _destroy } },
        .crypter = lib->crypto->create_crypter(lib->crypto, ENCR_SM4_CBC, key_size),
        .iv_gen = iv_gen_seq_create(),
        .icv_size = 16,
    );
    if (!this->crypter) { destroy(this); return NULL; }
    return &this->public.aead;
}
