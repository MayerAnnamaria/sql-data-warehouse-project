/* ============================================================================
   DATA WAREHOUSE ANALYTICS | 05 - MAGNITUDE ANALYSIS
   ============================================================================
   Database       : DataWarehouseAnalytics
   SQL dialect    : Microsoft SQL Server (T-SQL)
   Data layer     : Gold (dimensional model)
   Tables         : gold.dim_customers, gold.dim_products, gold.fact_sales
   Purpose        : Compare the magnitude of business measures across dimensions.
   Output         : Read-only query results; no tables or data are modified.

   BUSINESS QUESTIONS
   01. How many customers are in each country?
   02. How many customers belong to each gender group?
   03. How many products are in each product category?
   04. What is the average product cost by category?
   05. How much sales revenue does each product category generate?
   06. How much sales revenue does each customer generate?
   07. How many items are sold to customers in each country?

   ANALYTICAL APPROACH
   - Dimension-only distributions use a dimension table as their source.
   - Sales metrics use the fact table joined to the relevant dimension.
   - LEFT JOIN preserves fact rows whose dimension record is missing.
   - COALESCE groups missing or unmatched dimension values into a clear label.
   - Dimension keys are retained when reporting at customer level so people
     sharing a name do not get combined.
   - ORDER BY is for reading the results; formal Top N / Bottom N comparisons
     belong in 06_ranking_analysis.sql.

   ASSUMPTIONS
   - fact_sales.sales_amount is line-level revenue; fact_sales.quantity is
     the number of units sold on that line.
   - dim_products.cost is the stored product cost per product record; its
     average is NOT a quantity-weighted or sales-weighted cost.
   - Each product_key and customer_key uniquely identifies a dimension row.
   - Monetary units depend on the dataset; they are not assumed to be USD.
   - NULL sales_amount/quantity values are ignored by SUM().
   - No actual query outputs or business findings are asserted here.

   REUSE
   Update database/table/column names and check fact-table grain, unique
   dimension keys, currency, and NULL conventions before using elsewhere.
   ============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | CUSTOMER DISTRIBUTION BY COUNTRY
   Business question: How many registered customers belong to each country?
   Grain: One output row per country.
   ============================================================================ */

-- 01.01 | Customer count by country (includes customers with no purchases).
SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(c.country)), ''), 'Unknown') AS country,
    COUNT(*) AS total_customers
FROM gold.dim_customers AS c
GROUP BY
    COALESCE(NULLIF(LTRIM(RTRIM(c.country)), ''), 'Unknown')
ORDER BY
    total_customers DESC,
    country;

/* ============================================================================
   02 | CUSTOMER DISTRIBUTION BY GENDER
   Business question: How many registered customers belong to each gender?
   Grain: One output row per gender value.
   ============================================================================ */

-- 02.01 | Customer count by gender; source labels are otherwise preserved.
SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(c.gender)), ''), 'Unknown') AS gender,
    COUNT(*) AS total_customers
FROM gold.dim_customers AS c
GROUP BY
    COALESCE(NULLIF(LTRIM(RTRIM(c.gender)), ''), 'Unknown')
ORDER BY
    total_customers DESC,
    gender;

/* ============================================================================
   03 | PRODUCT DISTRIBUTION BY CATEGORY
   Business question: How many catalog products belong to each category?
   Grain: One output row per product category.
   ============================================================================ */

-- 03.01 | Product count by category, including unsold catalog products.
SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(p.category)), ''), 'Uncategorized') AS category,
    COUNT(*) AS total_products
FROM gold.dim_products AS p
GROUP BY
    COALESCE(NULLIF(LTRIM(RTRIM(p.category)), ''), 'Uncategorized')
ORDER BY
    total_products DESC,
    category;

/* ============================================================================
   04 | AVERAGE PRODUCT COST BY CATEGORY
   Business question: What is the average stored product cost in each category?
   Grain: One output row per product category.
   Note: AVG ignores NULL costs. This is an unweighted catalog average.
   ============================================================================ */

-- 04.01 | Average listed cost across product rows in each category.
SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(p.category)), ''), 'Uncategorized') AS category,
    CAST(AVG(CAST(p.cost AS DECIMAL(19, 4))) AS DECIMAL(19, 2)) AS average_product_cost,
    COUNT(p.cost) AS products_with_cost
FROM gold.dim_products AS p
GROUP BY
    COALESCE(NULLIF(LTRIM(RTRIM(p.category)), ''), 'Uncategorized')
ORDER BY
    average_product_cost DESC,
    category;

/* ============================================================================
   05 | SALES REVENUE BY PRODUCT CATEGORY
   Business question: How much sales revenue is attributed to each category?
   Grain: One output row per category.
   Note: An unmatched product key remains visible in the Uncategorized group.
   ============================================================================ */

-- 05.01 | Revenue generated by category (sales-based, not catalog-based).
SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(p.category)), ''), 'Unmatched / Uncategorized') AS category,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    COALESCE(NULLIF(LTRIM(RTRIM(p.category)), ''), 'Unmatched / Uncategorized')
ORDER BY
    total_revenue DESC,
    category;

/* ============================================================================
   06 | SALES REVENUE BY CUSTOMER
   Business question: How much revenue is attributed to each purchasing customer?
   Grain: One output row per customer_key (including unmatched NULL group).
   Note: This is the complete distribution, NOT a Top 10 ranking.
   ============================================================================ */

-- 06.01 | Revenue generated by each customer who appears in the sales fact.
SELECT
    f.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY
    f.customer_key,
    c.first_name,
    c.last_name
ORDER BY
    total_revenue DESC,
    f.customer_key;

/* ============================================================================
   07 | SALES VOLUME BY CUSTOMER COUNTRY
   Business question: How many units were sold to customers in each country?
   Grain: One output row per country.
   Note: Country is taken from the customer dimension, not a shipping address.
   ============================================================================ */

-- 07.01 | Units sold by customer country.
SELECT
    COALESCE(NULLIF(LTRIM(RTRIM(c.country)), ''), 'Unmatched / Unknown') AS country,
    SUM(f.quantity) AS total_units_sold
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY
    COALESCE(NULLIF(LTRIM(RTRIM(c.country)), ''), 'Unmatched / Unknown')
ORDER BY
    total_units_sold DESC,
    country;

