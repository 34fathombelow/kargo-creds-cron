# Makefile for kargo-creds image

REGISTRY ?= quay.io/34fathombelow
IMAGE_NAME ?= kargo-creds
# Try to get version from Chart.yaml appVersion, fallback to v0.3
CHART_APP_VERSION := $(shell grep '^appVersion:' charts/Chart.yaml 2>/dev/null | sed 's/^appVersion: *"\(.*\)"/\1/' || echo "")
VERSION ?= $(if $(CHART_APP_VERSION),$(CHART_APP_VERSION),v0.3)
IMAGE := $(REGISTRY)/$(IMAGE_NAME):$(VERSION)

# Multi-arch platforms for pushing
PLATFORMS ?= linux/amd64,linux/arm64

# Detect local host architecture and convert it to a docker platform format
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_M),x86_64)
  LOCAL_PLATFORM ?= linux/amd64
else ifeq ($(UNAME_M),amd64)
  LOCAL_PLATFORM ?= linux/amd64
else ifeq ($(UNAME_M),aarch64)
  LOCAL_PLATFORM ?= linux/arm64
else ifeq ($(UNAME_M),arm64)
  LOCAL_PLATFORM ?= linux/arm64
else ifeq ($(UNAME_M),armv7l)
  LOCAL_PLATFORM ?= linux/arm/v7
else
  $(warning Unknown architecture "$(UNAME_M)", defaulting to linux/amd64)
  LOCAL_PLATFORM ?= linux/amd64
endif

BUILDX = docker buildx build

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make build        - local build for detected platform ($(LOCAL_PLATFORM))"
	@echo "  make push         - build & push multi-arch image"
	@echo "  make release      - alias for push"
	@echo ""
	@echo "Variables (override with VAR=value):"
	@echo "  VERSION           - tag (default: $(VERSION))"
	@echo "  REGISTRY          - registry (default: $(REGISTRY))"
	@echo "  IMAGE_NAME        - name (default: $(IMAGE_NAME))"
	@echo "  PLATFORMS         - multi-arch platforms"
	@echo "  LOCAL_PLATFORM    - auto-detected: $(LOCAL_PLATFORM)"

.PHONY: build
build:
	$(BUILDX) \
		--platform=$(LOCAL_PLATFORM) \
		--provenance=false \
		--sbom=false \
		-t $(IMAGE) \
		--load \
		.

.PHONY: push
push:
	$(BUILDX) \
		--platform=$(PLATFORMS) \
		--provenance=false \
		--sbom=false \
		-t $(IMAGE) \
		--push \
		.

.PHONY: release
release: push
