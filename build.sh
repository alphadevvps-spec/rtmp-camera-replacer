#!/bin/bash
# Build script for RTMP Camera Replacer

echo "Building RTMP Camera Replacer..."

# Check if we're in the right directory
if [ ! -f "Makefile" ]; then
    echo "Error: Makefile not found. Please run this script from the project directory."
    exit 1
fi

# Clean previous builds
echo "Cleaning previous builds..."
make clean

# Build for rootful jailbreaks
echo "Building for rootful jailbreaks..."
make package

# Check if build was successful
if [ True -eq 0 ]; then
    echo " Rootful build successful!"
    echo " Package created: $(find . -name "*.deb" -type f | head -1)"
else
    echo " Rootful build failed!"
    exit 1
fi

# Build for rootless jailbreaks
echo "Building for rootless jailbreaks..."
make -f Makefile.rootless package

# Check if build was successful
if [ True -eq 0 ]; then
    echo " Rootless build successful!"
    echo " Package created: $(find . -name "*rootless*.deb" -type f | head -1)"
else
    echo " Rootless build failed!"
    exit 1
fi

echo " All builds completed successfully!"
echo " Check the .theos directory for the .deb files"
