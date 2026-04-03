#!/bin/bash
# distribute-data.sh — Upload 1794 test documents to TrueNAS shares
set -euo pipefail

IP="${1:?Usage: $0 <ip> <source-dir>}"
SRC="${2:?Usage: $0 <ip> <source-dir>}"
SSH_USER="truenas_admin"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
DEST="${SSH_USER}@${IP}:/mnt/repro-pool"

echo "=== Distributing 1794 test documents to TrueNAS ==="

# Public (html + markdown) — 113 + 159 = 272
echo "[1/11] Copying html files to public/ (113 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/html/" "$DEST/public/" 2>&1 | tail -1

echo "[2/11] Copying markdown files to public/ (159 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/markdown/" "$DEST/public/" 2>&1 | tail -1

# Engineering (odftoolkit + doc) — 617 + 155 = 772
echo "[3/11] Copying odt/odftoolkit to engineering/design-docs/ (617 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/odt/odftoolkit/" "$DEST/engineering/design-docs/" 2>&1 | tail -1

echo "[4/11] Copying doc files to engineering/source-code/ (155 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/doc/" "$DEST/engineering/source-code/" 2>&1 | tail -1

# Finance (vng-ibd) — 112
echo "[5/11] Copying docx/vng-ibd to finance/reports/ (112 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/docx/vng-ibd/" "$DEST/finance/reports/" 2>&1 | tail -1

# Shared-projects (pandoc + docspec + odt/pandoc) — 80 + 12 + 52 = 144
echo "[6/11] Copying docx/pandoc to shared-projects/project-alpha/ (80 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/docx/pandoc/" "$DEST/shared-projects/project-alpha/" 2>&1 | tail -1

echo "[7/11] Copying docx/docspec to shared-projects/project-alpha/ (12 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/docx/docspec/" "$DEST/shared-projects/project-alpha/" 2>&1 | tail -1

echo "[8/11] Copying odt/pandoc to shared-projects/project-alpha/ (52 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/odt/pandoc/" "$DEST/shared-projects/project-alpha/" 2>&1 | tail -1

# Management (rtf + odt/libreoffice) — 118 + 275 = 393
echo "[9/11] Copying rtf to management/strategy/ (118 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/rtf/" "$DEST/management/strategy/" 2>&1 | tail -1

echo "[10/11] Copying odt/libreoffice to management/hr/ (275 files)..."
rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$SRC/odt/libreoffice/" "$DEST/management/hr/" 2>&1 | tail -1

# Private — split epub across 4 users (26 + 25 + 25 + 25 = 101)
echo "[11/11] Distributing epub files to private/ (101 files split 26/25/25/25)..."
mapfile -t EPUBS < <(find "$SRC/epub" -type f | sort)
TOTAL_EPUB=${#EPUBS[@]}
COUNT=0
for f in "${EPUBS[@]}"; do
  if [ $COUNT -lt 26 ]; then
    rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$f" "$DEST/private/alice/" 2>/dev/null
  elif [ $COUNT -lt 51 ]; then
    rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$f" "$DEST/private/bob/" 2>/dev/null
  elif [ $COUNT -lt 76 ]; then
    rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$f" "$DEST/private/carol/" 2>/dev/null
  else
    rsync -a --no-times --no-perms -e "ssh -i $SSH_KEY" "$f" "$DEST/private/dave/" 2>/dev/null
  fi
  COUNT=$((COUNT+1))
done
echo "Distributed $TOTAL_EPUB epub files"

echo ""
echo "=== Distribution complete ==="
