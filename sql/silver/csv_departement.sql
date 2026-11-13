CREATE OR REPLACE VIEW silver.csv_departement AS
WITH departements AS (
    SELECT
        NULLIF(BTRIM("DEP"), '') AS code_departement,
        NULLIF(BTRIM("REG"), '') AS code_region,
        NULLIF(BTRIM("CHEFLIEU"), '') AS code_commune_chef_lieu,
        NULLIF(BTRIM("TNCC"), '') AS code_type_nom,
        NULLIF(BTRIM("NCC"), '') AS nom_majuscule,
        NULLIF(BTRIM("NCCENR"), '') AS nom_enrichi,
        NULLIF(BTRIM("LIBELLE"), '') AS libelle,
        _airbyte_extracted_at AS ingested_at_utc,
        NULLIF(BTRIM(_ab_source_file_url), '') AS source_file_key,
        _airbyte_raw_id
    FROM bronze.csv_departements
),
departements_classes AS (
    SELECT
        departements.*,
        ROW_NUMBER() OVER (
            PARTITION BY code_departement
            ORDER BY ingested_at_utc DESC, _airbyte_raw_id DESC
        ) AS rang
    FROM departements
    WHERE code_departement IS NOT NULL
)
SELECT
    code_departement AS record_id,
    code_departement,
    code_region,
    code_commune_chef_lieu,
    code_type_nom,
    nom_majuscule,
    nom_enrichi,
    libelle,
    'insee_cog_departements_2026'::text AS source_system,
    code_departement AS source_record_id,
    ingested_at_utc,
    source_file_key
FROM departements_classes
WHERE rang = 1;
