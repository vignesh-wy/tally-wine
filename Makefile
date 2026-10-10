# TallyPrime on macOS with Wine. Run "make" to list the commands.
# Settings (WINE_HOME, WINEPREFIX, WINE_REF) pass through to the scripts:
#   make build WINE_REF=wine-11.19
#   make run WINEPREFIX=~/some/prefix

SETUP  ?= $(HOME)/Downloads/tally_setup.exe
LETTER ?=
FOLDER ?=

.DEFAULT_GOAL := help
.PHONY: help deps build install run stop drives map clean
.EXPORT_ALL_VARIABLES:

help: ## List the commands
	@awk -F':.*## ' '/^[a-z-]+:.*## / {printf "  make %-9s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

deps: ## Install build tools (bison, mingw-w64, Rosetta)
	brew install bison mingw-w64
	@if [ "$$(uname -m)" = arm64 ]; then softwareupdate --install-rosetta --agree-to-license; fi

build: ## Build Wine into dist/wine-tally (long)
	./build-wine.sh

install: ## Install Tally. SETUP=path/to/tally_setup.exe
	./install-tally.sh "$(SETUP)"

run: ## Start Tally
	./run-tally.sh

stop: ## Force stop Tally
	./stop-tally.sh

drives: ## List drive letters seen by Tally
	./map-folder.sh

map: ## Map a Mac folder. LETTER=t FOLDER=~/TallyData
	@[ -n "$(LETTER)" ] && [ -n "$(FOLDER)" ] || { echo "Usage: make map LETTER=t FOLDER=~/TallyData"; exit 1; }
	./map-folder.sh "$(LETTER)" "$(FOLDER)"

clean: ## Delete build output (work/ and dist/). Keeps the Tally prefix
	rm -rf work dist
