# Airbyte — recréer les connexions du projet

Démarrer les services du kit et le cluster Airbyte local en suivant le [README Docker](../compose/README_DOCKER.md). L'environnement vérifié sous Windows utilise Airbyte 2.5.0 et abctl v0.30.4. Ouvrir Airbyte sur `http://localhost:8000`.

## 1. Recréer les sources et les destinations

| Source | Connecteur et réglages |
| --- | --- |
| `API Prix des carburants France` | Dans Builder, importer le [manifeste YAML](api_prix_des_carburants_france_v_2.yaml), tester puis publier le connecteur dans l'espace de travail. Créer ensuite la source à partir de ce connecteur. Le manifeste configure le flux API `prix_carburants_france`, l'extraction de `results`, la clé `id` et la pagination `limit=100` avec `offset`. |
| `insee_cog_departements_2026` | Connecteur File, dataset `departements`, format CSV, fournisseur HTTPS Public Web. Utiliser le [CSV officiel des départements de l'Insee](https://www.insee.fr/fr/statistiques/fichier/8740222/v_departement_2026.csv). Le fichier a un en-tête, utilise UTF-8 et la virgule. Lire les codes en texte pour préserver les zéros initiaux. |
| `minio_raw_prix_carburants` | Source S3. Bucket `dsid-raw`, flux `prix_carburants`, JSONL, motif `raw/api/prix_carburants/extraction_date=*/*.jsonl`, méthode Replicate Records. |
| `minio_raw_departements` | Source S3. Bucket `dsid-raw`, flux `departements`, CSV UTF-8 à virgules avec en-tête, motif `raw/csv/departements/extraction_date=*/*.csv`, méthode Replicate Records. Le motif sélectionne la sortie Airbyte datée et exclut le dossier `original/`. |
| `mariadb_espocrm` | Connecteur MySQL. Sous Windows, hôte `host.docker.internal`, port `3306`, base `espocrm`, compte de reprise `airbyte`, mot de passe local fourni par `AIRBYTE_MARIADB_PASSWORD`. Voir la vérification des droits ci-dessous. |

| Destination | Connecteur et réglages |
| --- | --- |
| `minio_raw_prix_des_carburants` | Destination S3, bucket privé `dsid-raw`, préfixe `raw/api/prix_carburants`, format JSONL. Modèle de chemin `extraction_date=${YEAR}-${MONTH}-${DAY}/${EPOCH}_`. |
| `minio_raw_departements` | Destination S3 dédiée au CSV, bucket `dsid-raw`. Le parcours documenté utilise `raw/csv/departements` et une sortie CSV datée. Vérifier le chemin et les options de sortie enregistrés avant le rejeu, comme indiqué en section 4. |
| `bronze` | Destination Postgres 3.0.24 pour le flux API observé. Sous Windows, hôte `host.docker.internal`, port `5432`, base `warehouse`, schéma par défaut `bronze`. Utiliser `POSTGRES_USER` et `POSTGRES_PASSWORD` du fichier local. Le réglage observé pour cette destination locale est `SSL mode: disable`, sans tunnel SSH. |

Pour MinIO, le flux API a été validé sous Windows avec **Source S3 4.16.4**, l'endpoint `http://host.docker.internal:9000` et la région `us-east-1`. Tester la connexion avant de lancer le chargement Bronze. Saisir les clés MinIO dans les champs privés d'Airbyte. Pour les différences réseau entre systèmes, suivre le [README Docker](../compose/README_DOCKER.md).

## 2. Recréer les cinq connexions

Les cinq connexions sont activées, en déclenchement **Manual**, avec le namespace **Destination-defined**. Elles utilisent **Propagate field changes only**, avec les notifications de changement de schéma activées et le remplissage rétroactif des colonnes désactivé. Pour les destinations PostgreSQL, **Destination-defined** reprend le schéma `bronze`.

| Nom affiché | Source | Destination | Stream Prefix |
| --- | --- | --- | --- |
| `api_prix_carburants → minio_raw` | `API Prix des carburants France` | `minio_raw_prix_des_carburants` | `api_` |
| `csv_departements → minio_raw` | `insee_cog_departements_2026` | `minio_raw_departements` | `csv_` |
| `minio_raw → bronze` | `minio_raw_prix_carburants` | `bronze` | `api_` |
| `minio_raw → bronze` | `minio_raw_departements` | `bronze` | `csv_` |
| `espocrm → bronze` | `mariadb_espocrm` | `bronze` | `espocrm_` |

Identifier les deux connexions `minio_raw → bronze` par leur **source**. Les préfixes des connexions PostgreSQL donnent notamment `bronze.api_prix_carburants` et `bronze.csv_departements`. Le préfixe CRM donne `bronze.espocrm_<flux>` pour chaque flux effectivement sélectionné.

### Sélection des champs pour le chargement Bronze

- **Carburants** · Garder `_airbyte_data`, `_ab_source_file_url` et `_ab_source_file_last_modified`.
- **Départements** · Garder les sept colonnes métier du CSV et les deux champs de provenance du fichier lorsqu'ils sont proposés. Vérifier que `DEP` est détecté en texte.
- **Champs techniques entrants S3** · Exclure `_airbyte_raw_id`, `_airbyte_extracted_at`, `_airbyte_meta` et `_airbyte_generation_id` lorsqu'ils sont présents dans le flux. Le connecteur Postgres génère ces noms. Leur exclusion a résolu la collision de colonnes lors du chargement API.

## 3. Compte MariaDB du CRM

La capture de configuration de la source montrait l’utilisateur `espocrm`. Le job réussi et les contrôles SQL confirment les données chargées, sans établir quel compte le job a utilisé. Pour la reprise, utiliser le compte dédié `airbyte`, puis vérifier ses droits et lancer le test de connexion. La procédure et la requête de vérification figurent dans le [guide Docker](../compose/README_DOCKER.md#5-préparer-postgresql-minio-et-le-compte-crm).

Sélectionner les trois flux observés, `account`, `contact` et `opportunity`. Les tables livrées portent le préfixe `espocrm_`. Les rattachements au compte ont été vérifiés à partir de `account_id` dans les tables chargées.

## 4. Ordre des synchronisations et comportement au rejeu

| Connexion | Mode observé ou à confirmer | Effet du rejeu |
| --- | --- | --- |
| API → MinIO | Full Refresh – Overwrite, documenté dans le rapport | Relit l’API publique et écrit un nouvel état dans la zone d’écriture. Archiver au préalable le fichier et son manifeste hors du préfixe d’écriture pour conserver le lot historique. |
| MinIO API → Bronze | Full Refresh – Overwrite, documenté dans le rapport | Remplace la table Bronze par les enregistrements de tous les objets sélectionnés. Pour charger un seul lot, utiliser sa clé exacte comme motif. |
| CSV → MinIO | Mode d’écriture à confirmer. Pour une reprise sur un bucket vide, choisir Full Refresh – Overwrite. | En Full Refresh, le CSV public est relu et Airbyte écrit un objet daté. Conserver l’original exact dans un préfixe d’archive distinct. |
| MinIO CSV → Bronze | Full Refresh – Overwrite affiché lors de la configuration du flux | Remplace la table avec les lignes des fichiers correspondants. Sélectionner l’objet daté du lot souhaité pour éviter de charger le même référentiel plusieurs fois. |
| CRM → Bronze | Mode par flux à confirmer. Pour reproduire la démonstration sur le petit jeu CRM, Full Refresh – Overwrite est le mode proposé en l’absence d’un curseur validé. | En Full Refresh – Overwrite, les trois tables sont rechargées à partir de l’état courant de MariaDB. Un chargement de 8 lignes peut donc comprendre l’état initial et le delta. Vérifier les identifiants et les écarts dans Bronze. En mode incrémental, le curseur et l’écriture effective déterminent les lignes lues et leur traitement en destination. |

Les effets généraux des modes sont décrits dans la [documentation Airbyte](https://docs.airbyte.com/platform/using-airbyte/core-concepts/sync-modes).

1. **API** — Synchroniser l’API vers MinIO. Contrôler la clé, le nombre de lignes et le SHA-256 du JSONL. Pour rejouer le [lot historique](../data/manifestes/api_prix_carburants_1794580622068_0.json), il faut disposer de l’objet correspondant et vérifier son empreinte. S’il est indisponible, effectuer une nouvelle collecte et identifier ce nouveau lot. Lancer ensuite la connexion API vers Bronze.
2. **CSV** — Dans le bucket `dsid-raw`, déposer le [CSV officiel versionné](../data/v_departement_2026.csv) sous `raw/csv/departements/original/millesime=2026/v_departement_2026.csv` lors d’une nouvelle installation. Retélécharger l’objet et comparer son SHA-256 à celui du [manifeste](../data/manifestes/csv_departements_2026.json). Lancer File → MinIO et relever la clé du CSV produit, puis sélectionner cet objet daté dans la source S3 et charger Bronze.
3. **CRM** — Synchroniser la base initiale et relever les volumes dans Bronze. Créer un compte, deux contacts et une opportunité liée dans EspoCRM, relever les quatre identifiants, puis relancer la connexion. Vérifier les identifiants, l’écart de volumes et les liens. La [capture Airbyte](../preuves/crm/crm_03_sync_delta_airbyte.png) montre les trois flux synchronisés et leurs volumes de référence, 2 comptes, 4 contacts et 2 opportunités.
4. Contrôler Bronze à chaque étape, puis exécuter les vues Silver et les tests dans l’ordre du [README racine](../README.md#3-créer-les-vues-silver).

## 5. Paramètres restant à vérifier

- **CSV vers MinIO** — La clé observée dans le manifeste commence par `raw/csv/departements/extraction_date=` et se termine en `.csv`. Pour une reprise, configurer une sortie CSV dans `dsid-raw` et vérifier que le modèle de chemin crée ce dossier daté. Relever le mode enregistré, la version de la destination S3, la compression et l’aplatissement avant de conclure à une configuration identique.
- **CRM** — Relever la version du connecteur MySQL, le chiffrement et le mode enregistré pour chacun des trois flux. Tester la connexion avec le compte dédié après vérification de ses droits.
- **Reprise** — Consigner les versions et les résultats d’une exécution complète sur une installation neuve.
