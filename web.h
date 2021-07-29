#ifndef WEB_H
#define WEB_H

#include <WebServer.h>

extern WebServer server;

// how to handle hasSD?
// by some shared global var maybe
void web_setup(void);

#endif
