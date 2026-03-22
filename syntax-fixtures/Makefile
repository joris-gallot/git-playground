CC := clang
CFLAGS := -Wall -Wextra

all: reviu

reviu: main.o
	$(CC) $(CFLAGS) main.o -o reviu

main.o: main.c
	$(CC) $(CFLAGS) -c main.c

clean:
	rm -f reviu main.o
