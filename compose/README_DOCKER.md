# Démarrage de la stack Docker et Airbyte

## 1. Prérequis et versions

Prévoir Git, Docker Desktop sous Windows ou macOS, ou Docker Engine et le plugin Compose sous Linux. Airbyte nécessite Docker, un accès Internet pour le premier téléchargement et au moins 8 Go de RAM. Prévoir 16 Go pour l’ensemble de la stack lorsque c’est possible.

| Composant | Version ou référence du projet |
| --- | --- |
| Docker Desktop / Engine / Compose sous Windows | 4.92.0 / 29.8.0 / v5.5.1 |
| abctl | v0.30.4 |
| Airbyte | Application et chart Helm 2.5.0 |
| ingress-nginx | Application 1.15.1, chart Helm 4.15.1 |
| PostgreSQL | 18.6 |
| MariaDB | 11.8.9 |
| EspoCRM et daemon | 10.0.8 |
| Adminer | 6.1.0 |
| MinIO | Référence source du build : `RELEASE.2025-10-15T17-29-55Z`. Version indiquée par le binaire observé : `DEVELOPMENT.GOGET`. |

Le [Compose](compose.yaml) démarre six services avec des volumes persistants. Il construit MinIO depuis le [Dockerfile](Dockerfile.minio). Airbyte tourne séparément dans le cluster Kubernetes local créé par abctl.

## 2. Configurer et démarrer Compose

Depuis la racine du dépôt, créer le fichier d’environnement **si celui-ci est absent**.

**Windows PowerShell**

```powershell
Set-Location .\compose
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
notepad .env
```

**macOS et Linux**

```bash
cd compose
[ -f .env ] || cp .env.example .env
nano .env
```

Renseigner des mots de passe locaux pour PostgreSQL, MariaDB, EspoCRM et MinIO. Garder les noms de base et d’utilisateur de l’exemple pour suivre les étapes ci-dessous. Le [script PostgreSQL](init/postgres/00_schemas.sql) attribue notamment les schémas au rôle `warehouse`. Conserver `.env` sur le poste.

Depuis `compose/`, sur les trois systèmes :

```text
docker version
docker compose version
docker compose config --quiet
docker compose build minio
docker compose up -d
docker compose ps
docker compose images
```

Vérifier que les six services tournent et que PostgreSQL, MariaDB et EspoCRM sont `healthy`.

## 3. Installer la version de référence d’Airbyte

Télécharger [abctl v0.30.4](https://github.com/airbytehq/abctl/releases/tag/v0.30.4) pour Windows, macOS ou Linux et placer l’exécutable dans le `PATH`. Pour une **nouvelle installation** :

```text
abctl version
abctl local install --chart-version 2.5.0
abctl local status
abctl local credentials
```

Vérifier que le chart Airbyte apparaît `deployed` et que le chart et l’application affichent `2.5.0`. Sur une installation existante, commencer par `abctl local status`. La sortie de `abctl local credentials` contient les identifiants de l’instance et reste sur le poste.

## 4. Accès et réseau

| Service | Accès depuis le poste | Accès depuis Airbyte sur le poste Windows validé |
| --- | --- | --- |
| Airbyte | [localhost:8000](http://localhost:8000) | Interface de configuration |
| EspoCRM | [localhost:8081](http://localhost:8081) | Lecture des données CRM via MariaDB |
| Adminer | [localhost:8082](http://localhost:8082) | Interface de contrôle SQL |
| PostgreSQL | `localhost:5432` | `host.docker.internal:5432` |
| MariaDB | `localhost:3306` | `host.docker.internal:3306` |
| MinIO | API `localhost:9000`, [console sur 9001](http://localhost:9001) | `http://host.docker.internal:9000` |

Les connecteurs Airbyte tournent dans le cluster kind, qui dispose de son propre réseau. Sous macOS, tester `host.docker.internal`. Sous Linux, tester ce nom, puis si sa résolution échoue, relever la passerelle du nœud kind comme adresse candidate :

```bash
NODE=$(docker ps --filter name=airbyte-abctl-control-plane --format '{{.Names}}' | head -n 1)
docker inspect "$NODE" --format '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}'
```

Valider l’adresse retenue avec les tests de connexion Airbyte. Le transfert API MinIO → Bronze a fonctionné sous Windows avec Source S3 `4.16.4`, l’endpoint HTTP ci-dessus et Postgres `3.0.24`. Si un connecteur refuse HTTP, vérifier sa version et utiliser la configuration de référence ou un endpoint HTTPS dont le certificat est accepté par Airbyte.

## 5. Préparer PostgreSQL, MinIO et le compte CRM

- **PostgreSQL** — Dans Adminer, se connecter au serveur `postgres`, base `warehouse`, puis vérifier les schémas :

  ```sql
  SELECT schema_name
  FROM information_schema.schemata
  WHERE schema_name IN ('bronze', 'silver')
  ORDER BY schema_name;
  ```

- **MinIO** — Dans la console, les valeurs `MINIO_ROOT_USER` et `MINIO_ROOT_PASSWORD` du fichier local permettent d’ouvrir la console. Créer le bucket privé `dsid-raw` si nécessaire. Saisir les identifiants S3 dans les champs privés d’Airbyte.
- **MariaDB** — Sur un volume neuf, le [script d’initialisation](init/mariadb/01_airbyte_user.sh) crée `airbyte` avec `AIRBYTE_MARIADB_PASSWORD` et lui accorde `SELECT` sur la base EspoCRM. Sur un volume existant, vérifier ce compte avec une connexion MariaDB dédiée. Dans Adminer, choisir **MySQL**, serveur `mariadb`, base `espocrm`, utilisateur `airbyte`, puis exécuter `SHOW GRANTS FOR CURRENT_USER;`. Vérifier le droit `SELECT` sur `espocrm.*` et l’absence de droits d’écriture. Si le compte manque, le faire créer par l’administrateur MariaDB selon le script du kit. Utiliser ce compte de lecture dans Airbyte et garder le compte applicatif `espocrm` pour EspoCRM.

Reprendre à l’[étape de configuration des connexions](../airbyte/README_AIRBYTE.md), puis suivre le [README racine](../README.md) pour exécuter les scripts Silver et leurs tests.

## 6. Vérification et arrêt

Les [relevés du poste de référence](../preuves/docker/) documentent les images, versions, ports et services démarrés. La reprise intégrale depuis une installation neuve reste à vérifier. Sur ce poste, `docker compose stop` arrête les services Compose en conservant leurs volumes. La commande `docker compose down -v` supprime aussi les volumes Compose.
