---

## Technical Appendix

**Tools:** MySQL · DBeaver · Tableau  
**Methods:** Market Sizing · Growth Analysis · Business Segmentation · Pricing Analysis · Data Coverage Validation

### Data

The analysis combines four datasets:

- **Procedure volume** — annual procedure volume by treatment and procedure type
- **Procedure pricing** — available average physician/surgeon fees
- **Procedure recurrence** — treatment frequency and business model classifications
- **Consumer financing** — BNPL adoption, usage, and elective-medical financing indicators

### Selected SQL

The full analysis is available in the [`/sql`](./sql) folder. Below are three examples of the SQL used to move from raw procedure-level data to the findings presented above.

#### 1. Ranking Category Leaders

I used `DENSE_RANK()` to identify the highest-volume procedures within each procedure type and year.

```sql
WITH ranked_procedures AS (
    SELECT
        year,
        procedure_type,
        procedure_name,
        volume,
        DENSE_RANK() OVER (
            PARTITION BY year, procedure_type
            ORDER BY volume DESC
        ) AS ranking
    FROM procedure_volume
)

SELECT
    year,
    procedure_type,
    procedure_name,
    volume,
    ranking
FROM ranked_procedures
WHERE ranking <= 5
ORDER BY year, procedure_type, ranking;
```

#### 2. Identifying Growth Drivers

To compare procedure growth between 2023 and 2024, I used `LAG()` to retrieve the prior-year volume for each procedure and calculate both absolute and percentage change.

```sql
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
    FROM procedure_volume
)

SELECT
    procedure_type,
    procedure_name,
    previous_volume,
    volume AS current_volume,
    volume - previous_volume AS volume_change,
    ROUND(
        (volume - previous_volume) * 100.0 / previous_volume,
        2
    ) AS growth_pct
FROM procedure_growth
WHERE year = 2024
    AND previous_volume IS NOT NULL
ORDER BY volume_change DESC;
```

#### 3. Building the Consumption Model

Procedure volume alone does not capture how treatments generate demand over time. I joined procedure volume, recurrence, and pricing data, then grouped treatments into three consumption models based on their underlying business characteristics.

```sql
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
                'Maintenance spending'
            )
                THEN 'Recurring / Maintenance'

            WHEN pr.business_model IN (
                'Package-based consumption',
                'Procedure package spending'
            )
                THEN 'Treatment Cycle / Package'

            WHEN pr.business_model IN (
                'High-ticket one-time purchase',
                'High-ticket purchase with future revision potential'
            )
                THEN 'High-Ticket / Low-Frequency'
        END AS consumption_model
    FROM procedure_volume AS pv
    JOIN procedure_recurrence AS pr
        ON pv.procedure_name = pr.procedure_name
    LEFT JOIN procedure_pricing AS pp
        ON pv.procedure_name = pp.procedure_name
    WHERE pv.year = 2024
)

SELECT
    consumption_model,
    COUNT(*) AS procedure_count,
    SUM(volume) AS total_2024_volume,
    ROUND(AVG(average_fee_usd), 2) AS avg_available_fee
FROM procedure_economics
WHERE consumption_model IS NOT NULL
GROUP BY consumption_model
ORDER BY total_2024_volume DESC;
```

### Data Quality

Before comparing procedure fees, I checked pricing coverage by procedure type.

Pricing data covered **87.5% of cosmetic surgery procedures** but only **36.4% of minimally invasive procedures**. Because of this gap, fee comparisons in the analysis are limited to procedures with available pricing rather than treated as complete market-wide estimates.

I also kept the consumer-financing analysis separate from procedure-demand analysis. The BNPL data describes the broader consumer-credit market and does not establish that BNPL borrowing caused growth in aesthetic procedures.

### Sources

- **American Society of Plastic Surgeons (ASPS)** — procedure volume and available physician/surgeon fee data
- **Consumer Financial Protection Bureau (CFPB)** — BNPL adoption, usage, and borrower-level consumer-credit indicators
- **Reuters / Affirm reporting** — elective-medical merchant expansion, purchase size, and financing terms

### Repository

- [`/sql`](./sql) — full SQL analysis
- [`/dashboards`](./dashboards) — Tableau dashboard exports
- [`/docs`](./docs) — supporting project documentation
