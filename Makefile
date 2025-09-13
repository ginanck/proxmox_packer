# Makefile in packer-templates directory
PACKER_VARS = variables
PACKER_BASE = base.pkr.hcl

init:
	packer init $(PACKER_BASE)

build:
	packer build \
		-var-file=$(PACKER_VARS)/common.pkrvars.hcl \
		-var-file=$(PACKER_VARS)/$(OS_TYPE)-$(OS_VERSION).pkrvars.hcl \
		-var 'os_type=$(OS_TYPE)' \
		-var 'os_version=$(OS_VERSION)' \
		$(PACKER_BASE)

debug:
	PACKER_LOG=1 PACKER_LOG_PATH=packer.log packer build -debug \
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
	@echo "  init                           : Initialize Packer plugins"
	@echo "  build                          : Build Linux template"
	@echo "  debug                          : Build Linux template with debug logging"
	@echo "  validate                       : Validate Linux template"
	@echo "  clean                          : Clean up build artifacts"
	@echo "  help                           : Show this help"
	@echo ""
	@echo "Usage examples:"
	@echo "  make build OS_TYPE=ubuntu OS_VERSION=2204"

.PHONY: init build debug validate clean help
