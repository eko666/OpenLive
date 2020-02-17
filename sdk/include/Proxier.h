#ifndef PROXIER_H
#define PROXIER_H

#ifdef __cplusplus
extern "C" {
#endif

void *proxier_open(int port);

int  proxier_get_listen_port(void *context);

void proxier_close(void *context);

int  proxier_hexstr(const char *str, int len, char *buf, int size);

#ifdef __cplusplus
}
#endif

#endif //PROXIER_H
