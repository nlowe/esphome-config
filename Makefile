ESPHOME_VERSION ?= 2026.9.1

device_name_for = $(subst /,__,$(device:devices/%=%))

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DEVICE_FILES := $(shell find devices/ -type f \( -name '*.yaml' -or -name '*.yml' \) -and -not \( -name '.*.yaml' -or -name '.*.yml' \))
DEVICE_LINKS := $(foreach device,$(DEVICE_FILES),$(call device_name_for $(device)))

KUBECTL_EXEC := @kubectl exec -it -n smart-home esphome-0 -c esphome --

# ESPHome only looks for device files in the main config directory, it does not search recursively. We also can't
# symlink device files, as that breaks on remote builds. Instead, make a file that simply includes the target.
define link_file
	$(eval $@_TARGET = $(1))
	$(eval $@_LINKNAME = $(2))
	$(file >$($@_LINKNAME),<<: !include '$($@_TARGET)')
endef

# Run an esphome command inside a docker container setup similarly to how the device builder dashboard is configured.
# The configuration (this repo) is mounted read-only, and a docker volume is used for the esphome and platformio cache.
define esphome_cmd
	$(eval $@_CMD = $(1))
	docker run -i --rm \
		-v "$(MAKEFILE_DIR):/data/configs:ro" \
		-v esphome-lint-cache:/cache \
		-w /data \
		-e PLATFORMIO_CORE_DIR=/cache/.platformio \
		-e PLATFORMIO_BUILD_CACHE_DIR=/cache/.platformio/build_cache \
		-e ESPHOME_DATA_DIR=/cache/.esphome/data \
		--entrypoint bash \
		ghcr.io/esphome/esphome:$(ESPHOME_VERSION) \
			-c " \
				make -C /data/configs link-devices-raw; \
				cp /data/configs/secrets.dummy.yaml /data/secrets.yaml; \
				esphome $($@_CMD); \
			"
endef

.PHONY: all
all: lint editorconfig-checker

.PHONY: lint
lint:
	$(call esphome_cmd,config $(DEVICE_LINKS))

.PHONY: lint-device
lint-device:
	$(call esphome_cmd,config $(DEVICE))

.PHONY: devices
devices:
	@echo "Found Devices:"
	@$(foreach device,$(sort $(DEVICE_LINKS)),echo "  $(device:%.yaml=%)";)

.PHONY: esphome-version
esphome-version:
	@echo "$(ESPHOME_VERSION)"

# Update secrets.dummy.yaml with dummy values for all secrets present in secrets.yaml (which is not committed). The
# dummy API Key is the base64 representation of "dummy value that's 32 bytes long"
secrets.dummy.yaml: secrets.yaml Makefile
	awk '!/^#|^$$|__api_encryption_key:/ {print $$1 ": dummy_value"}' FS=: secrets.yaml >secrets.dummy.yaml
	awk '/__api_encryption_key:/ {print $$1 ": ZHVtbXkgdmFsdWUgdGhhdCdzIDMyIGJ5dGVzIGxvbmc="}' FS=: secrets.yaml >>secrets.dummy.yaml

# is-on-device-builder detects if this make invocation is (probably) running inside an esphome container
.PHONY: is-on-device-builder
is-on-device-builder:
	@[ -f /esphome/esphome.egg-info/PKG-INFO ] || (echo >&2 "This command must be run within the esphome container" && exit 1)

.PHONY: link
link:
	$(KUBECTL_EXEC) make -C /data/configs link-raw

.PHONY: link-raw
link-raw: link-devices-raw link-secrets-raw

.PHONY: link-devices
link-devices:
	$(KUBECTL_EXEC) make -C /data/configs link-devices-raw

.PHONY: link-devices-raw
link-devices-raw: $(DEVICE_FILES) is-on-device-builder
	$(foreach device,$(DEVICE_FILES),$(call link_file,/data/configs/$(device),/data/$(call device_name_for $(device))))

.PHONY: link-secrets
link-secrets:
	$(KUBECTL_EXEC) make -C /data/configs link-secrets-raw

.PHONY: link-secrets-raw
link-secrets-raw:
	$(call link_file,/data/configs/secrets.yaml,/data/secrets.yaml)

.PHONY: editorconfig-checker
editorconfig-checker:
	@editorconfig-checker
