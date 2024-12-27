
# Packer Templates

This repository contains Packer templates for building machine images across various platforms.

## Quick Start

1. **Clone the Repository**:
   
   git clone https://github.com/yourusername/packer-templates.git
   cd packer-templates
   
2. **Install Packer**: Ensure [Packer](https://www.packer.io/downloads) is installed on your machine.

3. **Create Hashed Password**:
Below hashed password is used in `preceed.cfg` or `user-data` configuration files

    ```bash
    echo "rocky" | mkpasswd -m yescrypt --stdin
    ```

    or

    ```bash
    echo "rocky" | openssl passwd -6 -stdin
    ```

4. **Build an Image**:

    just use below command as example

    ```bash
    make build OS_TYPE=ubuntu OS_VERSION=1804
    ```

    or

    ```bash
    make build OS_TYPE=debian OS_VERSION=10
    ```

    or build image with debug mode

    ```bash
    make debug OS_TYPE=rocky OS_VERSION=8
    ```

## Available Templates

- **ubuntu-1804**
- **ubuntu-2004**
- **ubuntu-2204**
- **ubuntu-2404**
- **debian-10**
- **debian-11**
- **debian-12**
- **alma-8**
- **alma-9**
- **rocky-8**
- **rocky-9**

## Requirements

- **Packer**: Download and install from the [official website](https://www.packer.io/downloads).
- **Platform Credentials**: Ensure you have the necessary credentials and tools for the platforms you are building images for (e.g., AWS CLI for AWS templates).

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes. Ensure that your code adheres to the existing style and includes appropriate documentation.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
