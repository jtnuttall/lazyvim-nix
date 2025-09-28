#!/usr/bin/env bash
set -euo pipefail

# Script to fetch latest version information for LazyVim plugins
# Reads plugins.json and enriches it with commit, tag, and SHA256 hash data

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGINS_FILE="$REPO_ROOT/plugins.json"
OUTPUT_FILE="$REPO_ROOT/plugins-with-versions.json"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed"
    exit 1
fi

# Check if nix-prefetch-git is available
if ! command -v nix-prefetch-git &> /dev/null; then
    echo "Error: nix-prefetch-git is required but not installed"
    exit 1
fi

echo "==> Reading plugins from $PLUGINS_FILE..."

# Create a temporary file for building the updated JSON
TEMP_JSON=$(mktemp)
cp "$PLUGINS_FILE" "$TEMP_JSON"

# Get the number of plugins
PLUGIN_COUNT=$(jq '.plugins | length' "$PLUGINS_FILE")
echo "==> Processing $PLUGIN_COUNT plugins..."

# Optional limit for testing (set MAX_PLUGINS environment variable)
if [ -n "${MAX_PLUGINS:-}" ] && [ "$PLUGIN_COUNT" -gt "$MAX_PLUGINS" ]; then
    echo "   Limiting to first $MAX_PLUGINS plugins..."
    PLUGIN_COUNT="$MAX_PLUGINS"
fi

# Process each plugin
for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
    PLUGIN_NAME=$(jq -r ".plugins[$i].name" "$PLUGINS_FILE")
    OWNER=$(jq -r ".plugins[$i].owner" "$PLUGINS_FILE")
    REPO=$(jq -r ".plugins[$i].repo" "$PLUGINS_FILE")

    # Skip if owner/repo not available
    if [ "$OWNER" = "null" ] || [ "$REPO" = "null" ]; then
        echo "   ⚠ Skipping $PLUGIN_NAME (missing owner/repo info)"
        continue
    fi

    echo "   [$((i+1))/$PLUGIN_COUNT] Fetching info for $PLUGIN_NAME..."

    # GitHub API URL for latest release
    API_URL="https://api.github.com/repos/$OWNER/$REPO/releases/latest"

    # Try to get the latest release tag
    LATEST_TAG=$(curl -s "$API_URL" | jq -r '.tag_name // empty' 2>/dev/null || echo "")

    if [ -z "$LATEST_TAG" ]; then
        # No release found, get the default branch's latest commit
        echo "      No release found, fetching latest commit..."

        # Get default branch
        BRANCH_API_URL="https://api.github.com/repos/$OWNER/$REPO"
        DEFAULT_BRANCH=$(curl -s "$BRANCH_API_URL" | jq -r '.default_branch // "main"' 2>/dev/null || echo "main")

        # Get latest commit on default branch
        COMMIT_API_URL="https://api.github.com/repos/$OWNER/$REPO/commits/$DEFAULT_BRANCH"
        LATEST_COMMIT=$(curl -s "$COMMIT_API_URL" | jq -r '.sha // empty' 2>/dev/null || echo "")

        if [ -n "$LATEST_COMMIT" ]; then
            # Get SHA256 hash using nix-prefetch-git
            echo "      Fetching SHA256 for commit $LATEST_COMMIT..."
            PREFETCH_OUTPUT=$(nix-prefetch-git --quiet --url "https://github.com/$OWNER/$REPO" --rev "$LATEST_COMMIT" 2>/dev/null || echo "{}")
            SHA256=$(echo "$PREFETCH_OUTPUT" | jq -r '.sha256 // empty')

            # Update the JSON with version info
            jq ".plugins[$i].version_info = {
                \"commit\": \"$LATEST_COMMIT\",
                \"tag\": null,
                \"sha256\": \"$SHA256\",
                \"fetched_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
            }" "$TEMP_JSON" > "$TEMP_JSON.tmp" && mv "$TEMP_JSON.tmp" "$TEMP_JSON"
        else
            echo "      ⚠ Could not fetch commit info"
        fi
    else
        # Release found, use the tag
        echo "      Found release: $LATEST_TAG"

        # Get commit SHA for the tag
        TAG_API_URL="https://api.github.com/repos/$OWNER/$REPO/git/refs/tags/$LATEST_TAG"
        TAG_COMMIT=$(curl -s "$TAG_API_URL" | jq -r '.object.sha // empty' 2>/dev/null || echo "")

        if [ -n "$TAG_COMMIT" ]; then
            # Get SHA256 hash using nix-prefetch-git
            echo "      Fetching SHA256 for tag $LATEST_TAG..."
            PREFETCH_OUTPUT=$(nix-prefetch-git --quiet --url "https://github.com/$OWNER/$REPO" --rev "$LATEST_TAG" 2>/dev/null || echo "{}")
            SHA256=$(echo "$PREFETCH_OUTPUT" | jq -r '.sha256 // empty')

            # Update the JSON with version info
            jq ".plugins[$i].version_info = {
                \"commit\": \"$TAG_COMMIT\",
                \"tag\": \"$LATEST_TAG\",
                \"sha256\": \"$SHA256\",
                \"fetched_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
            }" "$TEMP_JSON" > "$TEMP_JSON.tmp" && mv "$TEMP_JSON.tmp" "$TEMP_JSON"
        else
            echo "      ⚠ Could not fetch tag commit info"
        fi
    fi

    # Add a small delay to avoid rate limiting
    sleep 0.5
done

# Move the temporary file to the output location
mv "$TEMP_JSON" "$OUTPUT_FILE"

echo "==> Version information saved to $OUTPUT_FILE"

# Show summary
PLUGINS_WITH_VERSION=$(jq '[.plugins[] | select(.version_info.sha256 != null and .version_info.sha256 != "")] | length' "$OUTPUT_FILE")
echo "==> Successfully fetched version info for $PLUGINS_WITH_VERSION/$PLUGIN_COUNT plugins"

# Check if we should update the main plugins.json
if [ "${UPDATE_MAIN_FILE:-0}" = "1" ]; then
    echo "==> Updating main plugins.json file..."
    cp "$OUTPUT_FILE" "$PLUGINS_FILE"
fi