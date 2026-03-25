# Analyse API

Cette page (`dashboard/analyse.html`) mesure les temps de reponse et la taille des payloads a partir d'un swagger/OpenAPI JSON, puis estime la consommation d'energie.

Le swagger peut etre fourni en JSON ou YAML (fichier ou URL).

## Authentification

Un bearer token optionnel est disponible pour analyser des endpoints proteges.

## Modele d'energie

- Energie reseau: `kWh/GB` * taille (GB) convertie en Wh.
- Energie serveur: `puissance W` * temps (s) converti en Wh.

Les coefficients sont configurables dans l'UI. C'est une estimation factuelle basee sur des coefficients explicites.

## Export

- `Export resume`: un fichier `analysis-summary-*.json`.
- `Export endpoints`: un fichier par endpoint `analysis-endpoint-*.json`.

Placez ces fichiers dans `reports/analysis` (et `reports/analysis/endpoints`) pour alimenter le dashboard.

## CORS

Si l'API n'autorise pas les appels cross-origin, utilisez le script CLI `scripts/analyse-openapi.py`.
