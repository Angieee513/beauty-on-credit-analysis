CREATE DATABASE beauty_on_credit;
USE beauty_on_credit;
SELECT DATABASE();
CREATE TABLE procedure_volume (
    year INT,
    procedure_type VARCHAR(50),
    category VARCHAR(50),
    procedure_name VARCHAR(255),
    volume INT
);
CREATE TABLE consumer_demographics (
    year INT,
    age_group VARCHAR(20),
    procedure_type VARCHAR(50),
    category VARCHAR(50),
    procedure_name VARCHAR(255),
    volume INT
);
CREATE TABLE procedure_pricing (
    procedure_type VARCHAR(50),
    category VARCHAR(50),
    procedure_name VARCHAR(255),
    low_fee_usd DECIMAL(10,2),
    high_fee_usd DECIMAL(10,2),
    average_fee_usd DECIMAL(10,2),
    source_label VARCHAR(100),
    source_url TEXT,
    record_origin VARCHAR(50)
);
CREATE TABLE procedure_recurrence (
    procedure_type VARCHAR(50),
    category VARCHAR(50),
    procedure_name VARCHAR(255),
    recurrence_model VARCHAR(100),
    typical_frequency VARCHAR(100),
    business_model VARCHAR(150),
    evidence_note TEXT
);
TRUNCATE TABLE procedure_recurrence;
ALTER TABLE procedure_recurrence
DROP COLUMN low_fee_usd,
DROP COLUMN high_fee_usd,
DROP COLUMN average_fee_usd,
DROP COLUMN source_label,
DROP COLUMN source_url,
DROP COLUMN procedure_name;
TRUNCATE TABLE procedure_recurrence;

CREATE TABLE aesthetics_revenue (
    company VARCHAR(100),
    year INT,
    segment VARCHAR(100),
    metric VARCHAR(50),
    value DECIMAL(15,2),
    unit VARCHAR(50),
    data_note TEXT
);
CREATE TABLE financing_market (
    metric VARCHAR(255),
    year INT,
    value_numeric DECIMAL(15,2),
    value_min DECIMAL(15,2),
    value_max DECIMAL(15,2),
    qualifier VARCHAR(50),
    raw_value VARCHAR(50),
    unit VARCHAR(50),
    scope VARCHAR(50),
    notes TEXT,
    source VARCHAR(100),
    source_url TEXT
);
TRUNCATE TABLE financing_market;
ALTER TABLE financing_market
DROP COLUMN company,
DROP COLUMN value;

-- check tables
USE beauty_on_credit;
SELECT 'procedure_volume' AS table_name, COUNT(*) AS row_count
FROM procedure_volume
UNION ALL
SELECT 'consumer_demographics', COUNT(*)
FROM consumer_demographics
UNION ALL
SELECT 'procedure_pricing', COUNT(*)
FROM procedure_pricing
UNION ALL
SELECT 'procedure_recurrence', COUNT(*)
FROM procedure_recurrence
UNION ALL
SELECT 'aesthetics_revenue', COUNT(*)
FROM aesthetics_revenue
UNION ALL
SELECT 'financing_market', COUNT(*)
FROM financing_market;
SELECT
    SUM(procedure_name IS NULL) AS null_procedure_names,
    SUM(volume IS NULL) AS null_volumes
FROM procedure_volume;
TRUNCATE TABLE procedure_volume;
ALTER TABLE procedure_volume
DROP COLUMN `procedure`;
SELECT
    SUM(procedure_name IS NULL) AS null_procedure_names,
    SUM(average_fee_usd IS NULL) AS null_average_fees
FROM procedure_pricing;

-- Is aesthetic demand driven more by surgical procedures or minimally invasive treatments?
WITH type_volume AS (
    SELECT year, procedure_type, SUM(volume) AS total_volume
    FROM procedure_volume
    GROUP BY year, procedure_type)
SELECT
    year,
    procedure_type,
    total_volume,
    ROUND(
        total_volume * 100.0/SUM(total_volume) OVER (PARTITION BY year),2
    ) AS market_share_pct
FROM type_volume
ORDER BY year, total_volume DESC;

-- which project support the 94%？
WITH ranked_procedures AS (
    SELECT
        year,
        procedure_type,
        procedure_name,
        volume,
        DENSE_RANK() OVER (
            PARTITION BY year, procedure_type
            ORDER BY volume DESC) AS ranking
    FROM procedure_volume)
SELECT
    year,
    procedure_type,
    procedure_name,
    volume,
    ranking
FROM ranked_procedures
WHERE ranking <= 5
ORDER BY year, procedure_type, ranking;

-- Which procedures gained or lost the most volume from 2023 to 2024?
WITH procedure_growth AS (
    SELECT
        year,
        procedure_type,
        procedure_name,
        volume,
        LAG(volume) OVER (
            PARTITION BY procedure_name
            ORDER BY year
        ) AS previous_volume
    FROM procedure_volume)
SELECT
    procedure_type,
    procedure_name,
    previous_volume,
    volume AS current_volume,
    volume - previous_volume AS volume_change,
    ROUND((volume - previous_volume) * 100.0/ previous_volume,2) AS growth_pct
FROM procedure_growth
WHERE year = 2024 AND previous_volume IS NOT NULL
ORDER BY volume_change DESC;

-- Recurring vs. One-Time Consumption
SELECT
    pv.procedure_name,
    pv.procedure_type,
    pv.volume,
    pr.recurrence_model,
    pr.typical_frequency,
    pr.business_model
FROM procedure_volume pv
LEFT JOIN procedure_recurrence pr
ON pv.procedure_name = pr.procedure_name
WHERE pv.year = 2024
ORDER BY pv.volume DESC;
-- unmatched records
SELECT procedure_name
FROM procedure_recurrence
ORDER BY procedure_name;
UPDATE procedure_recurrence
SET procedure_name = 'HA fillers'
WHERE procedure_name LIKE 'HA fillers%';
UPDATE procedure_recurrence
SET procedure_name = 'Non-HA fillers'
WHERE procedure_name LIKE 'Non-HA fillers%';
UPDATE procedure_recurrence
SET procedure_name = 'Lip augmentation (with injectable materials)'
WHERE procedure_name LIKE 'Lip augmentation%';
UPDATE procedure_recurrence
SET procedure_name = 'Skin resurfacing (dermabrasion, chemical peel, lasers, microdermabrasion)'
WHERE procedure_name LIKE 'Skin resurfacing%';
UPDATE procedure_recurrence
SET procedure_name = 'Noninvasive fat reduction (CoolSculpting, Liposonix, Emsculpt, Vanquish, Zerona, Kybella)'
WHERE procedure_name LIKE 'Noninvasive fat reduction%';
UPDATE procedure_recurrence
SET procedure_name = 'Nonsurgical skin tightening (Pelleve, Thermage, Ulthera)'
WHERE procedure_name LIKE 'Nonsurgical skin tightening%';
UPDATE procedure_recurrence
SET procedure_name = 'Nose reshaping (rhinoplasty)'
WHERE procedure_name = 'Rhinoplasty';
UPDATE procedure_recurrence
SET procedure_name = 'Breast augmentation (implant placement for both primary and/or revisions)'
WHERE procedure_name = 'Breast augmentation';
SELECT
    pr.procedure_name,
    CASE
        WHEN pv.procedure_name IS NOT NULL THEN 'Matched'
        ELSE 'Unmatched'
    END AS join_status
FROM procedure_recurrence pr
LEFT JOIN procedure_volume pv
    ON pr.procedure_name = pv.procedure_name
    AND pv.year = 2024
ORDER BY join_status, pr.procedure_name;

-- Which procedures combine high demand, repeat consumption, and meaningful consumer cost?
SELECT
    pv.procedure_name,
    pv.procedure_type,
    pv.volume,
    pr.recurrence_model,
    pr.typical_frequency,
    pr.business_model
FROM procedure_volume pv
LEFT JOIN procedure_recurrence pr
ON pv.procedure_name = pr.procedure_name
WHERE pv.year = 2024
ORDER BY pv.volume DESC;

SELECT
    COUNT(*) AS total_procedures,
    SUM(pp.procedure_name IS NOT NULL) AS matched_pricing,
    SUM(pp.procedure_name IS NULL) AS unmatched_pricing
FROM procedure_volume pv
LEFT JOIN procedure_pricing pp
    ON pv.procedure_name = pp.procedure_name
WHERE pv.year = 2024;

-- QA
SELECT
    pv.procedure_type,
    COUNT(*) AS total_procedures,
    COUNT(pp.average_fee_usd) AS procedures_with_price,
    ROUND(COUNT(pp.average_fee_usd) * 100.0 / COUNT(*), 2) AS pricing_coverage_pct
FROM procedure_volume pv
LEFT JOIN procedure_pricing pp
ON pv.procedure_name = pp.procedure_name
WHERE pv.year = 2024
GROUP BY pv.procedure_type;

-- Price Structure by Procedure Type
SELECT
    pv.procedure_type,
    COUNT(DISTINCT pv.procedure_name) AS procedures_with_pricing,
    ROUND(AVG(pp.average_fee_usd), 2) AS avg_procedure_fee,
    ROUND(MIN(pp.average_fee_usd), 2) AS lowest_avg_fee,
    ROUND(MAX(pp.average_fee_usd), 2) AS highest_avg_fee
FROM procedure_volume pv
JOIN procedure_pricing pp
ON pv.procedure_name = pp.procedure_name
WHERE pv.year = 2024
GROUP BY pv.procedure_type
ORDER BY avg_procedure_fee DESC;


-- Recurring vs One-Time Economics
SELECT
    pr.business_model,
    COUNT(DISTINCT pv.procedure_name) AS procedure_count,
    SUM(pv.volume) AS total_2024_volume,
    ROUND(AVG(pp.average_fee_usd), 2) AS avg_fee
FROM procedure_volume pv
JOIN procedure_recurrence pr
ON pv.procedure_name = pr.procedure_name
LEFT JOIN procedure_pricing pp
ON pv.procedure_name = pp.procedure_name
WHERE pv.year = 2024
GROUP BY pr.business_model
ORDER BY total_2024_volume DESC;

-- consolidated the raw recurrence date into 3 broader consumption models and compare
WITH procedure_economics AS (
    SELECT
        pv.procedure_name,
        pv.procedure_type,
        pv.volume,
        pr.business_model,
        pp.average_fee_usd,
        CASE
            WHEN pr.business_model IN (
                'Recurring revenue',
                'Repeat purchase',
                'Recurring service',
                'Maintenance spending') THEN 'Recurring / Maintenance'
            WHEN pr.business_model IN (
                'Package-based consumption',
                'Procedure package spending')THEN 'Treatment Cycle / Package'
            WHEN pr.business_model IN (
                'High-ticket one-time purchase',
                'High-ticket purchase with future revision potential') THEN 'High-Ticket / Low-Frequency'
        END AS consumption_model
    FROM procedure_volume pv
    JOIN procedure_recurrence pr
    ON pv.procedure_name = pr.procedure_name
    LEFT JOIN procedure_pricing pp
    ON pv.procedure_name = pp.procedure_name
    WHERE pv.year = 2024)

SELECT
    consumption_model,
    COUNT(*) AS procedure_count,
    SUM(volume) AS total_2024_volume,
    ROUND(AVG(average_fee_usd), 2) AS avg_available_fee
FROM procedure_economics
WHERE consumption_model IS NOT NULL
GROUP BY consumption_model
ORDER BY total_2024_volume DESC;


-- PART 2: Financing Market
-- What evidence shows that consumer financing is entering elective medicine?
SELECT
    metric,
    year,
    raw_value,
    unit,
    qualifier,
    notes
FROM financing_market
WHERE scope = 'elective_medical'

-- BNPL adoption is increasing
WITH bnpl_trends AS (
    SELECT
        metric,
        `year`,
        value_numeric,
        LAG(value_numeric) OVER (
            PARTITION BY metric
            ORDER BY `year`) AS previous_value
    FROM financing_market
    WHERE metric IN ('Consumers using BNPL','Average BNPL loans per borrower'))
SELECT
    metric,
    `year`,
    previous_value,
    value_numeric AS current_value,
    ROUND((value_numeric - previous_value)* 100.0 / previous_value,2) AS growth_pct
FROM bnpl_trends
WHERE previous_value IS NOT NULL
ORDER BY metric;

-- Younger Borrower Exposure
SELECT
    MAX(CASE
            WHEN metric = 'BNPL share of unsecured debt, age 18-24' THEN value_numeric
        END)AS age_18_24_share,
    MAX(CASE
            WHEN metric = 'BNPL share of unsecured debt, all borrowers' THEN value_numeric
        END)AS all_borrowers_share,
    ROUND(MAX(CASE WHEN metric = 'BNPL share of unsecured debt, age 18-24' THEN value_numeric END) 
    - MAX(CASE WHEN metric = 'BNPL share of unsecured debt, all borrowers' THEN value_numeric END),2) 
    AS percentage_point_gap
FROM financing_market
WHERE `year` = 2022;

-- why financial firms willing to make elective medicine be a loan category
-- If nearly half of these transactions can be offered at 0% APR, where is the financing economics coming from?
SELECT
    metric,
    raw_value,
    unit,
    qualifier
FROM financing_market
WHERE scope = 'elective_medical'
  AND metric IN (
      'Typical elective medical purchase size',
      'Affirm elective medical APR range',
      'Elective medical transactions at 0% APR',
      'Medical credit card average APR',
      'Affirm 30-day delinquency rate'
  )
ORDER BY metric;

-- clean sql for project presentation
-- Are the procedures adding the most absolute volume also the procedures growing the fastest in percentage terms?
WITH procedure_growth AS (
    SELECT
        year,
        procedure_type,
        procedure_name,
        volume,
        LAG(volume) OVER (
            PARTITION BY procedure_name
            ORDER BY year
        ) AS previous_volume
    FROM procedure_volume)
SELECT
    procedure_type,
    procedure_name,
    previous_volume,
    volume AS current_volume,
    volume - previous_volume AS volume_change,
    ROUND(
        (volume - previous_volume) * 100.0/ previous_volume,2) AS growth_pct
FROM procedure_growth
WHERE year = 2024
  AND previous_volume IS NOT NULL
ORDER BY volume_change DESC;


WITH procedure_economics AS (
    SELECT
        pv.procedure_name,
        pv.procedure_type,
        pv.volume,
        pr.business_model,
        pp.average_fee_usd,
        CASE
            WHEN pr.business_model IN (
                'Recurring revenue',
                'Repeat purchase',
                'Recurring service',
                'Maintenance spending')
                THEN 'Recurring / Maintenance'
            WHEN pr.business_model IN (
                'Package-based consumption',
                'Procedure package spending')
                THEN 'Treatment Cycle / Package'
            WHEN pr.business_model IN (
                'High-ticket one-time purchase',
                'High-ticket purchase with future revision potential')
                THEN 'High-Ticket / Low-Frequency'
        END AS consumption_model
    FROM procedure_volume pv
    JOIN procedure_recurrence pr
    ON pv.procedure_name = pr.procedure_name
    LEFT JOIN procedure_pricing pp
    ON pv.procedure_name = pp.procedure_name
    WHERE pv.year = 2024)
SELECT
    consumption_model,
    COUNT(*) AS procedure_count,
    SUM(volume) AS total_2024_volume,
    ROUND(AVG(average_fee_usd), 2) AS avg_available_fee
FROM procedure_economics
WHERE consumption_model IS NOT NULL
GROUP BY consumption_model
ORDER BY total_2024_volume DESC;

-- Purchase Size → Financing Cost → 0% Financing → Merchant Adoption
SELECT
    MAX(CASE
            WHEN metric = 'Elective medical merchants on Affirm network'
            THEN value_numeric END) AS elective_medical_merchants,
    MAX(CASE
            WHEN metric = 'Typical elective medical purchase size'
            THEN value_min END) AS typical_purchase_min_usd,
    MAX(CASE
            WHEN metric = 'Affirm elective medical APR range'
            THEN value_min END) AS affirm_apr_min_pct,
    MAX(CASE
            WHEN metric = 'Affirm elective medical APR range'
            THEN value_max END) AS affirm_apr_max_pct,
    MAX(CASE
            WHEN metric = 'Elective medical transactions at 0% APR'
            THEN value_numeric END) AS zero_apr_transaction_pct,
    MAX(CASE
            WHEN metric = 'Medical credit card average APR'
            THEN value_numeric END) AS medical_credit_card_apr_pct,
    MAX(
        CASE
            WHEN metric = 'Affirm 30-day delinquency rate'
            THEN value_numeric END) AS affirm_30day_delinquency_pct
FROM financing_market;