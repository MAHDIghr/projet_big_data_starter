CREATE OR REPLACE VIEW silver.espocrm_opportunity AS
SELECT DISTINCT ON (NULLIF(BTRIM(id), ''))
    NULLIF(BTRIM(id), '') AS record_id,
    NULLIF(BTRIM(name), '') AS name,
    NULLIF(BTRIM(stage), '') AS stage,
    amount,
    NULLIF(BTRIM(amount_currency), '') AS amount_currency,
    probability,
    close_date,
    NULLIF(BTRIM(account_id), '') AS account_id,
    NULLIF(BTRIM(contact_id), '') AS contact_id,
    deleted,
    created_at,
    modified_at,
    'espocrm'::text AS source_system,
    NULLIF(BTRIM(id), '') AS source_record_id,
    _airbyte_extracted_at AS ingested_at_utc
FROM bronze.espocrm_opportunity
WHERE NULLIF(BTRIM(id), '') IS NOT NULL
ORDER BY NULLIF(BTRIM(id), ''),
         _airbyte_extracted_at DESC,
         _airbyte_raw_id DESC;
