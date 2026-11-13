-- Lot Insee 2026 : 101 lignes et codes distincts, aucune anomalie,
-- une occurrence pour chacun des codes 01, 2A et 2B.
SELECT
    COUNT(*) AS lignes_silver,
    COUNT(DISTINCT record_id) AS codes_distincts,
    COUNT(*) FILTER (WHERE record_id IS NULL) AS codes_absents,
    COUNT(record_id) - COUNT(DISTINCT record_id) AS doublons,
    COUNT(*) FILTER (
        WHERE source_system IS DISTINCT FROM 'insee_cog_departements_2026'
           OR source_record_id IS DISTINCT FROM record_id
           OR ingested_at_utc IS NULL
           OR source_file_key IS NULL
    ) AS lignes_sans_tracabilite,
    COUNT(*) FILTER (WHERE code_departement = '01') AS code_01,
    COUNT(*) FILTER (WHERE code_departement = '2A') AS code_2a,
    COUNT(*) FILTER (WHERE code_departement = '2B') AS code_2b
FROM silver.csv_departement;
