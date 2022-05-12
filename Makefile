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
	mkdir -p $(DESTDIR)$(THIRDPARTYDIR)/logfmt
	install -m644 * $(DESTDIR)$(THIRDPARTYDIR)/logfmt

uninstall:
	rm -rf $(DESTDIR)$(THIRDPARTYDIR)/logfmt

.PHONY: all clean check install uninstall