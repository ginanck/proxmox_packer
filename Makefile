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
