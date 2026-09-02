-- DATABASE
USE beauty_on_credit;
-- Is aesthetic demand driven more by surgical procedures or minimally invasive treatments?
WITH type_volume AS(
    SELECT
        year, procedure_type,
        SUM(volume) AS total_volume
    FROM procedure_volume
    GROUP BY year, procedure_type)

SELECT
    year, procedure_type, total_volume,
    ROUND(total_volume * 100.0/SUM(total_volume) OVER (PARTITION BY year), 2) AS market_share_pct
FROM type_volume
ORDER BY year, total_volume DESC;

-- Which procedures account for the highest treatment volume within each procedure type?
WITH ranked_procedures AS(
    SELECT
        year, procedure_type, procedure_name, volume,
        DENSE_RANK() OVER (
            PARTITION BY year, procedure_type
            ORDER BY volume DESC)AS rnk
    FROM procedure_volume)

SELECT
    year, procedure_type, procedure_name, volume, rnk
FROM ranked_procedures
WHERE rnk <= 5
ORDER BY year, procedure_type, rnk;

-- Which procedures gained or lost the most volume from 2023 to 2024?
WITH procedure_growth AS(
    SELECT
        year, procedure_type, procedure_name, volume,
        LAG(volume) OVER(
            PARTITION BY procedure_name
            ORDER BY year) AS previous_volume
    FROM procedure_volume)

SELECT
    procedure_type, procedure_name, previous_volume, volume AS current_volume,
    volume - previous_volume AS volume_change,
    ROUND((volume - previous_volume) * 100.0/previous_volume, 2) AS growth_pct
FROM procedure_growth
WHERE year = 2024 AND previous_volume IS NOT NULL
ORDER BY volume_change DESC;

-- How do high-volume aesthetic procedures differ in their recurrence patterns and underlying consumption models?
SELECT
    pv.procedure_name,
    pv.procedure_type,
    pv.volume,
    pr.recurrence_model,
    pr.typical_frequency,
    pr.business_model
FROM procedure_volume AS pv
LEFT JOIN procedure_recurrence AS pr
ON pv.procedure_name = pr.procedure_name
WHERE pv.year = 2024
ORDER BY pv.volume DESC;

-- This QA step prevents partial pricing coverage from being interpreted as complete market-wide pricing information.
SELECT
    pv.procedure_type,
    COUNT(*) AS total_procedures,
    COUNT(pp.average_fee_usd) AS procedures_with_price,
    ROUND(COUNT(pp.average_fee_usd) * 100.0 / COUNT(*),2) AS pricing_coverage_pct
FROM procedure_volume AS pv
LEFT JOIN procedure_pricing AS pp
ON pv.procedure_name = pp.procedure_name
WHERE pv.year = 2024
GROUP BY pv.procedure_type;

-- How does available procedure pricing differ between cosmetic surgery and minimally invasive treatments?

SELECT
    pv.procedure_type,
    COUNT(DISTINCT pv.procedure_name) AS procedures_with_pricing,
    ROUND(AVG(pp.average_fee_usd), 2) AS avg_available_fee,
    ROUND(MIN(pp.average_fee_usd), 2) AS lowest_available_fee,
    ROUND(MAX(pp.average_fee_usd), 2) AS highest_available_fee
FROM procedure_volume AS pv
JOIN procedure_pricing AS pp
ON pv.procedure_name = pp.procedure_name
WHERE pv.year = 2024
GROUP BY pv.procedure_type
ORDER BY avg_available_fee DESC;

-- How much procedure volume is associated with recurring maintenance, treatment-cycle, and high-ticket models?

WITH procedure_economics AS(
    SELECT
        pv.procedure_name, pv.procedure_type, pv.volume, pr.business_model, pp.average_fee_usd,
        CASE
            WHEN pr.business_model IN(
                'Recurring revenue',
                'Repeat purchase',
                'Recurring service',
                'Maintenance spending')
                THEN 'Recurring / Maintenance'
            WHEN pr.business_model IN(
                'Package-based consumption',
                'Procedure package spending')
                THEN 'Treatment Cycle / Package'
            WHEN pr.business_model IN (
                'High-ticket one-time purchase',
                'High-ticket purchase with future revision potential')
                THEN 'High-Ticket / Low-Frequency'
        END AS consumption_model

    FROM procedure_volume AS pv
    JOIN procedure_recurrence AS pr
    ON pv.procedure_name = pr.procedure_name
    LEFT JOIN procedure_pricing AS pp
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

-- How has broader consumer adoption and usage frequency of Buy Now, Pay Later changed over time?
WITH bnpl_trends AS (
    SELECT
        metric, year, value_numeric,
        LAG(value_numeric) OVER (
            PARTITION BY metric
            ORDER BY year) AS previous_value
    FROM financing_market
    WHERE metric IN (
        'Consumers using BNPL',
        'Average BNPL loans per borrower'))

SELECT
    metric, year, previous_value, value_numeric AS current_value,
    ROUND((value_numeric - previous_value) * 100.0/previous_value, 2) AS growth_pct
FROM bnpl_trends
WHERE previous_value IS NOT NULL
ORDER BY metric;

-- During months of BNPL use, how does BNPL's share of unsecured debt differ for consumers ages 18-24 compared with all borrowers?
SELECT
    MAX(CASE
            WHEN metric = 'BNPL share of unsecured debt, age 18-24'
            THEN value_numeric
        END) AS age_18_24_share,
    MAX(CASE
            WHEN metric = 'BNPL share of unsecured debt, all borrowers'
            THEN value_numeric
        END) AS all_borrowers_share,

    ROUND(MAX(
            CASE WHEN metric = 'BNPL share of unsecured debt, age 18-24' THEN value_numeric END)
            -MAX(CASE WHEN metric = 'BNPL share of unsecured debt, all borrowers' THEN value_numeric END),2) AS percentage_point_gap
FROM financing_market
WHERE year = 2022;

-- What does the available evidence show about the economics and expansion of consumer financing in elective medicine?
SELECT 
	MAX(CASE
            WHEN metric = 'Elective medical merchants on Affirm network'
            THEN value_numeric
        END) AS elective_medical_merchants,
    MAX(CASE
            WHEN metric = 'Typical elective medical purchase size'
            THEN value_min
        END) AS typical_purchase_min_usd,
    MAX(CASE
            WHEN metric = 'Affirm elective medical APR range'
            THEN value_min
        END) AS affirm_apr_min_pct,
    MAX(CASE
            WHEN metric = 'Affirm elective medical APR range'
            THEN value_max
        END) AS affirm_apr_max_pct,
    MAX(CASE
            WHEN metric = 'Elective medical transactions at 0% APR'
            THEN value_numeric
        END) AS zero_apr_transaction_pct,
    MAX(CASE
            WHEN metric = 'Medical credit card average APR'
            THEN value_numeric
        END) AS medical_credit_card_apr_pct,
    MAX(CASE
            WHEN metric = 'Affirm 30-day delinquency rate'
            THEN value_numeric
        END) AS affirm_30day_delinquency_pct
FROM financing_market;