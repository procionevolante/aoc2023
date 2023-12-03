.PHONY: all
all: treb treb2

treb: treb.o
	ld treb.o -o treb

treb.o: treb.asm
	nasm -g -f elf64 treb.asm -o treb.o

.PHONY: run
run: treb input
	./treb < input

test1: treb testinput
	./treb < testinput

convertDigits.o: convertDigits.c
	cc -O0 -c -g convertDigits.c -o convertDigits.o

treb2: treb.o convertDigits.o
	ld treb.o convertDigits.o -o treb2

.PHONY: run2
run2: treb2 input
	./treb2 < input
test2: treb2 testinput2
	./treb2 < testinput2

.PHONY: clean
clean:
	rm -f *.o treb?
