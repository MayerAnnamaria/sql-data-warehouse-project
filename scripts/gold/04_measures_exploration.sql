/* ============================================================================
   DATA WAREHOUSE ANALYTICS | MEASURES EXPLORATION
   ============================================================================
   File        : 04_measures_exploration.sql
   Database    : DataWarehouseAnalytics
   SQL dialect : Microsoft SQL Server (T-SQL)
   Layer       : gold
   Purpose     : Explore core business measures and produce a reusable,
                 one-row-per-metric KPI summary from the sales fact table
                 and its related dimensions.

   Expected source tables and columns:
       gold.fact_sales    (order_number, customer_key, product_key,
                           sales_amount, quantity, price)
       gold.dim_customers (customer_key)
       gold.dim_products  (product_key)

   Scope:
       IN  : Total revenue, units sold, average price, order count,
             product counts, customer counts, and a consolidated KPI report.
       OUT : Date ranges, dimension categories, magnitude by segment,
             rankings, trends, cumulative/performance analysis, segmentation,
             part-to-whole analysis, customer/product detail reports.

   How to use:
       1. Confirm the gold tables and listed columns exist.
       2. Update the database/schema/column names to reuse in other projects.

   Interpretation notes:
       - fact_sales is assumed to contain sales line items: one order can
         appear on multiple rows. Distinct orders must use order_number.
       - SUM() and AVG() ignore NULL values. COUNT(*) counts all rows;
         COUNT(column) ignores NULLs; COUNT(DISTINCT ...) ignores NULLs.
       - price is assumed to be a line-item unit price. AVG(price) is the
         unweighted average across non-NULL sales lines.
       - sales_amount / quantity is a weighted, realized revenue per unit;
         it may differ from AVG(price), e.g. where discounts are present.
       - No currency is assumed; amounts use the source data's currency.
       - Queries are read-only and do not change the data warehouse.
   ============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | SALES MEASURES
   Business question: How much revenue and sales volume did we generate?
   ============================================================================ */

-- 01.01 | Total sales revenue across all recorded sales lines.
SELECT
    SUM(sales_amount) AS total_sales_revenue
FROM gold.fact_sales;

-- 01.02 | Total number of units sold.
SELECT
    SUM(quantity) AS total_units_sold
FROM gold.fact_sales;

-- 01.03 | Average recorded unit price per non-NULL sales line.
-- This is NOT quantity-weighted and is not necessarily the average amount
-- received per unit sold.
SELECT
    AVG(CAST(price AS DECIMAL(19, 4))) AS average_line_unit_price
FROM gold.fact_sales;

-- 01.04 | Realized revenue per unit sold (quantity-weighted measure).
-- NULLIF prevents division by zero when no units have been sold.
SELECT
    CAST(SUM(sales_amount) AS DECIMAL(28, 4))
        / NULLIF(SUM(CAST(quantity AS DECIMAL(28, 4))), 0)
        AS revenue_per_unit_sold
FROM gold.fact_sales;

/* ============================================================================
   02 | ORDER MEASURES
   Business question: How many unique orders were placed?
   ============================================================================ */

-- 02.01 | Total sales line items, including rows with a NULL order number.
SELECT
    COUNT(*) AS total_sales_lines
FROM gold.fact_sales;

-- 02.02 | Number of distinct orders (not the number of line items).
SELECT
    COUNT(DISTINCT order_number) AS total_orders
FROM gold.fact_sales;

/* ============================================================================
   03 | PRODUCT MEASURES
   Business question: How many products exist and how many have been sold?
   ============================================================================ */

-- 03.01 | Number of distinct products in the product catalog.
-- Source: dim_products; the original exploratory script referred to
-- gold.fact_products, which is not part of this warehouse's listed schema.
SELECT
    COUNT(DISTINCT product_key) AS total_catalog_products
FROM gold.dim_products;

-- 03.02 | Number of distinct products appearing in sales records.
SELECT
    COUNT(DISTINCT product_key) AS total_sold_products
FROM gold.fact_sales;

/* ============================================================================
   04 | CUSTOMER MEASURES
   Business question: How many customers exist and how many have bought?
   ============================================================================ */

-- 04.01 | Number of distinct registered customers in the customer dimension.
SELECT
    COUNT(DISTINCT customer_key) AS total_registered_customers
FROM gold.dim_customers;

-- 04.02 | Number of distinct customer keys appearing in sales records.
-- This counts fact-table keys; referential integrity checks belong in EDA.
SELECT
    COUNT(DISTINCT customer_key) AS total_purchasing_customer_keys
FROM gold.fact_sales;

-- Note: Equal counts in 04.01 and 04.02 do NOT prove that the same customers
-- appear in both tables. Use the referential integrity queries in the
-- exploratory data analysis file to verify key matching.

/* ============================================================================
   05 | CONSOLIDATED BUSINESS KPI SUMMARY
   Business question: What are the main business measures at a glance?

   Output: measure_name (text), measure_value (numeric).
   This tall format is suitable for export to reporting tools or reuse in
   other projects. Monetary/price metrics and counts share a numeric column;
   interpret each row according to its measure_name.
   ============================================================================ */

WITH sales_kpis AS (
    SELECT
        SUM(sales_amount) AS total_sales_revenue,
        SUM(quantity) AS total_units_sold,
        AVG(CAST(price AS DECIMAL(19, 4))) AS average_line_unit_price,
        COUNT(*) AS total_sales_lines,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT product_key) AS total_sold_products,
        COUNT(DISTINCT customer_key) AS total_purchasing_customer_keys
    FROM gold.fact_sales
),
dimension_kpis AS (
    SELECT
        (SELECT COUNT(DISTINCT product_key)
         FROM gold.dim_products) AS total_catalog_products,
        (SELECT COUNT(DISTINCT customer_key)
         FROM gold.dim_customers) AS total_registered_customers
)
SELECT
    k.measure_name,
    k.measure_value
FROM sales_kpis AS s
CROSS JOIN dimension_kpis AS d
CROSS APPLY (VALUES
    (1, 'Total Sales Revenue',         CAST(s.total_sales_revenue AS DECIMAL(28, 4))),
    (2, 'Total Units Sold',            CAST(s.total_units_sold AS DECIMAL(28, 4))),
    (3, 'Average Line Unit Price',     CAST(s.average_line_unit_price AS DECIMAL(28, 4))),
    (4, 'Total Sales Lines',           CAST(s.total_sales_lines AS DECIMAL(28, 4))),
    (5, 'Total Distinct Orders',       CAST(s.total_orders AS DECIMAL(28, 4))),
    (6, 'Total Catalog Products',      CAST(d.total_catalog_products AS DECIMAL(28, 4))),
    (7, 'Total Sold Products',         CAST(s.total_sold_products AS DECIMAL(28, 4))),
    (8, 'Total Registered Customers',  CAST(d.total_registered_customers AS DECIMAL(28, 4))),
    (9, 'Purchasing Customer Keys',    CAST(s.total_purchasing_customer_keys AS DECIMAL(28, 4)))
) AS k (display_order, measure_name, measure_value)
ORDER BY
    k.display_order;


