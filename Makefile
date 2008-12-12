#  Copyright (c) 2008, Thomas Jaeger <ThJaeger@gmail.com>
# 
#  Permission to use, copy, modify, and/or distribute this software for any
#  purpose with or without fee is hereby granted, provided that the above
#  copyright notice and this permission notice appear in all copies.
# 
#  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
#  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS.  IN NO EVENT SHALL ISC BE LIABLE FOR ANY
#  SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
#  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
#  OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
#  CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

DESTDIR  =
PREFIX   = /usr/local
BINDIR   = $(PREFIX)/bin
ICONDIR  = $(PREFIX)/share/icons/hicolor/scalable/apps
MENUDIR  = $(PREFIX)/share/applications
DFLAGS   =
OFLAGS   = -Os
AOFLAGS  = -O3
CXXFLAGS = -Wall $(DFLAGS) `pkg-config gtkmm-2.4 gthread-2.0 dbus-glib-1 --cflags`
LDFLAGS  = $(DFLAGS)

LIBS     = $(DFLAGS) -lboost_serialization -lXtst `pkg-config gtkmm-2.4 gthread-2.0 dbus-glib-1 --libs`

BINARY   = easystroke
ICON     = easystroke.svg
MENU     = easystroke.desktop
MANPAGE  = easystroke.1

CCFILES  = $(wildcard *.cc)
OFILES   = $(patsubst %.cc,%.o,$(CCFILES)) gui.o desktop.o version.o
DEPFILES = $(wildcard *.Po)
GENFILES = gui.c desktop.c dbus-server.h
GZFILES  = $(wildcard *.gz)

VERSION  = $(shell test -e debian/changelog && grep '(.*)' debian/changelog | sed 's/.*(//' | sed 's/).*//' | head -n1 || (test -e version && cat version || git describe))
GIT      = $(wildcard .git/index version)
DIST     = easystroke-$(VERSION)
ARCH     = $(shell uname -m)

-include debug.mk

all: $(BINARY)

.PHONY: all clean snapshot release

clean:
	$(RM) $(OFILES) $(BINARY) $(GENFILES) $(DEPFILES) $(MANPAGE) $(GZFILES)

include $(DEPFILES)

$(BINARY): $(OFILES)
	$(CXX) $(LDFLAGS) -o $@ $(OFILES) $(LIBS)

stroke.o: stroke.cc
	$(CXX) $(CXXFLAGS) $(AOFLAGS) -MT $@ -MMD -MP -MF $*.Po -o $@ -c $<

%.o: %.cc
	$(CXX) $(CXXFLAGS) $(OFLAGS) -MT $@ -MMD -MP -MF $*.Po -o $@ -c $<

version.o: $(GIT)
	echo 'const char *version_string = "$(VERSION)";' | $(CXX) -o $@ -c -xc++ -

gui.c: gui.glade
	echo "const char *gui_buffer = \"\\" > $@
	gtk-builder-convert $< - | sed 's/"/\\"/g' | sed 's/.*/&\\n\\/' >> $@
	echo "\";" >> $@

desktop.c: easystroke.desktop
	echo "const char *desktop_file = \"\\" > $@
	sed 's/Exec=easystroke/Exec=%s/' $< | sed 's/"/\\"/g' | sed 's/.*/&\\n\\/' >> $@
	echo "\";" >> $@

dbus-server.cc: dbus-server.h

dbus-server.h: dbus.xml
	dbus-binding-tool --prefix=server --mode=glib-server --output=$@ $<

man:	$(MANPAGE)

$(MANPAGE):	$(BINARY)
	help2man -N -n "X11 gesture recognition application" ./$(BINARY) > $@

install: all
	install -Ds $(BINARY) $(DESTDIR)$(BINDIR)/$(BINARY)
	install -D -m 644 $(ICON) $(DESTDIR)$(ICONDIR)/$(ICON)
	install -D -m 644 $(MENU) $(DESTDIR)$(MENUDIR)/$(MENU)

uninstall:
	$(RM) $(DESTDIR)$(BINDIR)/$(BINARY)
	$(RM) $(DESTDIR)$(ICONDIR)/$(ICON)
	$(RM) $(DESTDIR)$(MENUDIR)/$(MENU)

snapshot: $(DIST)_$(ARCH).tar.gz

release: $(DIST).tar.gz
	rsync -avP $(DIST).tar.gz thjaeger@frs.sourceforge.net:uploads/

tmp/$(DIST): $(GIT)
	$(RM) -r tmp
	mkdir tmp
	git archive --format=tar --prefix=$(DIST)/ HEAD | (cd tmp && tar x)
	echo $(VERSION) > $@/version
	$(RM) $@/.gitignore $@/release

$(DIST)_$(ARCH).tar.gz: tmp/$(DIST)
	$(MAKE) -j2 -C $<
	strip -s $</easystroke
	tar -czf $@ -C $< easystroke
	$(RM) -r tmp

$(DIST).tar.gz: tmp/$(DIST)
	tar -czf $@ -C tmp/ $(DIST)
	$(RM) -r tmp
