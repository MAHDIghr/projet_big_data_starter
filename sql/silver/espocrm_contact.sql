CREATE OR REPLACE VIEW silver.espocrm_contact AS
SELECT DISTINCT ON (NULLIF(BTRIM(id), ''))
    NULLIF(BTRIM(id), '') AS record_id,
    NULLIF(BTRIM(first_name), '') AS first_name,
    NULLIF(BTRIM(last_name), '') AS last_name,
    NULLIF(BTRIM(account_id), '') AS account_id,
    do_not_call,
    deleted,
    created_at,
    modified_at,
    'espocrm'::text AS source_system,
    NULLIF(BTRIM(id), '') AS source_record_id,
    _airbyte_extracted_at AS ingested_at_utc
FROM bronze.espocrm_contact
WHERE NULLIF(BTRIM(id), '') IS NOT NULL
ORDER BY NULLIF(BTRIM(id), ''),
         _airbyte_extracted_at DESC,
         _airbyte_raw_id DESC;
