#!/usr/bin/env bash
set -e

# ---------------------------------------------------------
# 1) Locate Enterprise tar in local directory
# ---------------------------------------------------------
ENTERPRISE_TAR_DIR="odoo-ee-tar"
ENTERPRISE_TAR_PATTERN="odoo_*.latest.tar.gz"
ENTERPRISE_TAR_FILE=$(find "$ENTERPRISE_TAR_DIR" -name "$ENTERPRISE_TAR_PATTERN" -print -quit)

if [ -z "$ENTERPRISE_TAR_FILE" ]; then
  echo "Error: No Enterprise tar found matching '$ENTERPRISE_TAR_PATTERN' in '$ENTERPRISE_TAR_DIR'."
  exit 1
fi

echo "Found Enterprise tar: $ENTERPRISE_TAR_FILE"

# ---------------------------------------------------------
# 2) Extract Enterprise tar into a temporary directory
# ---------------------------------------------------------
TMP_ENTERPRISE_DIR=$(mktemp -d)
echo "Extracting Enterprise tar into temporary directory: $TMP_ENTERPRISE_DIR"

tar -xzf "$ENTERPRISE_TAR_FILE" -C "$TMP_ENTERPRISE_DIR" --strip-components=1

# ---------------------------------------------------------
# 3) Parse Version & Build Date from PKG-INFO
# ---------------------------------------------------------
PKG_INFO_PATH="$TMP_ENTERPRISE_DIR/odoo.egg-info/PKG-INFO"

if [ ! -f "$PKG_INFO_PATH" ]; then
  echo "Error: PKG-INFO not found in Enterprise tar extraction: $PKG_INFO_PATH"
  rm -rf "$TMP_ENTERPRISE_DIR"
  exit 1
fi

# Example line from PKG-INFO => Version: 18.0+e.20250126
VERSION_LINE=$(grep '^Version:' "$PKG_INFO_PATH" | sed 's/^Version:\s*//')
echo "Enterprise PKG-INFO => Version: $VERSION_LINE"

VERSION=$(echo "$VERSION_LINE" | cut -d '+' -f1)                     # e.g. "18.0"
BUILD_DATE=$(echo "$VERSION_LINE" | cut -d '+' -f2 | cut -d '.' -f2)  # e.g. "20250126"

echo "Parsed Version: $VERSION"
echo "Parsed Build Date: $BUILD_DATE"

# Write them to local files
echo "$VERSION" > VERSION
echo "$BUILD_DATE" > BUILD_DATE
echo "Wrote VERSION=$VERSION and BUILD_DATE=$BUILD_DATE to files."

# ---------------------------------------------------------
# 4) Copy only "odoo/addons" to "odoo/enterprise"
# ---------------------------------------------------------
ENTERPRISE_ADDONS_DIR="$TMP_ENTERPRISE_DIR/odoo/addons"
ENTERPRISE_TARGET="odoo/enterprise"

echo "Cleaning out $ENTERPRISE_TARGET..."
rm -rf "$ENTERPRISE_TARGET"
mkdir -p "$ENTERPRISE_TARGET"

if [ ! -d "$ENTERPRISE_ADDONS_DIR" ]; then
  echo "Warning: Directory $ENTERPRISE_ADDONS_DIR doesn't exist, skipping copy."
else
  echo "Copying Enterprise addons to $ENTERPRISE_TARGET"
  cp -R "$ENTERPRISE_ADDONS_DIR"/* "$ENTERPRISE_TARGET"/
fi

# ---------------------------------------------------------
# 5) Clean up the temporary Enterprise directory
# ---------------------------------------------------------
echo "Cleaning up temporary Enterprise directory..."
rm -rf "$TMP_ENTERPRISE_DIR"

# ---------------------------------------------------------
# 6) Download & Unpack Community Tar
# ---------------------------------------------------------
COMMUNITY_SRC_DIR="odoo/src"
echo "Cleaning out $COMMUNITY_SRC_DIR ..."
rm -rf "$COMMUNITY_SRC_DIR"
mkdir -p "$COMMUNITY_SRC_DIR"

COMMUNITY_URL="https://nightly.odoo.com/${VERSION}/nightly/src/odoo_${VERSION}.${BUILD_DATE}.tar.gz"
TMP_COMMUNITY_TAR="/tmp/odoo_${VERSION}.${BUILD_DATE}.tar.gz"

echo "Downloading Community tar from: $COMMUNITY_URL"
curl -SL "$COMMUNITY_URL" -o "$TMP_COMMUNITY_TAR"

echo "Unpacking Community tar into $COMMUNITY_SRC_DIR (stripping top-level)..."
tar -xzf "$TMP_COMMUNITY_TAR" -C "$COMMUNITY_SRC_DIR" --strip-components=1

# ---------------------------------------------------------
# 7) Cleanup Community tar from /tmp
# ---------------------------------------------------------
echo "Removing downloaded Community tar: $TMP_COMMUNITY_TAR"
rm -f "$TMP_COMMUNITY_TAR"

# ---------------------------------------------------------
# 8) Build and push Docker image
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


# Verify that MAXMIND_LICENSE_KEY is set in the environment
if [ -z "${MAXMIND_LICENSE_KEY}" ]; then
  echo "Error: MAXMIND_LICENSE_KEY not set!"
  echo "Set the environment variable, e.g.:"
  echo "  export MAXMIND_LICENSE_KEY=<your_key>"
  echo "  ./build.sh"
  exit 1
fi

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
echo "Enterprise addons are in $ENTERPRISE_TARGET"
echo "Community sources are in $COMMUNITY_SRC_DIR"
echo "VERSION and BUILD_DATE written to local files."
echo "Docker image pushed as:"
echo "  ${IMAGE}:${TAG_WITH_DATE}"
echo "  ${IMAGE}:${TAG_LATEST}"