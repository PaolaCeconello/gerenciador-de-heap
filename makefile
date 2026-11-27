all: gerenciaHeap

gerenciaHeap: main.o gerenciador.o
	gcc -g main.o gerenciador.o -o gerenciaHeap

main.o: main.c gerenciador.h
	gcc -g -c main.c -o main.o

gerenciador.o: gerenciador.s
	as -g gerenciador.s -o gerenciador.o

clean:
	rm -f *.o gerenciaHeap