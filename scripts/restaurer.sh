#!/bin/bash
# Restaure une sauvegarde Lakol dans un projet Supabase NEUF (dont le schéma a déjà été créé avec supabase/schema_complet.sql).
# Usage : BACKUP_PASSPHRASE='...' bash scripts/restaurer.sh lakol_2026-11-14_0317.dump.gpg "postgresql://...adresse de la NOUVELLE base..."
# Variable facultative : PG_BIN (dossier contenant pg_restore et psql)
set -euo pipefail
FILE="${1:?Donne le fichier .gpg}"; NEW_DB="${2:?Donne ladresse de la NOUVELLE base}"
: "${BACKUP_PASSPHRASE:?Variable BACKUP_PASSPHRASE manquante}"
P="${PG_BIN:+$PG_BIN/}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
printf '%s' "$BACKUP_PASSPHRASE" | gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 0 --decrypt --output "$TMP/lakol.dump" "$FILE"
{
  echo "set session_replication_role = replica;"   # pas de déclencheurs (journal, emails) pendant la restauration
  "${P}pg_restore" --data-only --no-owner --schema=public -f - "$TMP/lakol.dump"
  "${P}pg_restore" --data-only --no-owner --schema=auth -t users -t identities -t mfa_factors -f - "$TMP/lakol.dump"
} | "${P}psql" "$NEW_DB" -v ON_ERROR_STOP=1 -q
echo "✅ Restauration terminée. Vérifie les comptes (Authentication > Users) et connecte-toi."
