/* ============================================================================
   SQL DATA WAREHOUSE | PERFORMANCE ANALYSIS
   File       : 09_performance_analysis.sql
   Database   : DataWarehouseAnalytics
   Platform   : Microsoft SQL Server (T-SQL)
   Tables     : gold.fact_sales, gold.dim_products
   Purpose    : Evaluate product sales against historical product averages
                and the immediately preceding calendar year.
   Scope      : Product performance only; no rankings or segmentation.
   Execution  : Read-only; queries can be run independently.

   ANALYTICAL NOTES
   - Sales are attributed to the calendar year of fact_sales.order_date.
   - Product comparisons use product_key, not product_name, because names
     need not be unique or stable over time.
   - Yearly average means the average of *observed yearly totals* for each
     product, not the average transaction or the average of every possible
     calendar year. Years without sales are not zero-filled.
   - Prior-year comparisons are reported only for consecutive calendar years.
     LAG() alone gives the previous *observed* year, which may be older.
   - Product rows with no matching product dimension are retained by LEFT JOIN
     and appear with a descriptive fallback name.
   - Revenue and percentage values preserve numeric types for downstream BI.
   - Validate actual schema, keys, and results before publishing findings.
============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | ANNUAL PRODUCT SALES
   Business question:
   How much sales revenue did each product generate in each calendar year?

   Grain: One row per product_key and calendar year with dated sales.
============================================================================ */

-- 01.01 | Annual sales revenue and quantity for each product.
SELECT
    YEAR(f.order_date) AS order_year,
    f.product_key,
    COALESCE(p.product_name, 'Unknown / Unmatched Product') AS product_name,
    SUM(f.sales_amount) AS annual_revenue,
    SUM(f.quantity) AS annual_units_sold
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY
    YEAR(f.order_date),
    f.product_key,
    p.product_name
ORDER BY
    f.product_key,
    order_year;
GO

/* ============================================================================
   02 | PRODUCT PERFORMANCE VS. ITS HISTORICAL YEARLY AVERAGE
   Business question:
   Is a product's annual revenue above or below its average annual revenue
   across the years where that product has recorded sales?

   Technique: CTE + AVG() OVER (PARTITION BY ...).
   Grain: One row per product and observed sales year.
============================================================================ */

-- 02.01 | Compare each product-year against its own observed-year average.
WITH annual_product_sales AS (
    SELECT
        YEAR(f.order_date) AS order_year,
        f.product_key,
        COALESCE(p.product_name, 'Unknown / Unmatched Product') AS product_name,
        SUM(f.sales_amount) AS annual_revenue
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY
        YEAR(f.order_date),
        f.product_key,
        p.product_name
),
product_average AS (
    SELECT
        order_year,
        product_key,
        product_name,
        annual_revenue,
        AVG(CAST(annual_revenue AS DECIMAL(19, 4))) OVER (
            PARTITION BY product_key
        ) AS avg_annual_revenue
    FROM annual_product_sales
)
SELECT
    order_year,
    product_key,
    product_name,
    annual_revenue,
    ROUND(avg_annual_revenue, 2) AS avg_annual_revenue,
    ROUND(annual_revenue - avg_annual_revenue, 2) AS difference_from_average,
    ROUND(
        100.0 * (annual_revenue - avg_annual_revenue)
        / NULLIF(avg_annual_revenue, 0),
        2
    ) AS difference_from_average_pct,
    CASE
        WHEN annual_revenue > avg_annual_revenue THEN 'Above Average'
        WHEN annual_revenue < avg_annual_revenue THEN 'Below Average'
        ELSE 'At Average'
    END AS average_performance_status
FROM product_average
ORDER BY
    product_key,
    order_year;
GO

/* ============================================================================
   03 | PRODUCT YEAR-OVER-YEAR (YOY) PERFORMANCE
   Business question:
   How much did a product's revenue change compared with the immediately
   preceding calendar year?

   Technique: CTE + LAG() OVER (PARTITION BY ... ORDER BY ...).
   Grain: One row per product and observed sales year.

   IMPORTANT:
   LAG() returns the previous available product-year row, not necessarily
   the prior calendar year. The explicit year check prevents treating a
   gap (e.g., 2022 -> 2024) as a valid 2024-vs-2023 comparison.
============================================================================ */

-- 03.01 | Prior-year revenue, absolute difference, percent change and status.
WITH annual_product_sales AS (
    SELECT
        YEAR(f.order_date) AS order_year,
        f.product_key,
        COALESCE(p.product_name, 'Unknown / Unmatched Product') AS product_name,
        SUM(f.sales_amount) AS annual_revenue
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY
        YEAR(f.order_date),
        f.product_key,
        p.product_name
),
previous_observation AS (
    SELECT
        order_year,
        product_key,
        product_name,
        annual_revenue,
        LAG(order_year) OVER (
            PARTITION BY product_key
            ORDER BY order_year
        ) AS previous_observed_year,
        LAG(annual_revenue) OVER (
            PARTITION BY product_key
            ORDER BY order_year
        ) AS previous_observed_revenue
    FROM annual_product_sales
),
calendar_year_comparison AS (
    SELECT
        order_year,
        product_key,
        product_name,
        annual_revenue,
        CASE
            WHEN previous_observed_year = order_year - 1
                THEN previous_observed_revenue
            ELSE NULL
        END AS previous_year_revenue
    FROM previous_observation
)
SELECT
    order_year,
    product_key,
    product_name,
    annual_revenue,
    previous_year_revenue,
    annual_revenue - previous_year_revenue AS yoy_revenue_change,
    ROUND(
        100.0 * (annual_revenue - previous_year_revenue)
        / NULLIF(previous_year_revenue, 0),
        2
    ) AS yoy_revenue_change_pct,
    CASE
        WHEN previous_year_revenue IS NULL THEN 'No Prior-Year Comparison'
        WHEN annual_revenue > previous_year_revenue THEN 'Increase'
        WHEN annual_revenue < previous_year_revenue THEN 'Decrease'
        ELSE 'No Change'
    END AS yoy_performance_status
FROM calendar_year_comparison
ORDER BY
    product_key,
    order_year;
GO

/* ============================================================================
   04 | COMBINED PRODUCT PERFORMANCE VIEW
   Business question:
   For each product and sales year, how does revenue compare with both its
   historical average and the previous calendar year's revenue?

   This consolidated output is suitable for reporting or dashboard exports.
   It repeats the base aggregation intentionally so this query is standalone.
============================================================================ */

-- 04.01 | Average-based and YoY product performance in one result set.
WITH annual_product_sales AS (
    SELECT
        YEAR(f.order_date) AS order_year,
        f.product_key,
        COALESCE(p.product_name, 'Unknown / Unmatched Product') AS product_name,
        SUM(f.sales_amount) AS annual_revenue
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY
        YEAR(f.order_date),
        f.product_key,
        p.product_name
),
performance_windows AS (
    SELECT
        order_year,
        product_key,
        product_name,
        annual_revenue,
        AVG(CAST(annual_revenue AS DECIMAL(19, 4))) OVER (
            PARTITION BY product_key
        ) AS avg_annual_revenue,
        LAG(order_year) OVER (
            PARTITION BY product_key
            ORDER BY order_year
        ) AS previous_observed_year,
        LAG(annual_revenue) OVER (
            PARTITION BY product_key
            ORDER BY order_year
        ) AS previous_observed_revenue
    FROM annual_product_sales
),
performance_comparisons AS (
    SELECT
        order_year,
        product_key,
        product_name,
        annual_revenue,
        avg_annual_revenue,
        CASE
            WHEN previous_observed_year = order_year - 1
                THEN previous_observed_revenue
            ELSE NULL
        END AS previous_year_revenue
    FROM performance_windows
)
SELECT
    order_year,
    product_key,
    product_name,
    annual_revenue,
    ROUND(avg_annual_revenue, 2) AS avg_annual_revenue,
    ROUND(annual_revenue - avg_annual_revenue, 2) AS difference_from_average,
    CASE
        WHEN annual_revenue > avg_annual_revenue THEN 'Above Average'
        WHEN annual_revenue < avg_annual_revenue THEN 'Below Average'
        ELSE 'At Average'
    END AS average_performance_status,
    previous_year_revenue,
    annual_revenue - previous_year_revenue AS yoy_revenue_change,
    ROUND(
        100.0 * (annual_revenue - previous_year_revenue)
        / NULLIF(previous_year_revenue, 0),
        2
    ) AS yoy_revenue_change_pct,
    CASE
        WHEN previous_year_revenue IS NULL THEN 'No Prior-Year Comparison'
        WHEN annual_revenue > previous_year_revenue THEN 'Increase'
        WHEN annual_revenue < previous_year_revenue THEN 'Decrease'
        ELSE 'No Change'
    END AS yoy_performance_status
FROM performance_comparisons
ORDER BY
    product_key,
    order_year;
GO

/* ============================================================================
   REUSABILITY & VALIDATION CHECKLIST

   [ ] Confirm the database and gold-layer table/column names.
   [ ] Verify gold.dim_products contains one row per product_key before
       joining; duplicated keys can inflate revenue.
   [ ] Define whether negative sales/returns should be included in revenue.
   [ ] Check missing order_date values (excluded from year comparisons).
   [ ] Confirm business treatment of products with years of zero sales.
   [ ] If zero-sales years must be included, build a calendar-product grid
       and zero-fill missing years BEFORE applying LAG() and AVG() OVER().
   [ ] Decide whether a partial current year should be compared with a full
       prior year; for fair comparisons, use equivalent year-to-date periods.
   [ ] Review numeric precision and currency conventions.
   [ ] Validate key output rows against source transactions.

   Portfolio note:
   These queries demonstrate CTEs, grouped aggregates, dimension joins,
   AVG() OVER(), LAG(), and conditional business logic.
============================================================================ */
