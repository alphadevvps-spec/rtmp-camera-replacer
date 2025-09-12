#!/bin/bash
# Setup script for building iOS tweaks on WSL2

echo "Setting up iOS development environment on WSL2..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y \
    build-essential \
    git \
    curl \
    wget \
    unzip \
    libc6-dev \
    libssl-dev \
    libffi-dev \
    python3 \
    python3-pip \
    clang \
    lld \
    llvm

# Install Theos
echo "Installing Theos..."
export THEOS=/opt/theos
sudo git clone --recursive https://github.com/theos/theos.git 

# Set up environment variables
echo 'export THEOS=/opt/theos' >> ~/.bashrc
echo 'export PATH=/bin:' >> ~/.bashrc
echo 'export THEOS_DEVICE_IP=127.0.0.1' >> ~/.bashrc
echo 'export THEOS_DEVICE_PORT=2222' >> ~/.bashrc

# Install iOS toolchain
echo "Installing iOS toolchain..."
cd /tmp
wget https://github.com/theos/sdks/archive/master.zip
unzip master.zip
sudo mv sdks-master/*.sdk /sdks/
rm -rf sdks-master master.zip

# Install Perl dependencies
sudo apt install -y perl
sudo cpan -i String::ShellQuote

# Make theos accessible
sudo chmod -R 755 

echo "Setup complete! Please restart your terminal or run: source ~/.bashrc"
echo "Then you can build your tweak with: make package"
