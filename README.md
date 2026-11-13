# Projet Big Data — Kamel Mahdi Gherbi

M1 MIAGE, Université Paris-Saclay · UE DSID · 2026–2027

Le projet charge trois sources dans PostgreSQL, puis expose cinq vues Silver indépendantes. Les preuves et les résultats concernent les lots du 13 novembre 2026.

| Source | Parcours | Résultat du lot de référence |
| --- | --- | --- |
| Prix des carburants | API publique GET → Airbyte Builder → MinIO JSONL → Airbyte Source S3 → `bronze.api_prix_carburants` | 9 834 lignes et identifiants distincts |
| Départements de l’Insee | CSV HTTPS → Airbyte File → MinIO CSV → Airbyte Source S3 → `bronze.csv_departements` | 101 lignes et codes distincts |
| EspoCRM | EspoCRM → MariaDB → Airbyte MySQL → `bronze.espocrm_account`, `bronze.espocrm_contact`, `bronze.espocrm_opportunity` | Après les nouvelles saisies : 2 comptes, 4 contacts, 2 opportunités |

## 1. Démarrer les services

Cloner le dépôt, puis suivre le [guide Docker et Airbyte](compose/README_DOCKER.md) depuis `compose/`. Il couvre les prérequis, l’installation Windows/macOS/Linux, la création de `compose/.env`, le démarrage des services, le bucket privé `dsid-raw` et la vérification du compte CRM en lecture seule. La configuration de référence utilise Airbyte 2.5.0 avec abctl v0.30.4.

## 2. Recréer et synchroniser les connexions

Suivre le [guide de configuration Airbyte](airbyte/README_AIRBYTE.md). Recréer les sources et les destinations et tester leurs connexions avant toute synchronisation. Depuis Airbyte, utiliser l’adresse hôte validée dans le guide Docker.

1. **API** — Importer et publier le [manifeste Builder](airbyte/api_prix_des_carburants_france_v_2.yaml). Synchroniser l’API vers MinIO et identifier l’objet JSONL. Sélectionner sa clé dans Source S3 avant de synchroniser vers Bronze. Contrôler le nombre de lignes, les clés et le fichier source. Le [manifeste API](data/manifestes/api_prix_carburants_1794580622068_0.json) décrit le lot historique. Une collecte sur l’API en direct crée un nouveau lot dont le volume peut varier.
2. **CSV** — Archiver le [CSV Insee original](data/v_departement_2026.csv) dans MinIO et vérifier son SHA-256. Synchroniser File vers MinIO, puis charger uniquement le CSV produit par Airbyte dans Bronze. Le [manifeste CSV](data/manifestes/csv_departements_2026.json) sépare les deux fichiers et leurs empreintes. Contrôler les 101 lignes, l’unicité des codes et la présence de `01`, `2A` et `2B`.
3. **CRM** — Synchroniser l’état initial des comptes, contacts et opportunités et relever leurs volumes dans Bronze. Créer un compte, deux contacts reliés au compte et une opportunité reliée au même compte. Relever leurs identifiants, resynchroniser, puis vérifier l’arrivée des quatre lignes et les rattachements. Sur une instance neuve, les volumes de départ peuvent différer. Les écarts attendus sont +1 compte, +2 contacts et +1 opportunité, en l’absence d’autres changements.

## 3. Créer les vues Silver

Dans [Adminer](http://localhost:8082), utiliser le système **PostgreSQL**, le serveur `postgres` et la base `warehouse`. Se connecter avec les valeurs locales de `compose/.env`. Dans **Requête SQL**, exécuter les cinq scripts ci-dessous après le chargement des tables Bronze correspondantes.

1. [Stations-service](sql/silver/api_station.sql)
2. [Départements](sql/silver/csv_departement.sql)
3. [Comptes EspoCRM](sql/silver/espocrm_account.sql)
4. [Contacts EspoCRM](sql/silver/espocrm_contact.sql)
5. [Opportunités EspoCRM](sql/silver/espocrm_opportunity.sql)

## 4. Rejouer les contrôles

| Script | Résultats à vérifier |
| --- | --- |
| [API](sql/tests/api_station.sql) | Sur le lot historique, 9 834 lignes, volumes réconciliés, aucune clé absente, aucun doublon, aucune anomalie de traçabilité et aucun prix négatif. Sur un nouveau lot, comparer à son volume Bronze. |
| [CSV](sql/tests/csv_departement.sql) | 101 lignes et codes distincts, aucune anomalie d’identifiant ni de traçabilité, une occurrence pour chacun des codes `01`, `2A` et `2B`. |
| [CRM](sql/tests/espocrm.sql) | Identifier les volumes Bronze et Silver de l’exécution. Contrôler l’unicité et la traçabilité, les trois rattachements du scénario et les types et noms de colonnes. Pour de nouvelles fiches, remplacer dans la requête de rattachement les trois identifiants attendus et celui du compte. |

Voir le [référentiel des tests Silver](sql/tests/README.md), le [rapport LaTeX](rapport/rapport.tex) et les [preuves](preuves/). Les résultats publiés servent de référence. Le rejeu complet sur une installation neuve à partir de ces guides reste à vérifier.
