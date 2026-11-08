/* ============================================================================
   DATA WAREHOUSE ANALYTICS | 07 - CHANGE OVER TIME ANALYSIS
   ============================================================================
   Project       : SQL Data Warehouse Analytics
   Database      : DataWarehouseAnalytics
   Schema        : gold
   SQL dialect   : Microsoft SQL Server (T-SQL)
   Purpose       : Explore how sales revenue, customer activity, and units sold
                   change across days, years, and months.
   Source tables : gold.fact_sales
   Requirements : SQL Server 2022+ for DATETRUNC examples
   Query type    : Read-only exploratory analysis

   ANALYSIS SCOPE
   01 | Daily sales trend
   02 | Annual sales trend
   03 | Annual business activity
   04 | Month-of-year seasonality
   05 | Year-and-month performance
   06 | Monthly trend using a date bucket
   07 | Annual trend using a date bucket
   08 | Presentation-friendly month labels

   MEASURE DEFINITIONS
   total_sales     = SUM(sales_amount)
   total_customers = COUNT(DISTINCT customer_key) in each time period;
                     counts active purchasing customer keys, not new customers
   total_quantity  = SUM(quantity)

   NOTES
   - Excludes rows with NULL order_date from time-based analysis.
   - Months or days without sales are not generated automatically.
   - Calendar-month analysis (04) combines the same month across all years.
   - Monetary unit and business rules are defined by the source dataset.
   - This file does NOT calculate cumulative totals, moving averages,
     year-over-year differences, rankings, or customer segments.
   ============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | DAILY SALES TREND
   Business question: How much revenue is generated on each order date?
   Grain: One row per calendar day with recorded sales.
   ============================================================================ */

-- 01.01 | Aggregate daily revenue.
SELECT
    CAST(f.order_date AS date) AS order_day,
    SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales AS f
WHERE f.order_date IS NOT NULL
GROUP BY
    CAST(f.order_date AS date)
ORDER BY
    order_day;

/* ============================================================================
   02 | ANNUAL SALES TREND
   Business question: How does revenue vary from one calendar year to another?
   Grain: One row per calendar year with recorded sales.
   ============================================================================ */

-- 02.01 | Aggregate annual revenue.
SELECT
    YEAR(f.order_date) AS order_year,
    SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales AS f
WHERE f.order_date IS NOT NULL
GROUP BY
    YEAR(f.order_date)
ORDER BY
    order_year;

/* ============================================================================
   03 | ANNUAL BUSINESS ACTIVITY
   Business question: How do yearly sales, customer activity, and units vary?
   Grain: One row per calendar year with recorded sales.
   ============================================================================ */

-- 03.01 | Compare core business measures across years.
SELECT
    YEAR(f.order_date) AS order_year,
    SUM(f.sales_amount) AS total_sales,
    COUNT(DISTINCT f.customer_key) AS total_customers,
    SUM(f.quantity) AS total_quantity
FROM gold.fact_sales AS f
WHERE f.order_date IS NOT NULL
GROUP BY
    YEAR(f.order_date)
ORDER BY
    order_year;

/* ============================================================================
   04 | MONTH-OF-YEAR SEASONALITY
   Business question: Which calendar months tend to show higher activity?
   Grain: One row per month number (January through December), across ALL years.

   Important: This combines multiple years and does not represent a sequential
   monthly time series. Compare with section 05 for year-specific monthly data.
   ============================================================================ */

-- 04.01 | Aggregate all Januarys, all Februarys, and so on.
SELECT
    MONTH(f.order_date) AS order_month,
    SUM(f.sales_amount) AS total_sales,
    COUNT(DISTINCT f.customer_key) AS total_customers,
    SUM(f.quantity) AS total_quantity
FROM gold.fact_sales AS f
WHERE f.order_date IS NOT NULL
GROUP BY
    MONTH(f.order_date)
ORDER BY
    order_month;

/* ============================================================================
   05 | YEAR-AND-MONTH PERFORMANCE
   Business question: How do sales and customer activity change each month?
   Grain: One row per distinct year/month combination with recorded sales.
   ============================================================================ */

-- 05.01 | Retain both the year and month to avoid mixing different years.
SELECT
    YEAR(f.order_date) AS order_year,
    MONTH(f.order_date) AS order_month,
    SUM(f.sales_amount) AS total_sales,
    COUNT(DISTINCT f.customer_key) AS total_customers,
    SUM(f.quantity) AS total_quantity
FROM gold.fact_sales AS f
WHERE f.order_date IS NOT NULL
GROUP BY
    YEAR(f.order_date),
    MONTH(f.order_date)
ORDER BY
    order_year,
    order_month;

/* ============================================================================
   06 | MONTHLY TREND WITH A DATE BUCKET
   Business question: How can monthly metrics use one sortable date column?
   Grain: One row per month with recorded sales.
   SQL Server 2022+ syntax: DATETRUNC.
   ============================================================================ */

-- 06.01 | The first day of each month remains a date, not a text label.
SELECT
    CAST(DATETRUNC(MONTH, f.order_date) AS date) AS order_month,
    SUM(f.sales_amount) AS total_sales,
    COUNT(DISTINCT f.customer_key) AS total_customers,
    SUM(f.quantity) AS total_quantity
FROM gold.fact_sales AS f
WHERE f.order_date IS NOT NULL
GROUP BY
    DATETRUNC(MONTH, f.order_date)
ORDER BY
    order_month;

/* ============================================================================
   07 | ANNUAL TREND WITH A DATE BUCKET
   Business question: How can annual metrics use one sortable date column?
   Grain: One row per year with recorded sales.
   SQL Server 2022+ syntax: DATETRUNC.
   ============================================================================ */

-- 07.01 | The first day of each year represents the corresponding year.
SELECT
    CAST(DATETRUNC(YEAR, f.order_date) AS date) AS order_year,
    SUM(f.sales_amount) AS total_sales,
    COUNT(DISTINCT f.customer_key) AS total_customers,
    SUM(f.quantity) AS total_quantity
FROM gold.fact_sales AS f
WHERE f.order_date IS NOT NULL
GROUP BY
    DATETRUNC(YEAR, f.order_date)
ORDER BY
    order_year;

/* ============================================================================
   08 | PRESENTATION-FRIENDLY MONTH LABELS
   Business question: How can the results display month names chronologically?
   Grain: One row per month with recorded sales.

   Best practice: Group and sort by a true date value; format only for display.
   Do not sort by a label such as '2024-Jan' (a string).
   ============================================================================ */

-- 08.01 | Derive readable month labels from an aggregated monthly series.
WITH monthly_sales AS (
    SELECT
        CAST(DATETRUNC(MONTH, f.order_date) AS date) AS order_month,
        SUM(f.sales_amount) AS total_sales,
        COUNT(DISTINCT f.customer_key) AS total_customers,
        SUM(f.quantity) AS total_quantity
    FROM gold.fact_sales AS f
    WHERE f.order_date IS NOT NULL
    GROUP BY
        DATETRUNC(MONTH, f.order_date)
)
SELECT
    order_month,
    FORMAT(order_month, 'yyyy-MMM', 'en-US') AS month_label,
    total_sales,
    total_customers,
    total_quantity
FROM monthly_sales
ORDER BY
    order_month;


