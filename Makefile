CXX ?= g++
CXXFLAGS ?= -O2 -pipe -std=c++17 -Wall -Wextra -Wpedantic
LDLIBS := $(shell pkg-config --libs x11 libpng)
CPPFLAGS := $(shell pkg-config --cflags x11 libpng)

.PHONY: all clean test
all: bin/print-rc

bin/print-rc: src/main.cpp
	@mkdir -p bin
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $< -o $@ $(LDLIBS)

test: bin/print-rc
	./bin/print-rc --self-test
	./bin/print-rc --version

clean:
	rm -f bin/print-rc
