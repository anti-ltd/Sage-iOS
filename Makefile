APP_NAME       := Sage
SCHEME         := Sage
BUNDLE_ID      := ltd.anti.sage

PROJECT        := Sage.xcodeproj
BUILD_DIR      := build
DERIVED        := $(BUILD_DIR)/DerivedData
CONFIG         ?= Debug

SIM_NAME       ?= iPhone 17 Pro
SIM_DEST       := "platform=iOS Simulator,name=$(SIM_NAME)"

DEVICE         ?=
DEVICE_NAME    ?=

# Unsigned-IPA packaging (for a friend to self-sign via Sideloadly/AltStore).
IPA_CONFIG     ?= Release
IPA_BUNDLE_ID  ?= $(BUNDLE_ID)
IPA_NAME       ?= $(APP_NAME)-unsigned.ipa
IPA_DERIVED    := $(BUILD_DIR)/DerivedData-ipa

.PHONY: all project icon build run sim install clean stop help test \
        device device-install device-launch build-device ipa

all: build

help:
	@echo "Simulator targets:"
	@echo "  make project — regenerate $(PROJECT) from project.yml (needs xcodegen)"
	@echo "  make icon    — render the app icon PNGs into Assets.xcassets"
	@echo "  make build   — xcodebuild for the iOS simulator"
	@echo "  make run     — boot the sim, install, launch"
	@echo "  make stop    — terminate the running sim instance"
	@echo "  make test    — run unit tests on the simulator"
	@echo "  make clean   — remove $(BUILD_DIR) and $(PROJECT)"
	@echo ""
	@echo "Device targets (requires a paired, unlocked iPhone):"
	@echo "  make device         — build + install + launch on the paired iPhone"
	@echo "  make device-install — build + install (no launch)"
	@echo "  make device-launch  — just relaunch the installed app"
	@echo ""
	@echo "Distribution:"
	@echo "  make ipa     — build an UNSIGNED .ipa for a friend to self-sign"
	@echo ""
	@echo "Overrides:"
	@echo "  SIM_NAME=\"iPhone 16 Pro Max\"  pick a different simulator"
	@echo "  DEVICE=<udid>              pick a specific iPhone by UDID"
	@echo "  DEVICE_NAME=\"My iPhone\"     pick a specific iPhone by name"
	@echo "  IPA_BUNDLE_ID=com.you.sage make ipa   override the bundle id"
	@echo "  IPA_NAME=Sage.ipa make ipa            override the output filename"

icon:
	swift Tools/RenderAppIcon.swift

project:
	@command -v xcodegen >/dev/null 2>&1 || { \
		echo "xcodegen not found. Install with: brew install xcodegen" >&2; exit 1; \
	}
	xcodegen generate
	@echo "Generated $(PROJECT)"

build: $(PROJECT)
	@mkdir -p $(BUILD_DIR)
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination $(SIM_DEST) \
		-derivedDataPath $(DERIVED) \
		build | xcbeautify --quiet 2>/dev/null || \
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination $(SIM_DEST) \
		-derivedDataPath $(DERIVED) \
		build

test: $(PROJECT)
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination $(SIM_DEST) \
		-derivedDataPath $(DERIVED) \
		test

run: build
	@xcrun simctl boot "$(SIM_NAME)" 2>/dev/null || true
	@open -a Simulator
	@APP=$$(find $(DERIVED)/Build/Products -name "$(APP_NAME).app" -type d | head -n1); \
	if [ -z "$$APP" ]; then echo "No built .app found"; exit 1; fi; \
	xcrun simctl install "$(SIM_NAME)" "$$APP"; \
	xcrun simctl launch "$(SIM_NAME)" $(BUNDLE_ID)

stop:
	@xcrun simctl terminate "$(SIM_NAME)" $(BUNDLE_ID) 2>/dev/null || true

clean:
	rm -rf $(BUILD_DIR) $(PROJECT)

# Build an unsigned device binary and wrap it in a Payload/ .ipa. The output
# carries no signature or provisioning profile, so the recipient signs it with
# their own Apple ID (Sideloadly, AltStore, ESign, …). Requires the Metal
# toolchain: `xcodebuild -downloadComponent MetalToolchain` (one time).
ipa: $(PROJECT) icon
	@mkdir -p $(BUILD_DIR)
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(IPA_CONFIG) \
		-destination 'generic/platform=iOS' \
		-derivedDataPath $(IPA_DERIVED) \
		PRODUCT_BUNDLE_IDENTIFIER=$(IPA_BUNDLE_ID) \
		CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
		build
	@APP=$$(find $(IPA_DERIVED)/Build/Products -name "$(APP_NAME).app" -type d | head -n1); \
	if [ -z "$$APP" ]; then echo "No built .app found"; exit 1; fi; \
	rm -rf $(BUILD_DIR)/ipa-staging "$(BUILD_DIR)/$(IPA_NAME)"; \
	mkdir -p $(BUILD_DIR)/ipa-staging/Payload; \
	cp -R "$$APP" $(BUILD_DIR)/ipa-staging/Payload/; \
	(cd $(BUILD_DIR)/ipa-staging && zip -qry "../$(IPA_NAME)" Payload); \
	rm -rf $(BUILD_DIR)/ipa-staging; \
	echo ""; \
	echo "Unsigned IPA: $(BUILD_DIR)/$(IPA_NAME)  (bundle id: $(IPA_BUNDLE_ID))"

DEVICE_UDID = $(shell \
	if [ -n "$(DEVICE)" ]; then \
		echo "$(DEVICE)"; \
	else \
		xcrun devicectl list devices 2>/dev/null \
			| awk -v name="$(DEVICE_NAME)" '\
				/^----/ {next} \
				name != "" && index($$0, name) == 0 {next} \
				{ \
					if (match($$0, /[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}/)) { \
						print substr($$0, RSTART, RLENGTH); exit \
					} \
				}'; \
	fi)

build-device: $(PROJECT)
	@mkdir -p $(BUILD_DIR)
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'generic/platform=iOS' \
		-derivedDataPath $(DERIVED) \
		-allowProvisioningUpdates \
		build | xcbeautify --quiet 2>/dev/null || \
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-destination 'generic/platform=iOS' \
		-derivedDataPath $(DERIVED) \
		-allowProvisioningUpdates \
		build

device: device-install device-launch

device-install: build-device
	@if [ -z "$(DEVICE_UDID)" ]; then \
		echo ""; \
		echo "No paired iPhone found. Steps:" >&2; \
		echo "  1. Plug your phone in (or pair over Wi-Fi via Finder)." >&2; \
		echo "  2. Unlock it and accept the 'Trust This Computer' prompt." >&2; \
		echo "  3. Run: xcrun devicectl list devices" >&2; \
		echo "     If it lists the phone, re-run \`make device\`." >&2; \
		echo ""; \
		exit 1; \
	fi
	@APP=$$(find $(DERIVED)/Build/Products/Debug-iphoneos -name "$(APP_NAME).app" -type d | head -n1); \
	if [ -z "$$APP" ]; then echo "No iOS-device .app found in $(DERIVED)"; exit 1; fi; \
	echo "Installing $$APP to device $(DEVICE_UDID)..."; \
	xcrun devicectl device install app --device "$(DEVICE_UDID)" "$$APP"

device-launch:
	@if [ -z "$(DEVICE_UDID)" ]; then echo "No paired iPhone — see \`make device-install\`."; exit 1; fi
	@echo "Launching $(BUNDLE_ID) on $(DEVICE_UDID)..."
	xcrun devicectl device process launch --device "$(DEVICE_UDID)" "$(BUNDLE_ID)" || true
