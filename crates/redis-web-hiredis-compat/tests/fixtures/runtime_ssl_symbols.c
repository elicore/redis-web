#include <stdio.h>

#include <hiredis/hiredis.h>
#include <hiredis/hiredis_ssl.h>

int main(void) {
    if (redisInitOpenSSL() != REDIS_OK) {
        fprintf(stderr, "redisInitOpenSSL failed\n");
        return 1;
    }

    /* Link/runtime smoke: ensure SSL entrypoints are available. */
    volatile void *fn_initiate = (void *)redisInitiateSSLWithContext;
    volatile void *fn_create = (void *)redisCreateSSLContextWithOptions;
    volatile void *fn_free = (void *)redisFreeSSLContext;

    if (fn_initiate == NULL || fn_create == NULL || fn_free == NULL) {
        fprintf(stderr, "missing one or more SSL function pointers\n");
        return 2;
    }

    puts("SSL symbol runtime fixture passed");
    return 0;
}
