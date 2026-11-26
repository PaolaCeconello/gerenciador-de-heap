TESTES = $(basename $(wildcard *.c))

all: $(TESTES)

gerenciador.o: gerenciador.s
	$(AS) $(ASFLAGS) $< -o $@
%: %.c gerenciador.o
	$(CC) $(CFLAGS) $< gerenciador.o -o $@
run: all
	for t in $(TESTES); do echo "===== $$t ====="; ./$$t; done
clean:
	rm -f *.o $(TESTES)
.PHONY: all run clean