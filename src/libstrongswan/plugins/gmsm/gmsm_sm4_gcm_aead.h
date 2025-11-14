/*
 * SM4 GCM AEAD (wrapper similar to gcm_aead but using SM4 block cipher)
 */
#ifndef GMSM_SM4_GCM_AEAD_H_
#define GMSM_SM4_GCM_AEAD_H_

#include <crypto/aead.h>

typedef struct gmsm_sm4_gcm_aead_t gmsm_sm4_gcm_aead_t;

struct gmsm_sm4_gcm_aead_t {
    aead_t aead; /* must be first so pointer to struct can be cast to aead_t* if needed */
};

/* Factory returning aead_t* as required by PLUGIN_REGISTER(AEAD, ...) */
aead_t *gmsm_sm4_gcm_aead_create(encryption_algorithm_t algo,
                                 size_t key_size, size_t salt_size);

#endif /* GMSM_SM4_GCM_AEAD_H_ */
