/* ============================================================================
   SQL DATA WAREHOUSE | CUMULATIVE ANALYSIS
   File       : 08_cumulative_analysis.sql
   Database   : DataWarehouseAnalytics
   Schema     : gold
   Platform   : Microsoft SQL Server 2022+ (T-SQL)
   Tables     : gold.fact_sales

   PURPOSE
   Track sales accumulation and rolling performance across reporting periods.
   This script can be reused in other dimensional data warehouse projects.

   BUSINESS QUESTIONS
   01. How does monthly revenue accumulate over time?
   02. How does monthly revenue accumulate within each calendar year?
   03. How does annual revenue accumulate over time?
   04. What is the three-period moving average of monthly revenue?
   05. How does the average selling price change across annual periods?

   ANALYTICAL GRAIN
   Monthly queries: one row per month with recorded orders.
   Annual queries : one row per year with recorded orders.

   NOTES
   - Read-only: this script does not modify data or database objects.
   - NULL order dates are excluded from period-based calculations.
   - Sales amounts and prices use the monetary units present in the source.
   - Missing calendar months are not filled in; ROWS counts observed periods.
   - A moving average of period averages treats each period equally. It is
     different from an overall line-weighted or quantity-weighted average.
   - DATETRUNC requires SQL Server 2022 or later.
============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | MONTHLY CUMULATIVE SALES

   Business question:
   How much revenue has the business generated up to each sales month?

   Method:
   Aggregate sales to the month, then compute a running SUM ordered by month.
============================================================================ */

WITH monthly_sales AS (
    SELECT
        CAST(DATETRUNC(MONTH, f.order_date) AS DATE) AS sales_month,
        SUM(f.sales_amount) AS monthly_revenue
    FROM gold.fact_sales AS f
    WHERE f.order_date IS NOT NULL
    GROUP BY
        DATETRUNC(MONTH, f.order_date)
)
SELECT
    sales_month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        ORDER BY sales_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM monthly_sales
ORDER BY
    sales_month;
GO

/* ============================================================================
   02 | YEAR-TO-DATE (YTD) CUMULATIVE SALES

   Business question:
   How much revenue has accumulated within each calendar year?

   Method:
   PARTITION BY resets the running total when the calendar year changes.
   Do not partition by sales_month: that would reset the total each month.
============================================================================ */

WITH monthly_sales AS (
    SELECT
        CAST(DATETRUNC(MONTH, f.order_date) AS DATE) AS sales_month,
        SUM(f.sales_amount) AS monthly_revenue
    FROM gold.fact_sales AS f
    WHERE f.order_date IS NOT NULL
    GROUP BY
        DATETRUNC(MONTH, f.order_date)
)
SELECT
    YEAR(sales_month) AS sales_year,
    sales_month,
    monthly_revenue,
    SUM(monthly_revenue) OVER (
        PARTITION BY YEAR(sales_month)
        ORDER BY sales_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS year_to_date_revenue
FROM monthly_sales
ORDER BY
    sales_month;
GO

/* ============================================================================
   03 | ANNUAL CUMULATIVE SALES

   Business question:
   What is the total revenue accumulated by the end of each sales year?

   Method:
   Aggregate by year, then apply a cumulative SUM across years.
============================================================================ */

WITH annual_sales AS (
    SELECT
        YEAR(f.order_date) AS sales_year,
        SUM(f.sales_amount) AS annual_revenue
    FROM gold.fact_sales AS f
    WHERE f.order_date IS NOT NULL
    GROUP BY
        YEAR(f.order_date)
)
SELECT
    sales_year,
    annual_revenue,
    SUM(annual_revenue) OVER (
        ORDER BY sales_year
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM annual_sales
ORDER BY
    sales_year;
GO

/* ============================================================================
   04 | THREE-MONTH-PERIOD MOVING AVERAGE OF REVENUE

   Business question:
   What is the average monthly revenue over the current and two preceding
   observed sales months?

   Method:
   ROWS BETWEEN 2 PRECEDING AND CURRENT ROW calculates a three-row window.
   If sales data contains missing months, the window spans the last three
   observed months, not necessarily three consecutive calendar months.
============================================================================ */

WITH monthly_sales AS (
    SELECT
        CAST(DATETRUNC(MONTH, f.order_date) AS DATE) AS sales_month,
        SUM(f.sales_amount) AS monthly_revenue
    FROM gold.fact_sales AS f
    WHERE f.order_date IS NOT NULL
    GROUP BY
        DATETRUNC(MONTH, f.order_date)
)
SELECT
    sales_month,
    monthly_revenue,
    AVG(CAST(monthly_revenue AS DECIMAL(19, 4))) OVER (
        ORDER BY sales_month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_revenue_3_observed_months
FROM monthly_sales
ORDER BY
    sales_month;
GO

/* ============================================================================
   05 | ANNUAL AVERAGE SELLING PRICE AND MOVING AVERAGE

   Business question:
   How does average recorded selling price evolve across years, and what is
   its three-observed-year moving average?

   Method:
   First compute each year's AVG(price), as in the original exploration;
   then average these annual values over the current and two prior years.

   IMPORTANT:
   This is an equally weighted average of annual average prices; years with
   different sales-line counts still receive equal weight in the moving window.
   For a volume-weighted price measure, use SUM(sales_amount)/SUM(quantity)
   where those fields have the appropriate business meaning.
============================================================================ */

WITH annual_prices AS (
    SELECT
        YEAR(f.order_date) AS sales_year,
        AVG(CAST(f.price AS DECIMAL(19, 4))) AS annual_avg_line_price
    FROM gold.fact_sales AS f
    WHERE f.order_date IS NOT NULL
      AND f.price IS NOT NULL
    GROUP BY
        YEAR(f.order_date)
)
SELECT
    sales_year,
    annual_avg_line_price,
    AVG(annual_avg_line_price) OVER (
        ORDER BY sales_year
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_price_3_observed_years
FROM annual_prices
ORDER BY
    sales_year;
GO

/* ============================================================================
   REUSABILITY & VALIDATION CHECKLIST

   [ ] Replace database, schema, table, and field names if adapting this file.
   [ ] Confirm each fact row's grain (e.g., an order line rather than an order).
   [ ] Decide how NULL order dates should be treated.
   [ ] Check for missing months/years before interpreting ROWS moving windows.
   [ ] Confirm whether the desired moving average is period-weighted,
       sales-line-weighted, or unit-weighted.

============================================================================ */
