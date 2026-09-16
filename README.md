---

## Technical Appendix

**Tools:** MySQL · DBeaver · Tableau

**Methods:**  
Market Sizing · Growth Analysis · Business Segmentation ·
Pricing Analysis · Data Coverage Validation

### Data

The analysis combines four datasets:

- Procedure volume
- Procedure pricing
- Procedure recurrence
- Consumer financing indicators

### Selected SQL

#### Ranking Category Leaders
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

#### Identifying Growth Drivers

WITH procedure_growth AS (
   SELECT
       year,
       procedure_type,
       procedure_name,
       volume,
       LAG(volume) OVER (
           PARTITION BY procedure_name
           ORDER BY year) AS previous_volume
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

#### Building the Consumption Model

WITH procedure_economics AS (
   SELECT
       pv.procedure_name,
       pv.procedure_type,
       pv.volume,
       pr.business_model,
       pp.average_fee_usd,
       CASE
           WHEN pr.business_model IN ( 'Recurring revenue', 'Repeat purchase', 'Recurring service', 'Maintenance spending') THEN 'Recurring / Maintenance'
           WHEN pr.business_model IN ( 'Package-based consumption',  'Procedure package spending') THEN 'Treatment Cycle / Package'
           WHEN pr.business_model IN ( 'High-ticket one-time purchase', 'High-ticket purchase with future revision potential') THEN 'High-Ticket / Low-Frequency'
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

### Data Quality

Pricing coverage was validated before comparing average procedure fees.
Coverage was 87.5% for cosmetic surgery and 36.4% for minimally invasive
procedures, so pricing results are interpreted only among procedures with
available pricing data.

### Sources

American Society of Plastic Surgeons (ASPS)  
Consumer Financial Protection Bureau (CFPB)  
Reuters / Affirm elective-medical financing reporting
