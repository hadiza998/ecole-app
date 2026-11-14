#!/bin/bash
# Sauvegarde chiffrée de la base Lakol (schémas public + auth).
# Variables obligatoires : DB_URL (adresse de connexion Supabase), BACKUP_PASSPHRASE (mot de passe de chiffrement)
# Variable facultative : PG_BIN (dossier contenant pg_dump et pg_restore)
# Usage : bash scripts/backup.sh [dossier_de_sortie]
set -euo pipefail
: "${DB_URL:?Variable DB_URL manquante (adresse de connexion à la base)}"
: "${BACKUP_PASSPHRASE:?Variable BACKUP_PASSPHRASE manquante (mot de passe de chiffrement)}"
P="${PG_BIN:+$PG_BIN/}"
OUT="${1:-.}"; mkdir -p "$OUT"
RAW="$OUT/lakol_$(date -u +%Y-%m-%d_%H%M).dump"

"${P}pg_dump" "$DB_URL" --format=custom --no-owner --no-privileges --schema=public --schema=auth --file "$RAW"

# Contrôle 1 : le fichier est lisible et contient les tables importantes
LISTE="$RAW.liste"
"${P}pg_restore" --list "$RAW" > "$LISTE"
for t in "public students" "public grades" "public payments" "public profiles" "auth users"; do
  grep -q "TABLE DATA $t " "$LISTE" || { echo "❌ Sauvegarde invalide : table « $t » absente"; rm -f "$RAW" "$LISTE"; exit 1; }
done
# Contrôle 2 : taille minimale
[ "$(wc -c < "$RAW")" -gt 20000 ] || { echo "❌ Sauvegarde trop petite, elle est suspecte"; rm -f "$RAW" "$LISTE"; exit 1; }
rm -f "$LISTE"

# Chiffrement (les données des élèves ne doivent jamais traîner en clair)
printf '%s' "$BACKUP_PASSPHRASE" | gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 0 --symmetric --cipher-algo AES256 --output "$RAW.gpg" "$RAW"
rm -f "$RAW"
echo "✅ Sauvegarde créée : $RAW.gpg ($(wc -c < "$RAW.gpg") octets)"
