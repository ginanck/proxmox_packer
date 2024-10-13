
# Packer Templates

This repository contains Packer templates for building machine images across various platforms.

## Quick Start

1. **Clone the Repository**:
   
   git clone https://github.com/yourusername/packer-templates.git
   cd packer-templates
   

2. **Install Packer**: Ensure [Packer](https://www.packer.io/downloads) is installed on your machine.

3. **Build an Image**:

    just use below command as example

    ```bash
    make build OS_TYPE=ubuntu OS_VERSION=1804
    ```

## Available Templates

- **ubuntu-1804**
- **ubuntu-2004**
- **ubuntu-2204**
- **ubunut-2404**

## Requirements

- **Packer**: Download and install from the [official website](https://www.packer.io/downloads).
- **Platform Credentials**: Ensure you have the necessary credentials and tools for the platforms you are building images for (e.g., AWS CLI for AWS templates).

## Contributing

Contributions are welcome! Please fork the repository and submit a pull request with your changes. Ensure that your code adheres to the existing style and includes appropriate documentation.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
