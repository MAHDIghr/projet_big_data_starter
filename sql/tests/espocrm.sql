WITH crm AS (
    SELECT 'account' AS entite, record_id, source_system,
           source_record_id, ingested_at_utc
    FROM silver.espocrm_account
    UNION ALL
    SELECT 'contact', record_id, source_system,
           source_record_id, ingested_at_utc
    FROM silver.espocrm_contact
    UNION ALL
    SELECT 'opportunity', record_id, source_system,
           source_record_id, ingested_at_utc
    FROM silver.espocrm_opportunity
)
SELECT
    entite,
    COUNT(*) AS lignes_silver,
    COUNT(DISTINCT record_id) AS ids_distincts,
    COUNT(*) FILTER (WHERE record_id IS NULL) AS ids_absents,
    COUNT(record_id) - COUNT(DISTINCT record_id) AS doublons,
    COUNT(*) FILTER (
        WHERE source_system IS DISTINCT FROM 'espocrm'
           OR source_record_id IS DISTINCT FROM record_id
           OR ingested_at_utc IS NULL
    ) AS lignes_sans_tracabilite
FROM crm
GROUP BY entite
ORDER BY entite;

-- Contrôle des rattachements pour les identifiants du lot de démonstration.
WITH attendus (entite, record_id) AS (
    VALUES
        ('contact',     '6af787c4746e9e223'),
        ('contact',     '6af787b4724e36815'),
        ('opportunity', '6af787ec38e9debdd')
),
fiches AS (
    SELECT 'contact' AS entite, record_id, account_id
    FROM silver.espocrm_contact
    UNION ALL
    SELECT 'opportunity', record_id, account_id
    FROM silver.espocrm_opportunity
)
SELECT
    e.entite,
    e.record_id AS id_attendu,
    f.record_id IS NOT NULL AS fiche_presente,
    f.account_id AS compte_reference,
    a.record_id AS compte_retrouve,
    a.record_id IS NOT DISTINCT FROM '6af78794aba6cf05e'
        AS rattachement_correct
FROM attendus AS e
LEFT JOIN fiches AS f
    ON f.entite = e.entite AND f.record_id = e.record_id
LEFT JOIN silver.espocrm_account AS a
    ON a.record_id = f.account_id
ORDER BY e.entite, e.record_id;

-- Inventaire des types PostgreSQL et vérification du nommage en snake_case.
SELECT
    table_name,
    column_name,
    data_type,
    column_name ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$' AS nom_conforme
FROM information_schema.columns
WHERE table_schema = 'silver'
  AND table_name IN (
      'espocrm_account',
      'espocrm_contact',
      'espocrm_opportunity'
  )
ORDER BY table_name, ordinal_position;
