#!/usr/bin/env bash
set -e

# Verify that MAXMIND_LICENSE_KEY is set in the environment
if [ -z "${MAXMIND_LICENSE_KEY}" ]; then
  echo "Error: MAXMIND_LICENSE_KEY not set!"
  echo "Set the environment variable, e.g.:"
  echo "  export MAXMIND_LICENSE_KEY=<your_key>"
  echo "  ./build.sh"
  exit 1
fi

# ---------------------------------------------------------
# Synchronize git submodules
# ---------------------------------------------------------
echo "Synchronizing git submodules..."
git submodule init
git submodule update

# ---------------------------------------------------------
# Extract version information
# ---------------------------------------------------------
echo "Extracting version information..."
# Get version from odoo/src/odoo/release.py
VERSION=$(python3 -c "import sys; sys.path.append('./odoo/src'); from odoo.release import version; print(version)")
# Use current date as build date in YYYYMMDD format
BUILD_DATE=$(date +%Y%m%d)

echo "Parsed Version: $VERSION"
echo "Build Date: $BUILD_DATE"

# Write them to local files
echo "$VERSION" > VERSION
echo "$BUILD_DATE" > BUILD_DATE
echo "Wrote VERSION=$VERSION and BUILD_DATE=$BUILD_DATE to files."

# ---------------------------------------------------------
# Build and push Docker image
# ---------------------------------------------------------
# Adjust these as needed
REGISTRY="registry.mast.jacotech.net"
NAMESPACE="jaco-tech"
REPOSITORY="jt-odoo-docker"
BRANCH="master"

TAG_WITH_DATE="${VERSION}-${BRANCH}-${BUILD_DATE}"
TAG_LATEST="${VERSION}-${BRANCH}-latest"
IMAGE="${REGISTRY}/${NAMESPACE}/${REPOSITORY}"

echo "Building Docker image with tags:"
echo " • ${IMAGE}:${TAG_WITH_DATE}"
echo " • ${IMAGE}:${TAG_LATEST}"

docker build \
  --build-arg "MAXMIND_LICENSE_KEY=${MAXMIND_LICENSE_KEY}" \
  -t "${IMAGE}:${TAG_WITH_DATE}" \
  -t "${IMAGE}:${TAG_LATEST}" \
  .

echo "Pushing all tags for ${IMAGE}..."
docker push --all-tags "${IMAGE}"

# ---------------------------------------------------------
# All done
# ---------------------------------------------------------
echo "Done!"
echo "VERSION and BUILD_DATE written to local files."
echo "Docker image pushed as:"
echo "  ${IMAGE}:${TAG_WITH_DATE}"
echo "  ${IMAGE}:${TAG_LATEST}"
