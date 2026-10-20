CXX ?= g++
CXXFLAGS ?= -O2 -pipe -std=c++17 -Wall -Wextra -Wpedantic
PKGS = x11 libpng
CPPFLAGS := $(shell pkg-config --cflags $(PKGS))
LDLIBS := $(shell pkg-config --libs $(PKGS))
STATIC_LIBS := $(shell pkg-config --static --libs $(PKGS))

.PHONY: all portable clean test
all: bin/print-rc

bin/print-rc: src/main.cpp src/settings.hpp
	@mkdir -p bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) src/main.cpp -o $@ $(LDLIBS)

# Usado na distribuicao; nenhuma biblioteca dinamica exigida pelo ELF.
# O servidor grafico X11 e o kernel continuam sendo requisitos do sistema.
portable:
	@mkdir -p bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -static src/main.cpp -o bin/print-rc $(STATIC_LIBS)
	strip bin/print-rc
	@file bin/print-rc
	@! readelf -l bin/print-rc | grep -q INTERP

test: bin/print-rc
	./bin/print-rc --self-test
	./bin/print-rc --version

clean:
	rm -f bin/print-rc
