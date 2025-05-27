#!/bin/bash

set -euo pipefail

# Vérifie que jq est installé
if ! command -v jq &> /dev/null; then
  echo "Erreur : 'jq' est requis mais non installé."
  exit 1
fi

# Récupère les versions depuis npm et filtre les versions stables dès l'insertion
versions_json=$(npm view create-nx-workspace versions --json)
versions=()

while IFS= read -r version; do
  if [[ "$version" =~ (canary|beta|pr|rc|alpha) ]]; then
    echo "Ignoré (pré-release) : $version"
    continue
  fi
  versions+=("$version")
done < <(echo "$versions_json" | jq -r '.[]')

# Affiche les versions stables
echo "Versions stables :"
for version in "${versions[@]}"; do
  echo "$version"
done
