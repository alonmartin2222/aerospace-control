PREFIX     ?= /usr/local
BINDIR     ?= $(PREFIX)/bin
SRC        := src/AerospaceControl.swift
BIN        := bin/aerospace-control
SWIFTC     ?= swiftc
SWIFTFLAGS ?= -O -framework AppKit

.PHONY: all build clean install uninstall setup release

all: build

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p bin
	$(SWIFTC) $(SWIFTFLAGS) $(SRC) -o $(BIN)

# Optimized release build — same flags but strips symbols.
release:
	@mkdir -p bin
	$(SWIFTC) -O -whole-module-optimization -framework AppKit $(SRC) -o $(BIN)
	strip $(BIN)
	@ls -lh $(BIN)

clean:
	rm -rf bin

# Install the binary system-wide (default) or to a custom PREFIX.
# Usage: make install                  # installs to /usr/local/bin
#        make install PREFIX=$HOME/.local
install: build
	install -d $(BINDIR)
	install -m 0755 $(BIN) $(BINDIR)/aerospace-control
	@echo ""
	@echo "Installed: $(BINDIR)/aerospace-control"
	@echo "Run:       aerospace-control --setup"
	@echo "Then add a keybinding to your aerospace.toml — see README."

uninstall:
	rm -f $(BINDIR)/aerospace-control
	@echo "Removed: $(BINDIR)/aerospace-control"
	@echo "Note: ~/.config/aerospace-control/ and the LaunchAgent are kept."
	@echo "Run scripts/uninstall.sh for a complete removal."

# Convenience: bootstrap a freshly installed binary on this machine.
setup:
	$(BINDIR)/aerospace-control --setup
