CREATE OR REPLACE VIEW silver.api_station AS
WITH stations AS (
    SELECT
        NULLIF(TRIM(_airbyte_data ->> 'id'), '') AS source_record_id,
        _airbyte_data AS donnees,
        _airbyte_extracted_at AS ingested_at_utc,
        _ab_source_file_url AS source_file_key,
        _airbyte_raw_id
    FROM bronze.api_prix_carburants
),
stations_classees AS (
    SELECT
        source_record_id,
        donnees,
        ingested_at_utc,
        source_file_key,
        ROW_NUMBER() OVER (
            PARTITION BY source_record_id
            ORDER BY ingested_at_utc DESC NULLS LAST,
                     _airbyte_raw_id DESC
        ) AS rang
    FROM stations
    WHERE source_record_id IS NOT NULL
)
SELECT
    source_record_id AS record_id,
    NULLIF(TRIM(donnees ->> 'cp'), '') AS code_postal,
    NULLIF(TRIM(donnees ->> 'ville'), '') AS ville,
    NULLIF(TRIM(donnees ->> 'adresse'), '') AS adresse,
    NULLIF(TRIM(donnees ->> 'code_departement'), '') AS code_departement,
    NULLIF(TRIM(donnees ->> 'code_region'), '') AS code_region,

    (donnees ->> 'gazole_prix')::numeric(12,3) AS gazole_prix,
    (donnees ->> 'e10_prix')::numeric(12,3) AS e10_prix,
    (donnees ->> 'e85_prix')::numeric(12,3) AS e85_prix,
    (donnees ->> 'gplc_prix')::numeric(12,3) AS gplc_prix,
    (donnees ->> 'sp95_prix')::numeric(12,3) AS sp95_prix,
    (donnees ->> 'sp98_prix')::numeric(12,3) AS sp98_prix,

    (donnees ->> 'gazole_maj')::timestamptz AS gazole_mis_a_jour_at,
    (donnees ->> 'e10_maj')::timestamptz AS e10_mis_a_jour_at,
    (donnees ->> 'e85_maj')::timestamptz AS e85_mis_a_jour_at,
    (donnees ->> 'gplc_maj')::timestamptz AS gplc_mis_a_jour_at,
    (donnees ->> 'sp95_maj')::timestamptz AS sp95_mis_a_jour_at,
    (donnees ->> 'sp98_maj')::timestamptz AS sp98_mis_a_jour_at,

    donnees -> 'carburants_disponibles' AS carburants_disponibles,
    donnees -> 'carburants_indisponibles' AS carburants_indisponibles,

    'api_prix_carburants'::text AS source_system,
    source_record_id,
    ingested_at_utc,
    source_file_key
FROM stations_classees
WHERE rang = 1;