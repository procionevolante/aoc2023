part1: part1.o
	ld part1.o -o part1

part1.o: part1.asm
	nasm -g -f elf64 part1.asm -o part1.o
	#nasm -f elf64 part1.asm -o part1.o

.PHONY: clean
clean:
	rm -f *.o part?

test1: part1 testinput1
	./part1 < testinput1

run1: part1 input
	./part1 < input

part2: part2.o
	ld part2.o -o part2

part2.o: part2.asm
	nasm -g -f elf64 part2.asm -o part2.o

test2: part2 testinput2
	./part2 < testinput1

run2: part2 input
	./part2 < input
