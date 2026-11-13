CREATE OR REPLACE VIEW silver.espocrm_account AS
SELECT DISTINCT ON (NULLIF(BTRIM(id), ''))
    NULLIF(BTRIM(id), '') AS record_id,
    NULLIF(BTRIM(name), '') AS name,
    NULLIF(BTRIM(type), '') AS account_type,
    NULLIF(BTRIM(industry), '') AS industry,
    NULLIF(BTRIM(website), '') AS website,
    deleted,
    created_at,
    modified_at,
    'espocrm'::text AS source_system,
    NULLIF(BTRIM(id), '') AS source_record_id,
    _airbyte_extracted_at AS ingested_at_utc
FROM bronze.espocrm_account
WHERE NULLIF(BTRIM(id), '') IS NOT NULL
ORDER BY NULLIF(BTRIM(id), ''),
         _airbyte_extracted_at DESC,
         _airbyte_raw_id DESC;
