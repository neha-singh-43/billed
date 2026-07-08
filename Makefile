APP_NAME := Billed
APP_PATH := .build/$(APP_NAME).app
ZIP_PATH := .build/$(APP_NAME).zip
BUILD_SCRIPT := ./scripts/build-app.sh

.PHONY: build kill open run clean test zip help

help:
	@echo "Billed — make targets"
	@echo ""
	@echo "  make run     Kill running app, rebuild, and open (default workflow)"
	@echo "  make build   Build release .app bundle (universal if full Xcode)"
	@echo "  make open    Open the built .app (build first if missing)"
	@echo "  make zip     Build and zip the .app for sharing with a teammate"
	@echo "  make kill    Quit a running $(APP_NAME) instance"
	@echo "  make clean   Remove build artifacts"
	@echo "  make test    Run unit tests (requires Xcode for XCTest)"

build:
	@$(BUILD_SCRIPT)

zip: build
	@rm -f $(ZIP_PATH)
	@cd .build && ditto -c -k --keepParent $(APP_NAME).app $(APP_NAME).zip
	@echo "Packaged $(ZIP_PATH) — share this with teammates (see README → Install)."

kill:
	@killall $(APP_NAME) 2>/dev/null || true

open: build
	@open $(APP_PATH)

run: kill build
	@open $(APP_PATH)

clean:
	@swift package clean
	@rm -rf $(APP_PATH) $(ZIP_PATH)

test:
	@swift test

.DEFAULT_GOAL := help
