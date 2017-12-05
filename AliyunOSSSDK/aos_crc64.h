#ifndef LIBAOS_CRC_H
#define LIBAOS_CRC_H

#include <_types/_uintmax_t.h>
#include <_types/_uint64_t.h>
#include <stddef.h>

uint64_t aos_crc64(uint64_t crc, void *buf, size_t len);
uint64_t aos_crc64_combine(uint64_t crc1, uint64_t crc2, uintmax_t len2);

#endif
