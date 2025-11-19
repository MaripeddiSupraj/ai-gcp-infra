#!/bin/bash
# ============================================================================
# AUTOMATED CLEANUP SCRIPT FOR ORPHANED KUBERNETES RESOURCES
# ============================================================================
# This script safely cleans up orphaned resources without manual intervention
# ============================================================================

set -e

echo "🧹 Starting automated cleanup of orphaned resources..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# ============================================================================
# 1. CLEANUP ORPHANED BACKUP PODS
# ============================================================================
log "Cleaning up orphaned backup pods..."

PENDING_BACKUPS=$(kubectl get pods --field-selector=status.phase=Pending | grep "^backup-" | wc -l || echo "0")
if [ "$PENDING_BACKUPS" -gt 0 ]; then
    log "Found $PENDING_BACKUPS orphaned backup pods. Deleting..."
    kubectl get pods --field-selector=status.phase=Pending | grep "^backup-" | awk '{print $1}' | xargs kubectl delete pod --ignore-not-found=true
    log "✅ Deleted $PENDING_BACKUPS orphaned backup pods"
else
    log "✅ No orphaned backup pods found"
fi

# ============================================================================
# 2. CLEANUP ORPHANED USER SERVICES
# ============================================================================
log "Cleaning up orphaned user services..."

# Get all user services
USER_SERVICES=$(kubectl get svc | grep "^user-" | awk '{print $1}' || echo "")
ORPHANED_COUNT=0

if [ -n "$USER_SERVICES" ]; then
    for svc in $USER_SERVICES; do
        # Check if corresponding pod exists
        if ! kubectl get pods | grep -q "^$svc-"; then
            log "Deleting orphaned service: $svc"
            kubectl delete svc "$svc" --ignore-not-found=true
            ((ORPHANED_COUNT++))
        fi
    done
    log "✅ Deleted $ORPHANED_COUNT orphaned user services"
else
    log "✅ No user services found"
fi

# ============================================================================
# 3. CLEANUP ORPHANED PVCS
# ============================================================================
log "Checking for orphaned PVCs..."

# Get PVCs that are not bound or have no corresponding pods
ORPHANED_PVCS=$(kubectl get pvc | grep -E "(Available|Failed)" | awk '{print $1}' || echo "")
PVC_COUNT=0

if [ -n "$ORPHANED_PVCS" ]; then
    for pvc in $ORPHANED_PVCS; do
        warn "Found potentially orphaned PVC: $pvc"
        # Don't auto-delete PVCs - they contain data
        ((PVC_COUNT++))
    done
    if [ "$PVC_COUNT" -gt 0 ]; then
        warn "⚠️  Found $PVC_COUNT potentially orphaned PVCs. Manual review recommended."
    fi
else
    log "✅ No orphaned PVCs found"
fi

# ============================================================================
# 4. RESOURCE SUMMARY
# ============================================================================
log "📊 Cleanup Summary:"
echo "  • Backup pods cleaned: $PENDING_BACKUPS"
echo "  • User services cleaned: $ORPHANED_COUNT"
echo "  • PVCs requiring review: $PVC_COUNT"

# ============================================================================
# 5. CURRENT RESOURCE STATUS
# ============================================================================
log "📈 Current cluster status:"
echo "Active pods:"
kubectl get pods | grep -E "(Running|Ready)" | wc -l
echo "Active services:"
kubectl get svc | grep -v kubernetes | wc -l
echo "Active PVCs:"
kubectl get pvc | grep Bound | wc -l

log "🎉 Cleanup completed successfully!"