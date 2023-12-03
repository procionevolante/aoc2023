powerg: powerg.o
	ld powerg.o -o powerg

powerg.o: power_games.asm
	nasm -g -f elf64 power_games.asm -o powerg.o

.PHONY: clean
clean:
	rm -r *.o powerg
	
