part1: part1.o
	ld part1.o -o part1

part1.o: part1.asm
	nasm -g -f elf64 part1.asm -o part1.o
	#nasm -f elf64 part1.asm -o part1.o

.PHONY: clean
clean:
	rm -f *.o part1

test1: part1 testinput1
	./part1 < testinput1

run1: part1 input
	./part1 < input
