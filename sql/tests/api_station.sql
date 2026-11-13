WITH ids_bronze AS (
    SELECT NULLIF(TRIM(_airbyte_data ->> 'id'), '') AS id
    FROM bronze.api_prix_carburants
),
bilan_bronze AS (
    SELECT COUNT(*) AS lignes_bronze,
           COUNT(*) FILTER (WHERE id IS NULL) AS ids_absents_bronze,
           COUNT(id) - COUNT(DISTINCT id) AS doublons_bronze,
           COUNT(DISTINCT id) AS lignes_silver_attendues
    FROM ids_bronze
),
bilan_silver AS (
    SELECT COUNT(*) AS lignes_silver,
           COUNT(DISTINCT record_id) AS ids_distincts_silver,
           COUNT(*) FILTER (WHERE record_id IS NULL) AS ids_absents_silver,
           COUNT(record_id) - COUNT(DISTINCT record_id) AS doublons_silver,
           COUNT(*) FILTER (
               WHERE source_system IS DISTINCT FROM 'api_prix_carburants'
                  OR source_record_id IS DISTINCT FROM record_id
                  OR ingested_at_utc IS NULL
                  OR NULLIF(TRIM(source_file_key), '') IS NULL
           ) AS lignes_sans_tracabilite,
           COUNT(*) FILTER (
               WHERE LEAST(gazole_prix, e10_prix, e85_prix,
                           gplc_prix, sp95_prix, sp98_prix) < 0
           ) AS stations_avec_prix_negatif
    FROM silver.api_station
)
SELECT b.*, s.*,
       b.lignes_silver_attendues = s.lignes_silver AS volumes_reconcilies
FROM bilan_bronze AS b
CROSS JOIN bilan_silver AS s;

SELECT column_name, data_type, numeric_precision, numeric_scale,
       column_name ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$' AS nom_conforme
FROM information_schema.columns
WHERE table_schema = 'silver'
  AND table_name = 'api_station'
ORDER BY ordinal_position;