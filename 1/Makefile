treb: treb.o
	ld treb.o -o treb

treb.o: treb.asm
	nasm -g -f elf64 treb.asm -o treb.o

.PHONY: run
run: treb input
	./treb < input
