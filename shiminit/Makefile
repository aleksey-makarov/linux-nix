CFLAGS ?= -Wall -Wextra -O2 -std=c99
PREFIX ?= /usr/local

shiminit: shiminit.o

install: shiminit
	install -D shiminit $(PREFIX)/bin/shiminit

clean:
	rm -f shiminit shiminit.o

.PHONY: clean install
