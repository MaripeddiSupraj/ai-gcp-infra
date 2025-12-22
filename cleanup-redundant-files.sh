#!/bin/bash

# Cleanup Script - Remove Redundant Files
# Run this after verifying test-all.sh and FINAL_GUIDE.md work correctly

set -e

echo "🧹 Cleaning up redundant files..."
echo "=================================="
echo ""

# Backup first (optional)
BACKUP_DIR="backup-$(date +%Y%m%d-%H%M%S)"
echo "Creating backup in: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Files to delete
FILES_TO_DELETE=(
    # Redundant documentation
    "CLIENT_GUIDE.md"
    
    # Redundant test scripts
    "CLIENT-API-TEST.sh"
    "CLIENT-PERSISTENCE-API-TEST.sh"
    "CLIENT-PERSISTENCE-TEST.sh"
    "HANDOVER_TEST.sh"
    "test-enhanced-persistence.sh"
    "test-persistence-professional.sh"
    "test-session-manager.sh"
    "test-concurrent-users.sh"
    "test-final-persistence.sh"
    
    # Redundant setup scripts
    "QUICK-SETUP.sh"
    
    # System files
    ".DS_Store"
)

echo "Files to be deleted:"
for file in "${FILES_TO_DELETE[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
        # Copy to backup
        cp "$file" "$BACKUP_DIR/" 2>/dev/null || true
    else
        echo "  ⨯ $file (not found)"
    fi
done

echo ""
read -p "Proceed with deletion? (y/N): " confirm

if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    echo ""
    echo "Deleting files..."
    
    for file in "${FILES_TO_DELETE[@]}"; do
        if [ -f "$file" ]; then
            rm "$file"
            echo "  ✓ Deleted: $file"
        fi
    done
    
    echo ""
    echo "✅ Cleanup complete!"
    echo ""
    echo "Summary:"
    echo "  - Deleted: $(ls "$BACKUP_DIR" 2>/dev/null | wc -l) files"
    echo "  - Backup: $BACKUP_DIR/"
    echo ""
    echo "New consolidated files:"
    echo "  📝 FINAL_GUIDE.md - Complete documentation"
    echo "  🧪 test-all.sh - All tests in one script"
    echo ""
    
    # Update .gitignore
    if ! grep -q "^.DS_Store$" .gitignore 2>/dev/null; then
        echo ".DS_Store" >> .gitignore
        echo "  ✓ Added .DS_Store to .gitignore"
    fi
    
else
    echo ""
    echo "Cleanup cancelled. No files deleted."
    rm -rf "$BACKUP_DIR"
fi
