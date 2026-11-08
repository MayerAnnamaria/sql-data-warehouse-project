/* ============================================================================
   DATA WAREHOUSE ANALYTICS | DATE RANGE EXPLORATION
   ============================================================================
   File        : 03_date_range_exploration.sql
   Database    : DataWarehouseAnalytics
   SQL dialect : Microsoft SQL Server (T-SQL)
   Layer       : gold
   Purpose     : Identify the earliest/latest dates in the sales and customer
                 dimensions, estimate available historical coverage, and
                 understand customer age boundaries.

   Expected source tables:
       gold.fact_sales    (order_date, ...)
       gold.dim_customers (birthdate, ...)

   Scope:
       IN  : Date boundaries, calendar coverage, and customer age extremes.
       OUT : Dimension categories, business KPI summaries, sales trends,
             cumulative measures, performance comparison, segmentation,
             magnitude/ranking, part-to-whole analysis, and reports.

   How to use:
       1. Confirm the gold tables and the date columns exist.
       2. Run each numbered SELECT independently in VS Code or SSMS.
       3. Adapt database, schema, table, and column names for future projects.

   Notes:
       - NULL dates are ignored by MIN() and MAX().
       - DATEDIFF(year/month, ...) counts calendar boundaries crossed;
         it does NOT return completed years/months of elapsed time.
       - Customer age is calculated as of the execution date (GETDATE()).
       - All queries are read-only and do not modify source data.
   ============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | SALES ORDER DATE BOUNDARIES
   Business question: When did the first and most recent orders occur?
   ============================================================================ */

-- 01.01 | Earliest and latest known sales order dates.
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date
FROM gold.fact_sales;

/* ============================================================================
   02 | SALES DATA HISTORICAL COVERAGE
   Business question: What calendar period is represented by the sales data?
   ============================================================================ */

-- 02.01 | Calendar years and months between the first and last orders.
-- Boundary counts are useful for orientation, not exact elapsed durations.
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(
        YEAR,
        MIN(order_date),
        MAX(order_date)
    ) AS calendar_year_boundaries,
    DATEDIFF(
        MONTH,
        MIN(order_date),
        MAX(order_date)
    ) AS calendar_month_boundaries
FROM gold.fact_sales;

-- 02.02 | Inclusive number of calendar months touched by dated orders.
-- Example: an order in January and another in March span 3 calendar months.
-- This does not prove that February contains any sales activity.
SELECT
    CASE
        WHEN MIN(order_date) IS NULL THEN 0
        ELSE DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) + 1
    END AS calendar_months_in_range
FROM gold.fact_sales;

/* ============================================================================
   03 | CUSTOMER BIRTHDATE BOUNDARIES
   Business question: Which birthdates are the earliest and latest?
   ============================================================================ */

-- 03.01 | Oldest and youngest birthdates in the customer dimension.
-- Earliest birthdate generally corresponds to the oldest customer.
SELECT
    MIN(birthdate) AS oldest_customer_birthdate,
    MAX(birthdate) AS youngest_customer_birthdate
FROM gold.dim_customers;

/* ============================================================================
   04 | CUSTOMER AGE BOUNDARIES
   Business question: How old are the oldest and youngest customers today?
   ============================================================================ */

-- 04.01 | Age in completed years, accounting for birthdays not yet reached.
-- NULL and future birthdates are excluded from age calculations.
-- A simple DATEDIFF(YEAR, birthdate, GETDATE()) can overstate age by one.
WITH valid_customer_birthdates AS (
    SELECT
        CAST(birthdate AS date) AS birth_date
    FROM gold.dim_customers
    WHERE birthdate IS NOT NULL
      AND CAST(birthdate AS date) <= CAST(GETDATE() AS date)
),
customer_ages AS (
    SELECT
        birth_date,
        DATEDIFF(YEAR, birth_date, CAST(GETDATE() AS date))
        - CASE
            WHEN DATEADD(
                YEAR,
                DATEDIFF(YEAR, birth_date, CAST(GETDATE() AS date)),
                birth_date
            ) > CAST(GETDATE() AS date) THEN 1
            ELSE 0
          END AS age_years
    FROM valid_customer_birthdates
)
SELECT
    MIN(birth_date) AS oldest_customer_birthdate,
    MAX(age_years) AS oldest_customer_age_years,
    MAX(birth_date) AS youngest_customer_birthdate,
    MIN(age_years) AS youngest_customer_age_years
FROM customer_ages;

/* ============================================================================
   05 | DATE COVERAGE CHECKS
   Business question: Are missing/invalid dates limiting our observations?
   ============================================================================ */

-- 05.01 | Number of sales rows with and without an order date.
-- This is a date-coverage check, not a business sales measure.
SELECT
    COUNT_BIG(*) AS sales_rows_checked,
    COUNT_BIG(order_date) AS rows_with_order_date,
    COUNT_BIG(*) - COUNT_BIG(order_date) AS rows_missing_order_date
FROM gold.fact_sales;

-- 05.02 | Missing and future-dated customer birthdates.
-- Future dates indicate records that need investigation before age analysis.
SELECT
    COUNT_BIG(*) AS customer_rows_checked,
    COUNT_BIG(*) - COUNT_BIG(birthdate) AS rows_missing_birthdate,
    COUNT_BIG(
        CASE WHEN CAST(birthdate AS date) > CAST(GETDATE() AS date)
             THEN 1 END
    ) AS rows_with_future_birthdate
FROM gold.dim_customers;


