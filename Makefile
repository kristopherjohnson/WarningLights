# The app wil be built here
APP_PATH=build/WarningLights.app

PROJECT=WarningLights.xcodeproj
SCHEME=WarningLights
CONFIGURATION=Release

XCODEBUILD=/usr/bin/xcodebuild
CP=/bin/cp
RM=/bin/rm
OPEN=/usr/bin/open

# Build the app in the build/directory
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

# Delete build artifacts
.PHONY: clean
clean:
	- $(RM) -rf build
