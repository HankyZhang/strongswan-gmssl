/* ANSI-C code produced by gperf version 3.1 */
/* Command-line: gperf -N proposal_get_token_static -m 10 -C -G -c -t -D --output-file=proposal_keywords_static.c proposal_keywords_static.txt  */
/* Computed positions: -k'1,5,7,10,15,$' */

#if !((' ' == 32) && ('!' == 33) && ('"' == 34) && ('#' == 35) \
      && ('%' == 37) && ('&' == 38) && ('\'' == 39) && ('(' == 40) \
      && (')' == 41) && ('*' == 42) && ('+' == 43) && (',' == 44) \
      && ('-' == 45) && ('.' == 46) && ('/' == 47) && ('0' == 48) \
      && ('1' == 49) && ('2' == 50) && ('3' == 51) && ('4' == 52) \
      && ('5' == 53) && ('6' == 54) && ('7' == 55) && ('8' == 56) \
      && ('9' == 57) && (':' == 58) && (';' == 59) && ('<' == 60) \
      && ('=' == 61) && ('>' == 62) && ('?' == 63) && ('A' == 65) \
      && ('B' == 66) && ('C' == 67) && ('D' == 68) && ('E' == 69) \
      && ('F' == 70) && ('G' == 71) && ('H' == 72) && ('I' == 73) \
      && ('J' == 74) && ('K' == 75) && ('L' == 76) && ('M' == 77) \
      && ('N' == 78) && ('O' == 79) && ('P' == 80) && ('Q' == 81) \
      && ('R' == 82) && ('S' == 83) && ('T' == 84) && ('U' == 85) \
      && ('V' == 86) && ('W' == 87) && ('X' == 88) && ('Y' == 89) \
      && ('Z' == 90) && ('[' == 91) && ('\\' == 92) && (']' == 93) \
      && ('^' == 94) && ('_' == 95) && ('a' == 97) && ('b' == 98) \
      && ('c' == 99) && ('d' == 100) && ('e' == 101) && ('f' == 102) \
      && ('g' == 103) && ('h' == 104) && ('i' == 105) && ('j' == 106) \
      && ('k' == 107) && ('l' == 108) && ('m' == 109) && ('n' == 110) \
      && ('o' == 111) && ('p' == 112) && ('q' == 113) && ('r' == 114) \
      && ('s' == 115) && ('t' == 116) && ('u' == 117) && ('v' == 118) \
      && ('w' == 119) && ('x' == 120) && ('y' == 121) && ('z' == 122) \
      && ('{' == 123) && ('|' == 124) && ('}' == 125) && ('~' == 126))
/* The character set is not based on ISO-646.  */
#error "gperf generated tables don't work with this execution character set. Please report a bug to <bug-gperf@gnu.org>."
#endif

#line 1 "proposal_keywords_static.txt"

/*
 * Copyright (C) 2009-2013 Andreas Steffen
 *
 * Copyright (C) secunet Security Networks AG
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.  See <http://www.fsf.org/copyleft/gpl.txt>.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 */

#include <string.h>

#include <crypto/transform.h>
#include <crypto/crypters/crypter.h>
#include <crypto/signers/signer.h>
#include <crypto/key_exchange.h>

#line 26 "proposal_keywords_static.txt"
struct proposal_token {
	char             *name;
	transform_type_t  type;
	uint16_t          algorithm;
	uint16_t          keysize;
};;

#define TOTAL_KEYWORDS 163
#define MIN_WORD_LENGTH 3
#define MAX_WORD_LENGTH 22
#define MIN_HASH_VALUE 9
#define MAX_HASH_VALUE 361
/* maximum key range = 353, duplicates = 0 */

#ifdef __GNUC__
__inline
#else
#ifdef __cplusplus
inline
#endif
#endif
static unsigned int
hash (register const char *str, register size_t len)
{
  static const unsigned short asso_values[] =
    {
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362,  42,   9,
        3,  66,  45,  21,  18,  57,   6,   0, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362,  63, 362,  90,   0,   3,
       33,  12,   3,  87, 105,   3, 362, 362,   0, 132,
      105,  15, 171,  66, 162, 153, 114,  18, 362, 362,
        0,   3, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362, 362, 362, 362,
      362, 362, 362, 362, 362, 362, 362
    };
  register unsigned int hval = len;

  switch (hval)
    {
      default:
        hval += asso_values[(unsigned char)str[14]];
      /*FALLTHROUGH*/
      case 14:
      case 13:
      case 12:
      case 11:
      case 10:
        hval += asso_values[(unsigned char)str[9]];
      /*FALLTHROUGH*/
      case 9:
      case 8:
      case 7:
        hval += asso_values[(unsigned char)str[6]];
      /*FALLTHROUGH*/
      case 6:
      case 5:
        hval += asso_values[(unsigned char)str[4]];
      /*FALLTHROUGH*/
      case 4:
      case 3:
      case 2:
      case 1:
        hval += asso_values[(unsigned char)str[0]+1];
        break;
    }
  return hval + asso_values[(unsigned char)str[len - 1]];
}

static const struct proposal_token wordlist[] =
  {
#line 38 "proposal_keywords_static.txt"
    {"aes192",           ENCRYPTION_ALGORITHM, ENCR_AES_CBC,            192},
#line 163 "proposal_keywords_static.txt"
    {"ecp192",           KEY_EXCHANGE_METHOD, ECP_192_BIT,                0},
#line 178 "proposal_keywords_static.txt"
    {"x448",             KEY_EXCHANGE_METHOD, CURVE_448,                  0},
#line 37 "proposal_keywords_static.txt"
    {"aes128",           ENCRYPTION_ALGORITHM, ENCR_AES_CBC,            128},
#line 141 "proposal_keywords_static.txt"
    {"aesxcbc",          INTEGRITY_ALGORITHM,  AUTH_AES_XCBC_96,          0},
#line 176 "proposal_keywords_static.txt"
    {"x25519",           KEY_EXCHANGE_METHOD, CURVE_25519,                0},
#line 33 "proposal_keywords_static.txt"
    {"null",             ENCRYPTION_ALGORITHM, ENCR_NULL,                 0},
#line 167 "proposal_keywords_static.txt"
    {"ecp521",           KEY_EXCHANGE_METHOD, ECP_521_BIT,                0},
#line 50 "proposal_keywords_static.txt"
    {"aes192ccm8",       ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV8,       192},
#line 52 "proposal_keywords_static.txt"
    {"aes192ccm12",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV12,      192},
#line 43 "proposal_keywords_static.txt"
    {"aes128ccm8",       ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV8,       128},
#line 45 "proposal_keywords_static.txt"
    {"aes128ccm12",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV12,      128},
#line 55 "proposal_keywords_static.txt"
    {"aes192ccm128",     ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV16,      192},
#line 152 "proposal_keywords_static.txt"
    {"none",             KEY_EXCHANGE_METHOD, KE_NONE,                    0},
#line 53 "proposal_keywords_static.txt"
    {"aes192ccm96",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV12,      192},
#line 48 "proposal_keywords_static.txt"
    {"aes128ccm128",     ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV16,      128},
#line 46 "proposal_keywords_static.txt"
    {"aes128ccm96",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV12,      128},
#line 54 "proposal_keywords_static.txt"
    {"aes192ccm16",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV16,      192},
#line 47 "proposal_keywords_static.txt"
    {"aes128ccm16",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV16,      128},
#line 39 "proposal_keywords_static.txt"
    {"aes256",           ENCRYPTION_ALGORITHM, ENCR_AES_CBC,            256},
#line 57 "proposal_keywords_static.txt"
    {"aes256ccm8",       ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV8,       256},
#line 59 "proposal_keywords_static.txt"
    {"aes256ccm12",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV12,      256},
#line 165 "proposal_keywords_static.txt"
    {"ecp256",           KEY_EXCHANGE_METHOD, ECP_256_BIT,                0},
#line 96 "proposal_keywords_static.txt"
    {"camellia192",      ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CBC,       192},
#line 62 "proposal_keywords_static.txt"
    {"aes256ccm128",     ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV16,      256},
#line 60 "proposal_keywords_static.txt"
    {"aes256ccm96",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV12,      256},
#line 142 "proposal_keywords_static.txt"
    {"camelliaxcbc",     INTEGRITY_ALGORITHM,  AUTH_CAMELLIA_XCBC_96,     0},
#line 95 "proposal_keywords_static.txt"
    {"camellia128",      ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CBC,       128},
#line 164 "proposal_keywords_static.txt"
    {"ecp224",           KEY_EXCHANGE_METHOD, ECP_224_BIT,                0},
#line 166 "proposal_keywords_static.txt"
    {"ecp384",           KEY_EXCHANGE_METHOD, ECP_384_BIT,                0},
#line 119 "proposal_keywords_static.txt"
    {"cast128",          ENCRYPTION_ALGORITHM, ENCR_CAST,               128},
#line 61 "proposal_keywords_static.txt"
    {"aes256ccm16",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV16,      256},
#line 107 "proposal_keywords_static.txt"
    {"camellia192ccm8",  ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV8,  192},
#line 109 "proposal_keywords_static.txt"
    {"camellia192ccm12", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV12, 192},
#line 101 "proposal_keywords_static.txt"
    {"camellia128ccm8",  ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV8,  128},
#line 103 "proposal_keywords_static.txt"
    {"camellia128ccm12", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV12, 128},
#line 112 "proposal_keywords_static.txt"
    {"camellia192ccm128",ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV16, 192},
#line 110 "proposal_keywords_static.txt"
    {"camellia192ccm96", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV12, 192},
#line 106 "proposal_keywords_static.txt"
    {"camellia128ccm128",ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV16, 128},
#line 104 "proposal_keywords_static.txt"
    {"camellia128ccm96", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV12, 128},
#line 175 "proposal_keywords_static.txt"
    {"curve25519",       KEY_EXCHANGE_METHOD, CURVE_25519,                0},
#line 51 "proposal_keywords_static.txt"
    {"aes192ccm64",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV8,       192},
#line 111 "proposal_keywords_static.txt"
    {"camellia192ccm16", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV16, 192},
#line 44 "proposal_keywords_static.txt"
    {"aes128ccm64",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV8,       128},
#line 105 "proposal_keywords_static.txt"
    {"camellia128ccm16", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV16, 128},
#line 113 "proposal_keywords_static.txt"
    {"camellia256ccm8",  ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV8,  256},
#line 115 "proposal_keywords_static.txt"
    {"camellia256ccm12", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV12, 256},
#line 97 "proposal_keywords_static.txt"
    {"camellia256",      ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CBC,       256},
#line 118 "proposal_keywords_static.txt"
    {"camellia256ccm128",ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV16, 256},
#line 116 "proposal_keywords_static.txt"
    {"camellia256ccm96", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV12, 256},
#line 149 "proposal_keywords_static.txt"
    {"prfaesxcbc",       PSEUDO_RANDOM_FUNCTION, PRF_AES128_XCBC,         0},
#line 151 "proposal_keywords_static.txt"
    {"prfaescmac",       PSEUDO_RANDOM_FUNCTION, PRF_AES128_CMAC,         0},
#line 58 "proposal_keywords_static.txt"
    {"aes256ccm64",      ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV8,       256},
#line 117 "proposal_keywords_static.txt"
    {"camellia256ccm16", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV16, 256},
#line 86 "proposal_keywords_static.txt"
    {"aes192gmac",       ENCRYPTION_ALGORITHM, ENCR_NULL_AUTH_AES_GMAC, 192},
#line 177 "proposal_keywords_static.txt"
    {"curve448",         KEY_EXCHANGE_METHOD, CURVE_448,                  0},
#line 85 "proposal_keywords_static.txt"
    {"aes128gmac",       ENCRYPTION_ALGORITHM, ENCR_NULL_AUTH_AES_GMAC, 128},
#line 71 "proposal_keywords_static.txt"
    {"aes192gcm8",       ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV8,       192},
#line 73 "proposal_keywords_static.txt"
    {"aes192gcm12",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV12,      192},
#line 196 "proposal_keywords_static.txt"
    {"esn",              EXTENDED_SEQUENCE_NUMBERS, EXT_SEQ_NUMBERS,      0},
#line 64 "proposal_keywords_static.txt"
    {"aes128gcm8",       ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV8,       128},
#line 66 "proposal_keywords_static.txt"
    {"aes128gcm12",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV12,      128},
#line 76 "proposal_keywords_static.txt"
    {"aes192gcm128",     ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV16,      192},
#line 108 "proposal_keywords_static.txt"
    {"camellia192ccm64", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV8,  192},
#line 74 "proposal_keywords_static.txt"
    {"aes192gcm96",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV12,      192},
#line 69 "proposal_keywords_static.txt"
    {"aes128gcm128",     ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV16,      128},
#line 102 "proposal_keywords_static.txt"
    {"camellia128ccm64", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV8,  128},
#line 67 "proposal_keywords_static.txt"
    {"aes128gcm96",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV12,      128},
#line 184 "proposal_keywords_static.txt"
    {"sm2",              KEY_EXCHANGE_METHOD, SM2_256,                    0},
#line 162 "proposal_keywords_static.txt"
    {"modp8192",         KEY_EXCHANGE_METHOD, MODP_8192_BIT,              0},
#line 188 "proposal_keywords_static.txt"
    {"sm4cbc",           ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128},
#line 87 "proposal_keywords_static.txt"
    {"aes256gmac",       ENCRYPTION_ALGORITHM, ENCR_NULL_AUTH_AES_GMAC, 256},
#line 75 "proposal_keywords_static.txt"
    {"aes192gcm16",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV16,      192},
#line 148 "proposal_keywords_static.txt"
    {"prfmd5",           PSEUDO_RANDOM_FUNCTION, PRF_HMAC_MD5,            0},
#line 129 "proposal_keywords_static.txt"
    {"sha1",             INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA1_96,         0},
#line 68 "proposal_keywords_static.txt"
    {"aes128gcm16",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV16,      128},
#line 139 "proposal_keywords_static.txt"
    {"md5",              INTEGRITY_ALGORITHM,  AUTH_HMAC_MD5_96,          0},
#line 78 "proposal_keywords_static.txt"
    {"aes256gcm8",       ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV8,       256},
#line 80 "proposal_keywords_static.txt"
    {"aes256gcm12",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV12,      256},
#line 137 "proposal_keywords_static.txt"
    {"sha512",           INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA2_512_256,    0},
#line 140 "proposal_keywords_static.txt"
    {"md5_128",          INTEGRITY_ALGORITHM,  AUTH_HMAC_MD5_128,         0},
#line 94 "proposal_keywords_static.txt"
    {"camellia",         ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CBC,       128},
#line 83 "proposal_keywords_static.txt"
    {"aes256gcm128",     ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV16,      256},
#line 114 "proposal_keywords_static.txt"
    {"camellia256ccm64", ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CCM_ICV8,  256},
#line 81 "proposal_keywords_static.txt"
    {"aes256gcm96",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV12,      256},
#line 193 "proposal_keywords_static.txt"
    {"sm3_96",           INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_96,          0},
#line 180 "proposal_keywords_static.txt"
    {"gost512",          KEY_EXCHANGE_METHOD, GOST3410_512,               0},
#line 190 "proposal_keywords_static.txt"
    {"sm4gcm128",        ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128},
#line 126 "proposal_keywords_static.txt"
    {"twofish192",       ENCRYPTION_ALGORITHM, ENCR_TWOFISH_CBC,        192},
#line 56 "proposal_keywords_static.txt"
    {"aes192ccm",        ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV16,      192},
#line 143 "proposal_keywords_static.txt"
    {"aescmac",          INTEGRITY_ALGORITHM,  AUTH_AES_CMAC_96,          0},
#line 82 "proposal_keywords_static.txt"
    {"aes256gcm16",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV16,      256},
#line 49 "proposal_keywords_static.txt"
    {"aes128ccm",        ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV16,      128},
#line 125 "proposal_keywords_static.txt"
    {"twofish128",       ENCRYPTION_ALGORITHM, ENCR_TWOFISH_CBC,        128},
#line 179 "proposal_keywords_static.txt"
    {"gost256",          KEY_EXCHANGE_METHOD, GOST3410_256,               0},
#line 191 "proposal_keywords_static.txt"
    {"sm4gcm16",         ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128},
#line 36 "proposal_keywords_static.txt"
    {"aes",              ENCRYPTION_ALGORITHM, ENCR_AES_CBC,            128},
#line 131 "proposal_keywords_static.txt"
    {"sha256",           INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA2_256_128,    0},
#line 185 "proposal_keywords_static.txt"
    {"sm2_256",          KEY_EXCHANGE_METHOD, SM2_256,                    0},
#line 72 "proposal_keywords_static.txt"
    {"aes192gcm64",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV8,       192},
#line 187 "proposal_keywords_static.txt"
    {"sm4",              ENCRYPTION_ALGORITHM, ENCR_SM4_CBC,            128},
#line 65 "proposal_keywords_static.txt"
    {"aes128gcm64",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV8,       128},
#line 63 "proposal_keywords_static.txt"
    {"aes256ccm",        ENCRYPTION_ALGORITHM, ENCR_AES_CCM_ICV16,      256},
#line 158 "proposal_keywords_static.txt"
    {"modp2048",         KEY_EXCHANGE_METHOD, MODP_2048_BIT,              0},
#line 34 "proposal_keywords_static.txt"
    {"des",              ENCRYPTION_ALGORITHM, ENCR_DES,                  0},
#line 156 "proposal_keywords_static.txt"
    {"modp1024",         KEY_EXCHANGE_METHOD, MODP_1024_BIT,              0},
#line 135 "proposal_keywords_static.txt"
    {"sha384",           INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA2_384_192,    0},
#line 127 "proposal_keywords_static.txt"
    {"twofish256",       ENCRYPTION_ALGORITHM, ENCR_TWOFISH_CBC,        256},
#line 92 "proposal_keywords_static.txt"
    {"blowfish192",      ENCRYPTION_ALGORITHM, ENCR_BLOWFISH,           192},
#line 41 "proposal_keywords_static.txt"
    {"aes192ctr",        ENCRYPTION_ALGORITHM, ENCR_AES_CTR,            192},
#line 160 "proposal_keywords_static.txt"
    {"modp4096",         KEY_EXCHANGE_METHOD, MODP_4096_BIT,              0},
#line 40 "proposal_keywords_static.txt"
    {"aes128ctr",        ENCRYPTION_ALGORITHM, ENCR_AES_CTR,            128},
#line 91 "proposal_keywords_static.txt"
    {"blowfish128",      ENCRYPTION_ALGORITHM, ENCR_BLOWFISH,           128},
#line 168 "proposal_keywords_static.txt"
    {"modp1024s160",     KEY_EXCHANGE_METHOD, MODP_1024_160,              0},
#line 155 "proposal_keywords_static.txt"
    {"modp768",          KEY_EXCHANGE_METHOD, MODP_768_BIT,               0},
#line 79 "proposal_keywords_static.txt"
    {"aes256gcm64",      ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV8,       256},
#line 192 "proposal_keywords_static.txt"
    {"sm3",              INTEGRITY_ALGORITHM,  AUTH_HMAC_SM3_96,          0},
#line 171 "proposal_keywords_static.txt"
    {"ecp224bp",         KEY_EXCHANGE_METHOD, ECP_224_BP,                 0},
#line 170 "proposal_keywords_static.txt"
    {"modp2048s256",     KEY_EXCHANGE_METHOD, MODP_2048_256,              0},
#line 173 "proposal_keywords_static.txt"
    {"ecp384bp",         KEY_EXCHANGE_METHOD, ECP_384_BP,                 0},
#line 174 "proposal_keywords_static.txt"
    {"ecp512bp",         KEY_EXCHANGE_METHOD, ECP_512_BP,                 0},
#line 150 "proposal_keywords_static.txt"
    {"prfcamelliaxcbc",  PSEUDO_RANDOM_FUNCTION, PRF_CAMELLIA128_XCBC,    0},
#line 42 "proposal_keywords_static.txt"
    {"aes256ctr",        ENCRYPTION_ALGORITHM, ENCR_AES_CTR,            256},
#line 144 "proposal_keywords_static.txt"
    {"prfsha1",          PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SHA1,           0},
#line 138 "proposal_keywords_static.txt"
    {"sha2_512",         INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA2_512_256,    0},
#line 145 "proposal_keywords_static.txt"
    {"prfsha256",        PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SHA2_256,       0},
#line 35 "proposal_keywords_static.txt"
    {"3des",             ENCRYPTION_ALGORITHM, ENCR_3DES,                 0},
#line 172 "proposal_keywords_static.txt"
    {"ecp256bp",         KEY_EXCHANGE_METHOD, ECP_256_BP,                 0},
#line 147 "proposal_keywords_static.txt"
    {"prfsha512",        PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SHA2_512,       0},
#line 157 "proposal_keywords_static.txt"
    {"modp1536",         KEY_EXCHANGE_METHOD, MODP_1536_BIT,              0},
#line 128 "proposal_keywords_static.txt"
    {"sha",              INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA1_96,         0},
#line 93 "proposal_keywords_static.txt"
    {"blowfish256",      ENCRYPTION_ALGORITHM, ENCR_BLOWFISH,           256},
#line 99 "proposal_keywords_static.txt"
    {"camellia192ctr",   ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CTR,       192},
#line 169 "proposal_keywords_static.txt"
    {"modp2048s224",     KEY_EXCHANGE_METHOD, MODP_2048_224,              0},
#line 98 "proposal_keywords_static.txt"
    {"camellia128ctr",   ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CTR,       128},
#line 154 "proposal_keywords_static.txt"
    {"modpnull",         KEY_EXCHANGE_METHOD, MODP_NULL,                  0},
#line 161 "proposal_keywords_static.txt"
    {"modp6144",         KEY_EXCHANGE_METHOD, MODP_6144_BIT,              0},
#line 132 "proposal_keywords_static.txt"
    {"sha2_256",         INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA2_256_128,    0},
#line 133 "proposal_keywords_static.txt"
    {"sha256_96",        INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA2_256_96,     0},
#line 134 "proposal_keywords_static.txt"
    {"sha2_256_96",      INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA2_256_96,     0},
#line 77 "proposal_keywords_static.txt"
    {"aes192gcm",        ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV16,      192},
#line 195 "proposal_keywords_static.txt"
    {"noesn",            EXTENDED_SEQUENCE_NUMBERS, NO_EXT_SEQ_NUMBERS,   0},
#line 70 "proposal_keywords_static.txt"
    {"aes128gcm",        ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV16,      128},
#line 100 "proposal_keywords_static.txt"
    {"camellia256ctr",   ENCRYPTION_ALGORITHM, ENCR_CAMELLIA_CTR,       256},
#line 88 "proposal_keywords_static.txt"
    {"chacha20poly1305", ENCRYPTION_ALGORITHM, ENCR_CHACHA20_POLY1305,    0},
#line 136 "proposal_keywords_static.txt"
    {"sha2_384",         INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA2_384_192,    0},
#line 124 "proposal_keywords_static.txt"
    {"twofish",          ENCRYPTION_ALGORITHM, ENCR_TWOFISH_CBC,        128},
#line 159 "proposal_keywords_static.txt"
    {"modp3072",         KEY_EXCHANGE_METHOD, MODP_3072_BIT,              0},
#line 130 "proposal_keywords_static.txt"
    {"sha1_160",         INTEGRITY_ALGORITHM,  AUTH_HMAC_SHA1_160,        0},
#line 84 "proposal_keywords_static.txt"
    {"aes256gcm",        ENCRYPTION_ALGORITHM, ENCR_AES_GCM_ICV16,      256},
#line 189 "proposal_keywords_static.txt"
    {"sm4gcm",           ENCRYPTION_ALGORITHM, ENCR_SM4_GCM_ICV16,      128},
#line 122 "proposal_keywords_static.txt"
    {"serpent192",       ENCRYPTION_ALGORITHM, ENCR_SERPENT_CBC,        192},
#line 181 "proposal_keywords_static.txt"
    {"mlkem512",         KEY_EXCHANGE_METHOD, ML_KEM_512,                 0},
#line 121 "proposal_keywords_static.txt"
    {"serpent128",       ENCRYPTION_ALGORITHM, ENCR_SERPENT_CBC,        128},
#line 182 "proposal_keywords_static.txt"
    {"mlkem768",         KEY_EXCHANGE_METHOD, ML_KEM_768,                 0},
#line 194 "proposal_keywords_static.txt"
    {"prfsm3",           PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SM3,            0},
#line 90 "proposal_keywords_static.txt"
    {"blowfish",         ENCRYPTION_ALGORITHM, ENCR_BLOWFISH,           128},
#line 123 "proposal_keywords_static.txt"
    {"serpent256",       ENCRYPTION_ALGORITHM, ENCR_SERPENT_CBC,        256},
#line 146 "proposal_keywords_static.txt"
    {"prfsha384",        PSEUDO_RANDOM_FUNCTION, PRF_HMAC_SHA2_384,       0},
#line 183 "proposal_keywords_static.txt"
    {"mlkem1024",        KEY_EXCHANGE_METHOD, ML_KEM_1024,                0},
#line 89 "proposal_keywords_static.txt"
    {"chacha20poly1305compat", ENCRYPTION_ALGORITHM, ENCR_CHACHA20_POLY1305, 256},
#line 153 "proposal_keywords_static.txt"
    {"modpnone",         KEY_EXCHANGE_METHOD, KE_NONE,                    0},
#line 120 "proposal_keywords_static.txt"
    {"serpent",          ENCRYPTION_ALGORITHM, ENCR_SERPENT_CBC,        128}
  };

static const short lookup[] =
  {
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,   0,
     -1,  -1,   1,   2,  -1,   3,   4,  -1,   5,   6,
     -1,   7,  -1,  -1,  -1,   8,   9,  -1,  10,  11,
     12,  13,  14,  15,  -1,  16,  -1,  -1,  -1,  -1,
     -1,  17,  -1,  -1,  18,  19,  20,  21,  22,  -1,
     23,  24,  -1,  25,  26,  -1,  27,  28,  -1,  -1,
     29,  30,  31,  32,  33,  -1,  34,  35,  36,  -1,
     37,  38,  -1,  39,  -1,  -1,  40,  41,  -1,  42,
     43,  -1,  44,  -1,  45,  46,  47,  -1,  -1,  48,
     -1,  49,  -1,  -1,  50,  -1,  -1,  51,  52,  -1,
     53,  -1,  -1,  54,  55,  -1,  56,  -1,  -1,  57,
     58,  59,  60,  61,  62,  63,  64,  65,  66,  67,
     68,  -1,  69,  70,  71,  72,  73,  74,  75,  76,
     77,  78,  79,  80,  81,  82,  83,  84,  85,  86,
     -1,  87,  88,  -1,  89,  90,  91,  92,  93,  -1,
     -1,  94,  95,  -1,  -1,  -1,  96,  -1,  -1,  97,
     98,  99, 100,  -1, 101, 102,  -1, 103, 104,  -1,
    105, 106, 107, 108, 109,  -1, 110, 111,  -1, 112,
    113, 114, 115, 116,  -1, 117, 118,  -1, 119,  -1,
     -1, 120, 121,  -1,  -1, 122, 123, 124,  -1,  -1,
     -1, 125, 126, 127, 128,  -1, 129, 130,  -1, 131,
     -1,  -1, 132, 133,  -1, 134,  -1,  -1, 135,  -1,
     -1, 136,  -1,  -1, 137, 138,  -1, 139, 140,  -1,
    141, 142,  -1, 143,  -1, 144, 145,  -1, 146, 147,
     -1,  -1,  -1,  -1,  -1, 148,  -1,  -1,  -1, 149,
     -1,  -1,  -1,  -1,  -1, 150, 151, 152,  -1,  -1,
     -1,  -1, 153,  -1,  -1,  -1,  -1,  -1,  -1, 154,
    155,  -1, 156,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1, 157,  -1,  -1,  -1,
     -1, 158,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1, 159, 160, 161,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,
     -1, 162
  };

const struct proposal_token *
proposal_get_token_static (register const char *str, register size_t len)
{
  if (len <= MAX_WORD_LENGTH && len >= MIN_WORD_LENGTH)
    {
      register unsigned int key = hash (str, len);

      if (key <= MAX_HASH_VALUE)
        {
          register int index = lookup[key];

          if (index >= 0)
            {
              register const char *s = wordlist[index].name;

              if (*str == *s && !strncmp (str + 1, s + 1, len - 1) && s[len] == '\0')
                return &wordlist[index];
            }
        }
    }
  return 0;
}
