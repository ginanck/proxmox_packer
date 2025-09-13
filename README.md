
# Proxmox Packer Templates

This repository contains comprehensive Packer configurations for creating VM templates in Proxmox Virtual Environment. It supports both Linux and Windows operating systems with automated provisioning and customization.

## � **Table of Contents**

1. [🚀 Supported Operating Systems](#-supported-operating-systems)
2. [📋 Prerequisites](#-prerequisites)
3. [⚡ Quick Start](#-quick-start)
4. [🛠️ Build Commands](#️-build-commands)
5. [📊 Template Specifications](#-template-specifications)
6. [🔐 Default Credentials](#-default-credentials)
7. [📁 Project Structure](#-project-structure)
8. [🐧 Linux ISO Requirements](#-linux-iso-requirements)
9. [🪟 Windows ISO Requirements](#-windows-iso-requirements)
10. [🔧 What Gets Installed](#-what-gets-installed)
11. [🛠️ Customization](#️-customization)
12. [🔍 Troubleshooting](#-troubleshooting)
13. [🤝 Contributing](#-contributing)
14. [🔒 Security Considerations](#-security-considerations)
15. [📄 License Notes](#-license-notes)
16. [📚 Additional Documentation](#-additional-documentation)

## �🚀 **Supported Operating Systems**

### **🐧 Linux Distributions**
- **Ubuntu** - 18.04, 20.04, 22.04, 24.04 LTS versions
- **Debian** - 10 (Buster), 11 (Bullseye), 12 (Bookworm)
- **Rocky Linux** - 8, 9, 10 (RHEL compatible)
- **AlmaLinux** - 8, 9, 10 (RHEL compatible)

### **🪟 Windows Versions**
- **Windows Server 2022** - Latest server version
- **Windows Server 2012 R2** - Legacy server support
- **Windows 11** - Latest desktop/workstation version
- **Windows 10** - Stable desktop/workstation version

## 📋 **Prerequisites**

### 1. Required Software
- **[Packer](https://www.packer.io/downloads)** - Latest version recommended
- **Proxmox VE** - Accessible Proxmox environment
- **Make** - For using the provided Makefile commands

### 2. Proxmox Setup
- API token with appropriate permissions
- Storage pools configured for ISOs and templates
- Network bridge configured (typically `vmbr0` or `vmbr1`)
- Sufficient storage space for templates

### 3. ISO Files
Upload the required ISO files to your Proxmox storage. See specific documentation for exact filenames:
- [Linux ISO Requirements](#linux-iso-requirements)
- [Windows ISO Requirements](WINDOWS_README.md#prerequisites)

## ⚡ **Quick Start**

### 1. **Clone Repository**
```bash
git clone https://github.com/ginanck/proxmox_packer.git
cd proxmox_packer
```

### 2. **Configure Proxmox Connection**
Edit `variables/common.pkrvars.hcl`:
```hcl
proxmox_url = "https://your-proxmox-server:8006/api2/json"
proxmox_username = "your-username@pam!your-token-id"
proxmox_api_token = "your-token-secret"
node_name = "your-proxmox-node"
```

### 3. **Initialize Packer**
```bash
make init
```

### 4. **Build Templates**

**Linux Templates:**
```bash
# Ubuntu 22.04
make build OS_TYPE=ubuntu OS_VERSION=2204

# Debian 12
make build OS_TYPE=debian OS_VERSION=12

# Rocky Linux 9
make build OS_TYPE=rocky OS_VERSION=9
```

**Windows Templates:**
```bash
# Windows 11
make build-windows OS_TYPE=windows OS_VERSION=11

# Windows Server 2022
make build-windows OS_TYPE=windows OS_VERSION=2022
```

## 🛠️ **Build Commands**

### **Standard Build**
```bash
make build OS_TYPE=<type> OS_VERSION=<version>
```

### **Windows Build**
```bash
make build-windows OS_TYPE=windows OS_VERSION=<version>
```

### **Debug Mode**
```bash
# Linux debug
make debug OS_TYPE=<type> OS_VERSION=<version>

# Windows debug
make debug-windows OS_TYPE=windows OS_VERSION=<version>
```

## 📊 **Template Specifications**

### **Linux Templates**

| Distribution | Versions | VM ID Range | Default RAM | Default Disk |
|--------------|----------|-------------|-------------|--------------|
| Ubuntu | 18.04, 20.04, 22.04, 24.04 | 8050-8053 | 4GB | 10GB |
| Debian | 10, 11, 12 | 8040-8042 | 4GB | 10GB |
| Rocky Linux | 8, 9, 10 | 8020-8022 | 4GB | 10GB |
| AlmaLinux | 8, 9, 10 | 8030-8032 | 4GB | 10GB |

### **Windows Templates**

| OS Version | VM ID | RAM | Disk | Proxmox OS Type |
|------------|-------|-----|------|-----------------|
| Windows Server 2022 | 9001 | 8GB | 60GB | win11 |
| Windows Server 2012 R2 | 9002 | 6GB | 40GB | win8 |
| Windows 11 | 9004 | 4GB | 60GB | win11 |
| Windows 10 | 9003 | 4GB | 50GB | win10 |

## 🔐 **Default Credentials**

### **Linux Systems**
- **Username**: Varies by distribution (ubuntu, debian, rocky, etc.)
- **Password**: Set in each distribution's variable file
- **SSH**: Enabled with key-based authentication

### **Windows Systems**
- **Username**: `Administrator`
- **Password**: `P@ssw0rd123!`
- **WinRM**: Enabled for automation

**⚠️ SECURITY WARNING**: Change default passwords after deploying VMs from templates!

## 📁 **Project Structure**

```
proxmox_packer/
├── base.pkr.hcl                    # Linux templates configuration
├── base.windows.pkr.hcl            # Windows templates configuration
├── Makefile                        # Build automation
├── README.md                       # This comprehensive guide
├── variables/                      # Configuration variables
│   ├── common.pkrvars.hcl          # Shared settings
│   ├── ubuntu-2204.pkrvars.hcl     # Ubuntu 22.04 settings
│   ├── debian-12.pkrvars.hcl       # Debian 12 settings
│   ├── rocky-9.pkrvars.hcl         # Rocky Linux 9 settings
│   ├── alma-9.pkrvars.hcl          # AlmaLinux 9 settings
│   ├── windows-11.pkrvars.hcl      # Windows 11 settings
│   ├── windows-2022.pkrvars.hcl    # Windows Server 2022 settings
│   └── ...                         # Other OS configurations
├── files/                          # Automation files
│   ├── ubuntu-2204/                # Ubuntu 22.04 cloud-init
│   │   ├── user-data               # Cloud-init configuration
│   │   └── meta-data               # Cloud-init metadata
│   ├── debian-12/                  # Debian 12 preseed
│   │   └── preseed.cfg             # Automated installation config
│   ├── rocky-9/                    # Rocky Linux 9 kickstart
│   │   └── ks.cfg                  # Kickstart configuration
│   ├── windows-11/                 # Windows 11 autounattend
│   │   └── autounattend.xml        # Unattended installation
│   └── ...                         # Other OS automation files
└── scripts/                       # Provisioning scripts
    ├── common/                     # Shared scripts
    │   ├── debian/                 # Debian family common scripts
    │   │   ├── 01-update.sh        # Common update script
    │   │   ├── 02-packages.sh      # Common packages
    │   │   └── 03-cleanup.sh       # Common cleanup
    │   ├── rhel/                   # RHEL family common scripts
    │   │   ├── 01-update.sh        # Common update script
    │   │   ├── 02-packages.sh      # Common packages
    │   │   └── 03-cleanup.sh       # Common cleanup
    │   └── windows/                # Windows common scripts
    │       ├── 01-windows-update.ps1   # Common update script
    │       ├── 02-install-packages.ps1 # Common packages
    │       └── 03-cleanup.ps1          # Common cleanup
    ├── ubuntu-2204/                # Ubuntu 22.04 specific scripts
    │   └── 04-grub.sh              # Ubuntu-specific GRUB config
    ├── windows-11/                 # Windows 11 specific scripts
    │   ├── 01-windows-update.ps1   # Win11-specific updates
    │   └── 02-install-packages.ps1 # Win11-specific packages
    └── ...                         # Other OS specific scripts
```

## 🐧 **Linux ISO Requirements**

Upload these ISO files to your Proxmox storage:

### **Ubuntu**
- **18.04**: `ubuntu-18.04.6-server-amd64.iso`
- **20.04**: `ubuntu-20.04.6-live-server-amd64.iso`  
- **22.04**: `ubuntu-22.04.5-live-server-amd64.iso`
- **24.04**: `ubuntu-24.04.1-live-server-amd64.iso`

### **Debian**
- **10**: `debian-10.13.0-amd64-netinst.iso`
- **11**: `debian-11.10.0-amd64-netinst.iso`
- **12**: `debian-12.6.0-amd64-netinst.iso`

### **Rocky Linux**
- **8**: `Rocky-8.10-x86_64-minimal.iso`
- **9**: `Rocky-9.4-x86_64-minimal.iso`
- **10**: `Rocky-10.0-x86_64-minimal.iso`

### **AlmaLinux**
- **8**: `AlmaLinux-8.10-x86_64-minimal.iso`
- **9**: `AlmaLinux-9.4-x86_64-minimal.iso`
- **10**: `AlmaLinux-10.0-x86_64-minimal.iso`

## 🪟 **Windows ISO Requirements**

Upload these ISO files to your Proxmox storage:

### **Windows Server**
- **2022**: `Windows_Server_2022_Eval.iso`
- **2012 R2**: `Windows_Server_2012R2_Eval.iso`

### **Windows Desktop**
- **11**: `Win11_24H2_English_x64.iso`
- **10**: `Win10_22H2_English_x64v1.iso`

## 🔧 **What Gets Installed**

### **Linux Systems**
- **System Updates**: Latest packages and security updates
- **Essential Tools**: vim, curl, wget, git, htop, tree
- **Network Tools**: net-tools, openssh-server
- **Development**: build-essential, python3, nodejs (where applicable)
- **Cloud-init**: For VM customization support
- **QEMU Guest Agent**: For better Proxmox integration

### **Windows Systems**

#### **Windows Server 2022**
- Latest Windows updates
- Chocolatey package manager
- 7zip, Notepad++, Firefox, Git, PuTTY
- .NET Framework
- OpenSSH Server
- SysInternals tools

#### **Windows Server 2012 R2**
- Compatible Windows updates
- Chocolatey (older version)
- 7zip, Notepad++, Firefox (compatible versions)
- .NET Framework 4.8
- IIS Web Server Role
- PowerShell ISE

#### **Windows 11**
- Latest Windows updates
- Chocolatey package manager
- Modern development tools (VS Code, Node.js, Python, Docker Desktop)
- WSL2 and Virtual Machine Platform
- Windows Terminal, PowerToys, WinGet
- Hyper-V and Windows Sandbox (if supported)
- Comprehensive bloatware removal
- Privacy and telemetry disabled
- Widgets and Chat integration disabled

#### **Windows 10**
- Latest Windows updates
- Chocolatey package manager
- 7zip, Notepad++, Firefox, Chrome, Git, VS Code
- Windows Terminal, PowerToys
- WSL (Windows Subsystem for Linux)
- Bloatware removal
- Telemetry disabled

## 🛠️ **Customization**

### **Adding Software Packages**

#### **Linux Systems**
Edit the provisioning scripts in `scripts/[os-type]/02-packages.sh`:
```bash
# Example: Adding Docker to Ubuntu
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

#### **Windows Systems**
Edit the provisioning scripts in `scripts/windows-[version]/02-install-packages.ps1`:
```powershell
# Example: Adding additional software
choco install -y docker-desktop
choco install -y postman
```

### **Modifying VM Settings**
Edit the relevant `.pkrvars.hcl` file in the `variables/` directory:
- CPU cores, RAM, disk size
- Network configuration  
- Storage pool settings

### **Custom Automation Files**

#### **Linux Systems**
- **Ubuntu/Debian**: Modify cloud-init files in `files/[os-version]/user-data`
- **Rocky/Alma**: Modify kickstart files in `files/[os-version]/ks.cfg`
- **Debian**: Modify preseed files in `files/[os-version]/preseed.cfg`

#### **Windows Systems**
- **All Windows**: Modify autounattend.xml files in `files/windows-[version]/autounattend.xml`
- Configure different disk partitioning
- Add additional Windows features
- Set custom computer names
- Create different user accounts

### **Script Organization Philosophy**

The project uses a hierarchical script structure that promotes code reuse:

#### **`/scripts/common/[os-family]/`**
Contains scripts shared across OS family versions:
- **`/scripts/common/debian/`** - Shared Ubuntu/Debian scripts
- **`/scripts/common/rhel/`** - Shared Rocky/Alma scripts  
- **`/scripts/common/windows/`** - Shared Windows scripts

#### **`/scripts/[os-version]/`**
Contains OS-specific scripts and customizations:
- **`/scripts/ubuntu-2204/`** - Ubuntu 22.04 specific
- **`/scripts/windows-11/`** - Windows 11 specific

#### **Script Execution Patterns**

**Option 1: Maximum code reuse (recommended)**
```hcl
provisioning_scripts = [
  "scripts/common/windows/01-windows-update.ps1",    # Common logic
  "scripts/windows-2022/02-install-packages.ps1",    # Version-specific
  "scripts/common/windows/03-cleanup.ps1"            # Common cleanup
]
```

**Option 2: Full version-specific control**
```hcl
provisioning_scripts = [
  "scripts/windows-2012r2/01-windows-update.ps1",    # All specific
  "scripts/windows-2012r2/02-install-packages.ps1",
  "scripts/common/windows/03-cleanup.ps1"
]
```

### **Creating Hashed Passwords**
For Linux preseed and cloud-init files:
```bash
# Using mkpasswd (preferred)
echo "your-password" | mkpasswd -m yescrypt --stdin

# Using openssl
echo "your-password" | openssl passwd -6 -stdin
```

## 🔍 **Troubleshooting**

### **Common Issues**

#### **All Platforms**
1. **Connection Timeouts**
   - Verify Proxmox API credentials
   - Check network connectivity to Proxmox server
   - Ensure correct node name in configuration

2. **ISO Not Found**
   - Verify ISO file is uploaded to correct storage pool
   - Check ISO filename matches exactly in variables file
   - Ensure storage pool has sufficient space

3. **Build Hangs During Installation**
   - Check Proxmox console for installation progress
   - Verify automation file configuration (cloud-init/preseed/autounattend)
   - Increase timeout values if needed

#### **Linux-Specific Issues**
4. **SSH Connection Failed**
   - Verify VM has network connectivity
   - Check SSH service is running
   - Ensure SSH keys or password authentication is configured
   - Check firewall settings

5. **Cloud-init/Preseed Errors**
   - Validate YAML syntax in cloud-init files
   - Check preseed.cfg syntax for Debian
   - Verify kickstart syntax for RHEL family

#### **Windows-Specific Issues**
6. **WinRM Connection Fails**
   - Check firewall settings in autounattend.xml
   - Verify WinRM service is running
   - Ensure correct credentials
   - Check WinRM listener configuration

7. **Windows Installation Hangs**
   - Check Proxmox console for errors
   - Verify autounattend.xml syntax
   - Ensure Windows 11 hardware requirements are bypassed
   - Increase boot_wait time

8. **Windows Updates Fail**
   - Check internet connectivity
   - Verify Windows Update service is running
   - Some older versions may need manual update configuration
   - Check PowerShell execution policy

### **Debug Mode**
Enable detailed logging:
```bash
# Linux builds
PACKER_LOG=1 PACKER_LOG_PATH=packer.log make debug OS_TYPE=ubuntu OS_VERSION=2204

# Windows builds  
PACKER_LOG=1 PACKER_LOG_PATH=packer.log make debug-windows OS_TYPE=windows OS_VERSION=11
```

### **Log Files**

#### **Packer Logs**
- **Main logs**: `packer.log` (when debug enabled)
- **Build logs**: Console output during build process

#### **Linux System Logs**
- **Ubuntu/Debian**: `/var/log/syslog`, `/var/log/dpkg.log`
- **Rocky/Alma**: `/var/log/messages`, `/var/log/yum.log`
- **Cloud-init**: `/var/log/cloud-init.log`, `/var/log/cloud-init-output.log`

#### **Windows System Logs**
- **Event Viewer**: Application and System logs
- **Setup logs**: `C:\Windows\Panther\setupact.log`
- **Windows Update**: `C:\Windows\WindowsUpdate.log`
- **PowerShell**: `$env:APPDATA\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt`

## 🤝 **Contributing**

Contributions are welcome! Please follow these guidelines:

1. **Fork** the repository
2. **Create** a feature branch
3. **Test** your changes thoroughly
4. **Submit** a pull request with clear description

### **Adding New OS Support**
1. Create variable file in `variables/[os-name]-[version].pkrvars.hcl`
2. Add automation files in `files/[os-name]-[version]/`
3. Create provisioning scripts in `scripts/[os-name]-[version]/`
4. Update documentation in this README
5. Test build process thoroughly

### **OS-Specific Contribution Guidelines**

#### **Linux Distributions**
- Follow existing cloud-init/preseed patterns
- Use common scripts where possible (`scripts/common/debian/` or `scripts/common/rhel/`)
- Test with minimal and full installation scenarios
- Ensure SSH access is properly configured

#### **Windows Versions**
- Create appropriate autounattend.xml for the version
- Use common Windows scripts where applicable (`scripts/common/windows/`)
- Test WinRM connectivity
- Ensure proper Windows feature configuration
- Document any version-specific requirements or limitations

## 🔒 **Security Considerations**

### **General Security**
1. **Change default passwords** immediately after deployment
2. **Enable firewalls** in production environments
3. **Configure appropriate user accounts** for your environment
4. **Enable automatic updates** after template deployment (disable in templates)
5. **Review installed software** and remove unnecessary packages
6. **Use SSH keys** instead of passwords for Linux systems

### **Windows-Specific Security**
1. **Configure antivirus** if required by your organization
2. **Enable Windows Defender** in production
3. **Configure Windows Update** policies appropriately
4. **Review PowerShell execution** policies
5. **Ensure proper license compliance** for all Windows deployments

### **Network Security**
1. **Configure proper VLANs** in Proxmox
2. **Set up firewall rules** for template access
3. **Use secure protocols** (SSH, HTTPS, etc.)
4. **Monitor template usage** and access

## 📄 **License Notes**

### **Software Licensing**
- **Linux**: All Linux distributions have their respective open-source licenses
- **Windows**: Ensure you have appropriate Windows licenses for templates and deployed VMs
- **Third-party software**: Review licenses for all installed packages

### **Template Usage**
This configuration does not include Windows product keys - you'll need to:
- Provide them separately during VM deployment
- Use volume licensing if available
- Ensure compliance with Microsoft licensing terms

### **Project License**
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 📚 **Additional Documentation**

- **[Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)** - Official Proxmox documentation
- **[Packer Documentation](https://www.packer.io/docs)** - Official Packer documentation  
- **[Cloud-init Documentation](https://cloud-init.readthedocs.io/)** - Cloud-init configuration guide
- **[Windows Deployment](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/)** - Windows deployment documentation

## ⭐ **Support**

If you find this project helpful, please consider giving it a star! For issues and questions, please use the GitHub Issues page.
