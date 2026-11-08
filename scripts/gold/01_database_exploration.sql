/*
===============================================================================
PROJECT    : Data Warehouse Analytics
SCRIPT     : 02_exploratory_data_analysis.sql
DATABASE   : DataWarehouseAnalytics
PLATFORM   : Microsoft SQL Server (T-SQL)
AUTHOR     : Portfolio project
PURPOSE    : Reusable exploratory analysis of a dimensional sales warehouse.

DATA MODEL (expected):
  gold.dim_customers : customer_key, first_name, last_name, country,
                       gender, birthdate
  gold.dim_products  : product_key, product_name, category, subcategory, cost
  gold.fact_sales    : order_number, order_date, customer_key, product_key,
                       sales_amount, quantity, price

ASSUMPTIONS / INTERPRETATION:
  * fact_sales is at sales-line granularity: one order can have multiple rows.
  * Monetary totals use sales_amount; unit counts use quantity.
  * 'Average unit price' below is quantity-weighted (sales / units).
  * Product and customer counts come from their dimension tables.
  * Missing dates, ages, and dimension links are assessed separately.
  * ORDER BY ensures stable output ordering where appropriate.

USAGE:
  1. Ensure required gold tables exist (see optional setup file).
  2. Execute individual sections, or run the full read-only script.
  3. Replace source table/column names for a different warehouse.

NOTE: Information_schema queries only inspect the current database. An
optional, separate instance-wide inventory is included at the end.
===============================================================================
*/

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | DATA DISCOVERY & SCHEMA INSPECTION
   Goal: Confirm the available tables, columns, and relationships.
============================================================================ */

-- 01.01 | Inventory base tables and views in the current database.
SELECT
    TABLE_CATALOG AS database_name,
    TABLE_SCHEMA AS schema_name,
    TABLE_NAME AS object_name,
    TABLE_TYPE AS object_type
FROM INFORMATION_SCHEMA.TABLES
ORDER BY schema_name, object_name;

-- 01.02 | Inspect table columns, types, and nullability.
SELECT
    TABLE_SCHEMA AS schema_name,
    TABLE_NAME AS table_name,
    ORDINAL_POSITION AS column_position,
    COLUMN_NAME AS column_name,
    DATA_TYPE AS data_type,
    IS_NULLABLE AS is_nullable
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold'
ORDER BY table_name, column_position;

-- 01.03 | List databases visible to this login.
SELECT
    name AS database_name,
    state_desc AS database_state
FROM sys.databases
WHERE HAS_DBACCESS(name) = 1
ORDER BY name;

/* ============================================================================
   02 | DIMENSION EXPLORATION
   Goal: Understand categorical attributes used to segment KPIs.
============================================================================ */

-- 02.01 | Customer geography.
SELECT DISTINCT
    country
FROM gold.dim_customers
ORDER BY country;

-- 02.02 | Product hierarchy; combinations may repeat across products.
SELECT DISTINCT
    category,
    subcategory,
    product_name
FROM gold.dim_products
ORDER BY category, subcategory, product_name;

/* ============================================================================
   03 | DATE COVERAGE & CUSTOMER AGE
   Goal: Establish the timeframe covered by the sales and customer datasets.
============================================================================ */

-- 03.01 | Sales history boundaries and elapsed calendar boundaries.
-- DATEDIFF counts date-part boundaries, not complete elapsed years/months.
SELECT
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(YEAR, MIN(order_date), MAX(order_date)) AS year_boundaries,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS month_boundaries
FROM gold.fact_sales
WHERE order_date IS NOT NULL;

-- 03.02 | Oldest and youngest recorded birth dates.
SELECT
    MIN(birthdate) AS oldest_birthdate,
    MAX(birthdate) AS youngest_birthdate
FROM gold.dim_customers
WHERE birthdate IS NOT NULL;

-- 03.03 | Customer age in completed years, not DATEDIFF(YEAR) alone.
-- Age reflects the date on which this query is run; future dates are excluded.
WITH valid_birthdates AS (
    SELECT birthdate
    FROM gold.dim_customers
    WHERE birthdate IS NOT NULL
      AND CAST(birthdate AS DATE) <= CAST(GETDATE() AS DATE)
),
ages AS (
    SELECT
        birthdate,
        DATEDIFF(YEAR, birthdate, GETDATE())
        - CASE
            WHEN DATEADD(YEAR, DATEDIFF(YEAR, birthdate, GETDATE()), birthdate)
                 > GETDATE() THEN 1 ELSE 0
          END AS age_years
    FROM valid_birthdates
)
SELECT
    MIN(birthdate) AS oldest_birthdate,
    MAX(age_years) AS oldest_age_years,
    MAX(birthdate) AS youngest_birthdate,
    MIN(age_years) AS youngest_age_years
FROM ages;

/* ============================================================================
   04 | BUSINESS KPI OVERVIEW
   Goal: Calculate core metrics using consistent and explicit definitions.
============================================================================ */

-- 04.01 | Sales KPIs. Distinct orders avoid counting line items as orders.
SELECT
    SUM(sales_amount) AS total_revenue,
    SUM(quantity) AS units_sold,
    COUNT(DISTINCT order_number) AS distinct_orders,
    COUNT(*) AS sales_lines,
    CAST(SUM(sales_amount) AS DECIMAL(19, 4))
        / NULLIF(SUM(quantity), 0) AS weighted_average_unit_price,
    AVG(CAST(price AS DECIMAL(19, 4))) AS average_recorded_line_price
FROM gold.fact_sales;

-- 04.02 | Dimension size and customer purchasing activity.
SELECT
    (SELECT COUNT(*) FROM gold.dim_products) AS products_in_catalog,
    (SELECT COUNT(*) FROM gold.dim_customers) AS registered_customers,
    (SELECT COUNT(DISTINCT customer_key)
       FROM gold.fact_sales
      WHERE customer_key IS NOT NULL) AS purchasing_customer_keys;

-- 04.03 | Long-form KPI report, convenient for reporting or export.
-- Each measure is converted to a uniform decimal representation.
WITH business_metrics AS (
    SELECT 1 AS display_order, 'Total Revenue' AS metric_name,
           CAST(SUM(sales_amount) AS DECIMAL(19, 4)) AS metric_value
    FROM gold.fact_sales
    UNION ALL
    SELECT 2, 'Units Sold', CAST(SUM(quantity) AS DECIMAL(19, 4))
    FROM gold.fact_sales
    UNION ALL
    SELECT 3, 'Distinct Orders', CAST(COUNT(DISTINCT order_number) AS DECIMAL(19, 4))
    FROM gold.fact_sales
    UNION ALL
    SELECT 4, 'Average Unit Selling Price',
           CAST(SUM(sales_amount) AS DECIMAL(19, 4)) / NULLIF(SUM(quantity), 0)
    FROM gold.fact_sales
    UNION ALL
    SELECT 5, 'Products in Catalog', CAST(COUNT(*) AS DECIMAL(19, 4))
    FROM gold.dim_products
    UNION ALL
    SELECT 6, 'Registered Customers', CAST(COUNT(*) AS DECIMAL(19, 4))
    FROM gold.dim_customers
    UNION ALL
    SELECT 7, 'Purchasing Customers',
           CAST(COUNT(DISTINCT customer_key) AS DECIMAL(19, 4))
    FROM gold.fact_sales
)
SELECT
    metric_name,
    metric_value
FROM business_metrics
ORDER BY display_order;

/* ============================================================================
   05 | DATA QUALITY & REFERENTIAL INTEGRITY CHECKS
   Goal: Identify missing keys, null measures, and unmatched dimension keys.
============================================================================ */

-- 05.01 | Duplicate keys in customer dimension (should return no rows).
SELECT
    customer_key,
    COUNT(*) AS row_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1
ORDER BY row_count DESC, customer_key;

-- 05.02 | Duplicate keys in product dimension (should return no rows).
SELECT
    product_key,
    COUNT(*) AS row_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1
ORDER BY row_count DESC, product_key;

-- 05.03 | Missing essential fields in sales facts.
SELECT
    COUNT(*) AS sales_lines,
    SUM(CASE WHEN order_number IS NULL THEN 1 ELSE 0 END) AS null_order_numbers,
    SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS null_order_dates,
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS null_customer_keys,
    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS null_product_keys,
    SUM(CASE WHEN sales_amount IS NULL THEN 1 ELSE 0 END) AS null_sales_amounts,
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS null_quantities
FROM gold.fact_sales;

-- 05.04 | Fact records without matching dimension records.
SELECT
    SUM(CASE WHEN c.customer_key IS NULL THEN 1 ELSE 0 END) AS unmatched_customer_lines,
    SUM(CASE WHEN p.product_key IS NULL THEN 1 ELSE 0 END) AS unmatched_product_lines
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key;

/* ============================================================================
   06 | MAGNITUDE & SEGMENT ANALYSIS
   Goal: Compare customer mix, product mix, revenue, and volume by dimensions.
============================================================================ */

-- 06.01 | Registered customers by country.
SELECT
    COALESCE(country, 'Unknown') AS country,
    COUNT(*) AS total_customers
FROM gold.dim_customers
GROUP BY COALESCE(country, 'Unknown')
ORDER BY total_customers DESC, country;

-- 06.02 | Registered customers by gender.
SELECT
    COALESCE(gender, 'Unknown') AS gender,
    COUNT(*) AS total_customers
FROM gold.dim_customers
GROUP BY COALESCE(gender, 'Unknown')
ORDER BY total_customers DESC, gender;

-- 06.03 | Product count and average unit cost by category.
SELECT
    COALESCE(category, 'Uncategorized') AS category,
    COUNT(*) AS total_products,
    AVG(CAST(cost AS DECIMAL(19, 4))) AS average_unit_cost
FROM gold.dim_products
GROUP BY COALESCE(category, 'Uncategorized')
ORDER BY total_products DESC, category;

-- 06.04 | Sales revenue by product category.
SELECT
    COALESCE(p.category, 'Unmatched / Uncategorized') AS category,
    SUM(f.sales_amount) AS total_revenue,
    SUM(f.quantity) AS units_sold
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY COALESCE(p.category, 'Unmatched / Uncategorized')
ORDER BY total_revenue DESC, category;

-- 06.05 | Revenue by individual customer (includes matched purchasing customers).
SELECT
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue,
    COUNT(DISTINCT f.order_number) AS distinct_orders
FROM gold.fact_sales AS f
INNER JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC, c.customer_key;

-- 06.06 | Units sold across customer countries.
SELECT
    COALESCE(c.country, 'Unmatched / Unknown') AS country,
    SUM(f.quantity) AS units_sold,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY COALESCE(c.country, 'Unmatched / Unknown')
ORDER BY units_sold DESC, country;

/* ============================================================================
   07 | RANKING: TOP-N & BOTTOM-N
   Goal: Identify high- and low-performing products, categories, and customers.
============================================================================ */

-- 07.01 | Top five products by revenue (deterministic tie-break).
SELECT TOP (5)
    p.product_key,
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
INNER JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY p.product_key, p.product_name
ORDER BY total_revenue DESC, p.product_key;

-- 07.02 | Alternative with a window function and ranked product revenue.
WITH product_revenue AS (
    SELECT
        p.product_key,
        p.product_name,
        SUM(f.sales_amount) AS total_revenue
    FROM gold.fact_sales AS f
    INNER JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    GROUP BY p.product_key, p.product_name
),
ranked_products AS (
    SELECT
        product_key,
        product_name,
        total_revenue,
        ROW_NUMBER() OVER (
            ORDER BY total_revenue DESC, product_key
        ) AS revenue_rank
    FROM product_revenue
)
SELECT
    product_key,
    product_name,
    total_revenue,
    revenue_rank
FROM ranked_products
WHERE revenue_rank <= 5
ORDER BY revenue_rank;

-- 07.03 | Bottom five products by revenue, including unsold catalog products.
-- A left join is intentional; unsold products have zero recognized revenue.
SELECT TOP (5)
    p.product_key,
    p.product_name,
    COALESCE(SUM(f.sales_amount), 0) AS total_revenue
FROM gold.dim_products AS p
LEFT JOIN gold.fact_sales AS f
    ON f.product_key = p.product_key
GROUP BY p.product_key, p.product_name
ORDER BY total_revenue ASC, p.product_key;

-- 07.04 | Top five subcategories by revenue.
SELECT TOP (5)
    COALESCE(p.subcategory, 'Uncategorized') AS subcategory,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
INNER JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY COALESCE(p.subcategory, 'Uncategorized')
ORDER BY total_revenue DESC, subcategory;

-- 07.05 | Top ten customers by total revenue.
SELECT TOP (10)
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
INNER JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC, c.customer_key;

-- 07.06 | Three purchasing customers with the fewest distinct orders.
-- To include customers with zero orders, start from dim_customers instead.
SELECT TOP (3)
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT f.order_number) AS distinct_orders
FROM gold.dim_customers AS c
INNER JOIN gold.fact_sales AS f
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY distinct_orders ASC, c.customer_key;

-- 07.07 | Optional: bottom three registered customers, including zero orders.
SELECT TOP (3)
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT f.order_number) AS distinct_orders
FROM gold.dim_customers AS c
LEFT JOIN gold.fact_sales AS f
    ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY distinct_orders ASC, c.customer_key;

/* ============================================================================
   08 | OPTIONAL CROSS-DATABASE INVENTORY (INSTANCE-WIDE)
   Goal: List tables in all ONLINE databases accessible to the current login.
   Notes:
     - Dynamic SQL is necessary to query each database's INFORMATION_SCHEMA.
     - This may fail if access changes or system/database permissions differ.
     - Skip in restricted production environments.
============================================================================ */

DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql = @sql +
    N'SELECT ' + QUOTENAME(name, '''') + N' AS database_name, '
    + N'TABLE_SCHEMA AS schema_name, TABLE_NAME AS table_name '
    + N'FROM ' + QUOTENAME(name) + N'.INFORMATION_SCHEMA.TABLES '
    + N'WHERE TABLE_TYPE = ''BASE TABLE'' UNION ALL '
FROM sys.databases
WHERE state_desc = N'ONLINE'
  AND HAS_DBACCESS(name) = 1;

IF LEN(@sql) > 0
BEGIN
    SET @sql = LEFT(@sql, LEN(@sql) - LEN(N' UNION ALL '));
    SET @sql += N' ORDER BY database_name, schema_name, table_name;';
    EXEC sys.sp_executesql @sql;
END;
GO

/* ============================================================================
   END OF EXPLORATORY DATA ANALYSIS
============================================================================ */
