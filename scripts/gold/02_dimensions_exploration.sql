/* ============================================================================
   DATA WAREHOUSE ANALYTICS | DIMENSION EXPLORATION
   ============================================================================
   File        : 02_dimension_exploration.sql
   Database    : DataWarehouseAnalytics
   SQL dialect : Microsoft SQL Server (T-SQL)
   Layer       : gold
   Purpose     : Identify distinct descriptive attributes and product hierarchy
                 members that can be used to filter or group later analyses.

   Expected source tables:
       gold.dim_customers (customer_key, country, gender, marital_status, ...)
       gold.dim_products  (product_key, category, subcategory, product_name, ...)

   Scope:
       IN  : Categorical dimension values and product hierarchy exploration.
       OUT : Date ranges, KPI measures, magnitude/count summaries, ranking,
             trends, cumulative metrics, performance, segmentation,
             part-to-whole analysis, and customer/product reports.

   How to use:
       1. Confirm that the gold dimension tables have been created.
       2. For another project, replace the database, schema, and column names.

   Notes:
       - SELECT DISTINCT returns one row per unique value or combination.
       - NULL appears as a separate distinct value when present.
       - No data is modified: all queries are read-only.
   ============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | CUSTOMER DIMENSIONS
   Business question: Which descriptive customer attributes are available?
   ============================================================================ */

-- 01.01 | Distinct customer countries.
-- Useful for subsequent geographic filtering and sales-by-country analysis.
SELECT DISTINCT
    country
FROM gold.dim_customers
ORDER BY
    country;

-- 01.02 | Distinct customer genders.
-- Check how gender is represented before using it in reporting.
SELECT DISTINCT
    gender
FROM gold.dim_customers
ORDER BY
    gender;

-- 01.03 | Distinct customer marital-status values.
-- Check the allowed values and detect unexpected labels.
SELECT DISTINCT
    marital_status
FROM gold.dim_customers
ORDER BY
    marital_status;

/* ============================================================================
   02 | PRODUCT DIMENSIONS
   Business question: How is the product catalog organized?
   ============================================================================ */

-- 02.01 | Distinct top-level product categories.
SELECT DISTINCT
    category
FROM gold.dim_products
ORDER BY
    category;

-- 02.02 | Distinct category / subcategory combinations.
-- Preserves the hierarchy instead of listing subcategories without context.
SELECT DISTINCT
    category,
    subcategory
FROM gold.dim_products
ORDER BY
    category,
    subcategory;

-- 02.03 | Distinct product hierarchy (category -> subcategory -> product).
-- This is the complete drill-down structure for later reporting.
SELECT DISTINCT
    category,
    subcategory,
    product_name
FROM gold.dim_products
ORDER BY
    category,
    subcategory,
    product_name;
