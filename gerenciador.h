#ifndef GERENCIADOR_H
#define GERENCIADOR_H

void setup_brk();
void dismiss_brk();
void *memory_alloc(unsigned long int bytes, unsigned char strategy);
int memory_free(void *pointer);

#endif