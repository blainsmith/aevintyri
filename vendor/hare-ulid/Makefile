.POSIX:
.SUFFIXES:
HARE=hare
HAREFLAGS=
HAREDOC=haredoc

DESTDIR=
PREFIX=/usr/local
SRCDIR=$(PREFIX)/src
HARESRCDIR=$(SRCDIR)/hare
THIRDPARTYDIR=$(HARESRCDIR)/third-party

all:
	@true # no-op

check:
	$(HARE) test

clean:
	rm -rf docs

docs:
	mkdir -p docs/ulid
	$(HAREDOC) -Fhtml ulid > docs/ulid/index.html

install:
	mkdir -p "$(DESTDIR)$(THIRDPARTYDIR)"/ulid
	install -m644 ulid/README "$(DESTDIR)$(THIRDPARTYDIR)"/ulid/README
	install -m644 ulid/*.ha "$(DESTDIR)$(THIRDPARTYDIR)"/ulid

uninstall:
	rm -rf $(DESTDIR)$(THIRDPARTYDIR)/net

.PHONY: all docs clean check install uninstall