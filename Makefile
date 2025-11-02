# Makefile in packer-templates directory
PACKER_VARS = variables

# Select the appropriate packer template by OS_TYPE ("windows" or "linux").
# For distro-specific var-files use OS_TYPE (e.g. ubuntu, debian, rocky, windows-server).
ifeq ($(OS_TYPE),windows)
PACKER_BASE = build-windows.pkr.hcl
else
PACKER_BASE = build-linux.pkr.hcl
endif

# Initialize shared plugins and both build templates
init:
	packer init $(PACKER_BASE)


# Build template. Example:
#   make build-linux OS_TYPE=ubuntu OS_VERSION=2204
#   make build-windows OS_TYPE=windows OS_VERSION=2022
build:
	packer build \
		-var-file=$(PACKER_VARS)/common.pkrvars.hcl \
		-var-file=$(PACKER_VARS)/$(OS_TYPE)-$(OS_VERSION).pkrvars.hcl \
		-var 'os_type=$(OS_TYPE)' \
		-var 'os_version=$(OS_VERSION)' \
		$(PACKER_BASE)


debug:
	PACKER_LOG=1 packer build \
		-var-file=$(PACKER_VARS)/common.pkrvars.hcl \
		-var-file=$(PACKER_VARS)/$(OS_TYPE)-$(OS_VERSION).pkrvars.hcl \
		-var 'os_type=$(OS_TYPE)' \
		-var 'os_version=$(OS_VERSION)' \
		$(PACKER_BASE)


validate:
	packer validate \
		-var-file=$(PACKER_VARS)/common.pkrvars.hcl \
		-var-file=$(PACKER_VARS)/$(OS_TYPE)-$(OS_VERSION).pkrvars.hcl \
		-var 'os_type=$(OS_TYPE)' \
		-var 'os_version=$(OS_VERSION)' \
		$(PACKER_BASE)


clean:
	@echo "Cleaning up build artifacts..."
	rm -f packer.log
	rm -f *.backup-*
	rm -rf /tmp/windows-iso-*


help:
	@echo "Available targets:"
	@echo "  init                           : Initialize shared plugins and templates"
	@echo "  build                          : Alias for build-linux (kept for backward compatibility)"
	@echo "  debug                          : Alias for debug-linux (kept for backward compatibility)"
	@echo "  validate                       : Alias for validate-linux (kept for backward compatibility)"
	@echo "  clean                          : Clean up build artifacts"
	@echo "  help                           : Show this help"
	@echo ""
	@echo "Usage examples:"
	@echo "  make build-linux OS_TYPE=ubuntu OS_VERSION=2204"
	@echo "  make build-windows OS_TYPE=windows-server OS_VERSION=2012"


.PHONY: init build validate clean help
