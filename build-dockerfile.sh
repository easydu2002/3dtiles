#!/bin/bash

set -e  # Exit on any error

# Color definitions for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Help function
show_help() {
    echo -e "${BLUE}🔧 3D Tiles Docker Build Script${NC}"
    echo -e "${BLUE}📖 Usage: $0 [image-tag] [platform]${NC}"
    echo ""
    echo -e "${YELLOW}🎯 Examples:${NC}"
    echo "  $0                                  # Build 3dtiles:latest for linux/amd64"
    echo "  $0 3dtiles:arm64 linux/arm64        # Build an ARM64 image"
    echo "  $0 my-registry/3dtiles:v1 linux/arm64"
    echo ""
    echo -e "${YELLOW}📦 Output Docker image:${NC}"
    echo "  - Customizable with the image-tag argument"
    echo "  - Default: 3dtiles:latest"
    echo ""
    echo -e "${YELLOW}📋 Docker Build Configuration:${NC}"
    echo "  - Platform: linux/amd64 or linux/arm64"
    echo "  - Base Builder: rust:1.90.0-bookworm"
    echo "  - Base Runtime: debian:bookworm-slim"
    echo "  - Build Type: Multi-stage build with vcpkg integration"
    echo "  - Dependencies: pinned vcpkg baseline from vcpkg.json"
}

# Validate Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

# Check for help flags
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

# Function to build Docker image
build_image() {
    local image_tag=$1
    local platform=$2

    echo -e "${BLUE}🚀 Building 3D Tiles Docker image...${NC}"
    echo -e "${YELLOW}Image tag: ${image_tag}${NC}"
    echo -e "${YELLOW}Platform: ${platform}${NC}"

    docker buildx build \
        -t "${image_tag}" \
        --platform "${platform}" \
        --load \
        . || {
        echo -e "${RED}❌ Docker build failed!${NC}"
        exit 1
    }

    echo -e "${GREEN}✅ Successfully built image: ${image_tag}${NC}"
}

# Main script logic
if [ $# == 0 ]; then
    build_image "3dtiles:latest" "linux/amd64"
elif [ $# == 1 ]; then
    build_image "$1" "linux/amd64"
elif [ $# == 2 ]; then
    build_image "$1" "$2"
else
    echo -e "${RED}❌ Too many arguments!${NC}"
    show_help
    exit 1
fi

echo -e "${GREEN}🎉 Docker build process completed successfully!${NC}"

