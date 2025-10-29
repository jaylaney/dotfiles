#!/usr/bin/env bash

# Dotfiles installation script
# Non-destructively symlinks files into target directory (defaults to $HOME)
# - Files in root are prefixed with a dot (e.g., "zshrc" -> "~/.zshrc")
# - Files in subdirectories maintain their structure (e.g., "config/nvim/init.lua" -> "~/.config/nvim/init.lua")

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
TARGET_DIR="$HOME"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            TARGET_DIR="$arg"
            shift
            ;;
    esac
done

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Files and directories to skip
SKIP_FILES=(".git" ".DS_Store" "README.md" "CLAUDE.md" "install.sh")

should_skip() {
    local file="$1"
    for skip in "${SKIP_FILES[@]}"; do
        # Check exact match
        if [[ "$file" == "$skip" ]]; then
            return 0
        fi
        # Check if file is inside a skip directory
        if [[ "$file" == "$skip"/* ]]; then
            return 0
        fi
        # Check if any .DS_Store appears anywhere in the path
        if [[ "$skip" == ".DS_Store" ]] && [[ "$file" == *"/.DS_Store" ]]; then
            return 0
        fi
    done
    return 1
}

symlink_file() {
    local source="$1"
    local target="$2"

    # Create parent directory if needed
    local target_dir="$(dirname "$target")"
    if [[ ! -d "$target_dir" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${BLUE}[DRY RUN] Would create directory: $target_dir${NC}"
        else
            echo -e "${GREEN}Creating directory: $target_dir${NC}"
            mkdir -p "$target_dir"
        fi
    fi

    # Check if target exists
    if [[ -e "$target" ]] || [[ -L "$target" ]]; then
        if [[ -L "$target" ]]; then
            # It's a symlink - check if it points to the correct source
            local current_source="$(readlink "$target")"
            if [[ "$current_source" == "$source" ]]; then
                echo -e "${GREEN}✓ Already linked: $target${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠ Symlink exists but points elsewhere:${NC}"
                echo -e "  Target: $target"
                echo -e "  Points to: $current_source"
                echo -e "  Expected: $source"
                return 1
            fi
        else
            # It's a regular file or directory
            echo -e "${RED}✗ File already exists (not a symlink): $target${NC}"
            return 1
        fi
    else
        # Create the symlink
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${BLUE}[DRY RUN] Would symlink: $target -> $source${NC}"
        else
            echo -e "${GREEN}→ Symlinking: $target -> $source${NC}"
            ln -s "$source" "$target"
        fi
    fi
}

process_file() {
    local rel_path="$1"
    local source="$DOTFILES_DIR/$rel_path"
    local target

    # Determine target path
    if [[ "$rel_path" == */* ]]; then
        # File is in a subdirectory - maintain structure without adding dot
        target="$TARGET_DIR/.$rel_path"
    else
        # File is in root - add dot prefix
        target="$TARGET_DIR/.$rel_path"
    fi

    symlink_file "$source" "$target"
}

# Main processing
echo "Dotfiles directory: $DOTFILES_DIR"
echo "Target directory: $TARGET_DIR"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${BLUE}Mode: DRY RUN (no changes will be made)${NC}"
fi
echo ""

# Process all files recursively
while IFS= read -r -d '' file; do
    # Get relative path from dotfiles dir
    rel_path="${file#$DOTFILES_DIR/}"

    # Skip if in skip list
    if should_skip "$rel_path"; then
        continue
    fi

    # Skip if it's a directory (we only symlink files)
    if [[ -d "$file" ]]; then
        continue
    fi

    process_file "$rel_path"
done < <(find "$DOTFILES_DIR" -type f -print0)

echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${BLUE}Dry run complete! No changes were made.${NC}"
else
    echo -e "${GREEN}Installation complete!${NC}"
fi
