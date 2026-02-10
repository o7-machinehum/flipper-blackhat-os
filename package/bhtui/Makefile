.PHONY: all build install clean

BINARY := bhtui
BUILD_DIR := build
PREFIX ?= /usr/local

all: build

build:
	cmake -S . -B $(BUILD_DIR)
	cmake --build $(BUILD_DIR) --target $(BINARY)

install: build
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 0755 $(BUILD_DIR)/$(BINARY) $(DESTDIR)$(PREFIX)/bin/$(BINARY)

clean:
	rm -rf $(BUILD_DIR)
