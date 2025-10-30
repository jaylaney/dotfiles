#!/usr/bin/env bash

# Dotfiles installation script
# Non-destructively symlinks files into target directory (defaults to $HOME)
# - Files in root are prefixed with a dot (e.g., "zshrc" -> "~/.zshrc")
# - Files in subdirectories maintain their structure (e.g., "config/nvim/init.lua" -> "~/.config/nvim/init.lua")

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_DIR/dotfiles"
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

# Show diff between two files
show_diff() {
    local source="$1"
    local target="$2"

    echo ""
    echo -e "${BLUE}=== Diff: $target (current) vs $source (new) ===${NC}"

    # If target is a symlink, resolve it first
    if [[ -L "$target" ]]; then
        local resolved_target="$(readlink "$target")"
        if [[ -f "$resolved_target" ]]; then
            diff -u "$resolved_target" "$source" || true
        else
            echo -e "${YELLOW}Cannot diff: symlink points to non-existent file${NC}"
        fi
    elif [[ -f "$target" ]]; then
        diff -u "$target" "$source" || true
    else
        echo -e "${YELLOW}Cannot diff: target is not a regular file${NC}"
    fi
    echo -e "${BLUE}=== End of diff ===${NC}"
    echo ""
}

# Backup and overwrite a file/symlink
backup_and_overwrite() {
    local source="$1"
    local target="$2"
    local timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup="$target.backup.$timestamp"

    echo -e "${YELLOW}Creating backup: $backup${NC}"

    # Move existing file/symlink to backup
    mv "$target" "$backup"

    # Create new symlink
    echo -e "${GREEN}→ Symlinking: $target -> $source${NC}"
    ln -s "$source" "$target"

    return 0
}

# Interactive prompt for conflict resolution
prompt_conflict_resolution() {
    local source="$1"
    local target="$2"
    local conflict_type="$3"  # "file" or "symlink"

    while true; do
        echo ""
        if [[ "$conflict_type" == "symlink" ]]; then
            local current_source="$(readlink "$target")"
            echo -e "${YELLOW}⚠ Conflict: Symlink points to different location${NC}"
            echo -e "  Target: $target"
            echo -e "  Currently points to: $current_source"
            echo -e "  Should point to: $source"
        else
            echo -e "${YELLOW}⚠ Conflict: File already exists${NC}"
            echo -e "  Target: $target"
            echo -e "  New source: $source"
        fi

        echo ""
        echo -e "Options: ${GREEN}[s]${NC}kip  ${BLUE}[d]${NC}iff  ${RED}[o]${NC}verwrite  ${YELLOW}[q]${NC}uit"
        read -p "Choice: " -n 1 -r choice
        echo ""

        case $choice in
            s|S)
                echo -e "${YELLOW}Skipping: $target${NC}"
                return 1
                ;;
            d|D)
                show_diff "$source" "$target"
                # Re-prompt after showing diff
                continue
                ;;
            o|O)
                backup_and_overwrite "$source" "$target"
                return 0
                ;;
            q|Q)
                echo -e "${RED}Installation cancelled by user${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                continue
                ;;
        esac
    done
}

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
                # Symlink points elsewhere - handle conflict
                if [[ "$DRY_RUN" == true ]]; then
                    echo -e "${YELLOW}[DRY RUN] Symlink conflict detected:${NC}"
                    echo -e "  Target: $target"
                    echo -e "  Points to: $current_source"
                    echo -e "  Expected: $source"
                    return 1
                else
                    prompt_conflict_resolution "$source" "$target" "symlink"
                    return $?
                fi
            fi
        else
            # It's a regular file or directory - handle conflict
            if [[ "$DRY_RUN" == true ]]; then
                echo -e "${RED}[DRY RUN] File conflict detected: $target${NC}"
                return 1
            else
                prompt_conflict_resolution "$source" "$target" "file"
                return $?
            fi
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
