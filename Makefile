# The app will be built here
APP_PATH=build/WarningLights.app
APP_NAME=WarningLights

PROJECT=WarningLights.xcodeproj
SCHEME=WarningLights
CONFIGURATION=Release

XCODEBUILD=/usr/bin/xcodebuild
CP=/bin/cp
RM=/bin/rm
OPEN=/usr/bin/open
PKILL=/usr/bin/pkill

# Show available targets
.PHONY: help
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  build      Build the app (Release) into build/"
	@echo "  run        Build and launch the app"
	@echo "  test       Run unit tests"
	@echo "  install    Build and copy to /Applications"
	@echo "  uninstall  Remove from /Applications"
	@echo "  kill       Kill any running instances"
	@echo "  clean      Delete build artifacts"
	@echo "  help       Show this help"

# Build the app in the build/ directory
.PHONY: build
build:
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) \
    	CONFIGURATION_BUILD_DIR='$(CURDIR)/build' build

# Build and run the app
.PHONY: run
run: build
	$(OPEN) '$(APP_PATH)'

# Run unit tests
.PHONY: test
test:
	$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) test

# Build the app and copy it to /Applications
.PHONY: install
install: build
	$(CP) -R '$(APP_PATH)' /Applications

# Remove the app from /Applications
.PHONY: uninstall
uninstall: kill
	$(RM) -rf '/Applications/$(APP_NAME).app'

# Kill any running instances
.PHONY: kill
kill:
	-$(PKILL) -x $(APP_NAME)

# Delete build artifacts
.PHONY: clean
clean:
	- $(RM) -rf build
