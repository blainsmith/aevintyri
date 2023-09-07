.POSIX:
.SUFFIXES:
HARE=hare
HAREFLAGS=

DESTDIR=
PREFIX=/usr/local
SRCDIR=$(PREFIX)/src
HARESRCDIR=$(SRCDIR)/hare
THIRDPARTYDIR=$(HARESRCDIR)/third-party

all:
	# no-op

clean:
	# no-op

check:
	$(HARE) test

install:
	mkdir -p $(DESTDIR)$(THIRDPARTYDIR)/log/logfmt
	install -m644 * $(DESTDIR)$(THIRDPARTYDIR)

uninstall:
	rm -rf $(DESTDIR)$(THIRDPARTYDIR)/log/logfmt

.PHONY: all clean check install uninstall