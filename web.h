#ifndef WEB_H
#define WEB_H

#include <WebServer.h>

extern WebServer server;

void monitorWiFi(void); // call it repeatedly from loop() to reconnect
void web_setup(void);

#endif
