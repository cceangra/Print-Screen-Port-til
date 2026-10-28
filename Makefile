CXX ?= g++
CXXFLAGS ?= -O2 -pipe -std=c++17 -Wall -Wextra -Wpedantic
PKGS = x11 libpng
CPPFLAGS += $(shell pkg-config --cflags $(PKGS))
LDLIBS += $(shell pkg-config --libs $(PKGS))
VERSION := $(shell cat VERSION)
CPPFLAGS += -DPRINT_RC_VERSION=\"$(VERSION)\"
HEADERS := $(shell find src -name '*.hpp')

.PHONY: all portable debug clean test locales
all: locales Print-RC Instalar Configurar bin/print-rc bin/print-rc-launcher

locales:
	python3 scripts/build/locales.py --check

bin/print-rc: src/main.cpp $(HEADERS) Makefile
	@mkdir -p bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) src/main.cpp -o $@ $(LDFLAGS) $(LDLIBS)

bin/print-rc-launcher: src/app/launcher.cpp src/app/dialog.hpp src/i18n/messages.hpp src/i18n/generated.hpp Makefile
	@mkdir -p bin
	$(CXX) $(CXXFLAGS) src/app/launcher.cpp -o $@ $(LDFLAGS)

Print-RC: src/app/entrypoint.cpp src/app/dialog.hpp src/i18n/messages.hpp src/i18n/generated.hpp Makefile
	$(CXX) $(CXXFLAGS) src/app/entrypoint.cpp -o $@ $(LDFLAGS)

Instalar: src/app/entrypoint.cpp src/app/dialog.hpp src/i18n/messages.hpp src/i18n/generated.hpp Makefile
	$(CXX) $(CXXFLAGS) -DPRINT_RC_INSTALLER=1 src/app/entrypoint.cpp -o $@ $(LDFLAGS)

Configurar: src/app/entrypoint.cpp src/app/dialog.hpp src/i18n/messages.hpp src/i18n/generated.hpp Makefile
	$(CXX) $(CXXFLAGS) -DPRINT_RC_SETTINGS_ENTRY=1 src/app/entrypoint.cpp -o $@ $(LDFLAGS)

# GNU portable packages deliberately use the host's dynamic glibc and loader.
# ABI requirements are checked again when packaging; this is not universal Linux.
portable: all
	strip Print-RC Instalar Configurar bin/print-rc bin/print-rc-launcher
	@file bin/print-rc
	@readelf -l bin/print-rc | grep -q INTERP

debug:
	$(MAKE) -B all CXXFLAGS='-Og -g3 -fno-omit-frame-pointer -std=c++17 -Wall -Wextra -Wpedantic'

test: bin/print-rc
	./bin/print-rc --self-test
	./bin/print-rc --version

clean:
	rm -f Print-RC Instalar Configurar bin/print-rc bin/print-rc-launcher
