/* ============================================================================
   SQL DATA WAREHOUSE | RANKING ANALYSIS
   File:     06_ranking_analysis.sql
   Database: DataWarehouseAnalytics
   Platform: Microsoft SQL Server (T-SQL)
   Layer:    Gold (dimensional model)

   PURPOSE
   Identify high- and low-performing products, product subcategories, and
   customers through revenue- and order-based rankings.

   SOURCE TABLES
   gold.fact_sales   : order_number, product_key, customer_key, sales_amount
   gold.dim_products : product_key, product_name, subcategory
   gold.dim_customers: customer_key, first_name, last_name

   SCOPE & ASSUMPTIONS
   - All queries are read-only; the underlying data is not modified.
   - sales_amount is treated as recorded revenue (no returns adjustments).
   - Each sales fact row may represent an order line. Order counts therefore
     use COUNT(DISTINCT order_number).
   - Product-level rankings use product_key, not just product_name, because
     product names may not be unique.
   - Revenue rankings based on fact_sales include products with recorded
     sales only. Unsold products are not included in the bottom-five query.
   - Customers with no orders are not included in the fewest-orders query.
   - TOP (N) uses a deterministic secondary sort for ties. The ROW_NUMBER()
     example returns exactly five rows; RANK() would include tied positions.

   REUSE
   Update the USE statement, table/column names, metric definitions, and
   ranking limits when adapting this file to another warehouse.
============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | TOP 5 PRODUCTS BY REVENUE

   Business question:
   Which five products generated the highest recorded sales revenue?

   Grain: One row per product_key.
   Technique: JOIN, SUM, GROUP BY, TOP, ORDER BY.
============================================================================ */

SELECT TOP (5)
    p.product_key,
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    p.product_key,
    p.product_name
ORDER BY
    total_revenue DESC,
    p.product_key ASC;


/* ============================================================================
   02 | TOP 5 PRODUCTS BY REVENUE — WINDOW FUNCTION

   Business question:
   How can the same top-five product ranking be produced using ROW_NUMBER()?

   Grain: One row per product_key.
   Technique: CTE, SUM, ROW_NUMBER(), PARTITION-free ranking.
============================================================================ */

WITH product_revenue AS (
    SELECT
        p.product_key,
        p.product_name,
        SUM(f.sales_amount) AS total_revenue
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    GROUP BY
        p.product_key,
        p.product_name
),
ranked_products AS (
    SELECT
        product_key,
        product_name,
        total_revenue,
        ROW_NUMBER() OVER (
            ORDER BY total_revenue DESC, product_key ASC
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


/* ============================================================================
   03 | BOTTOM 5 PRODUCTS BY REVENUE

   Business question:
   Which five products with recorded sales generated the least revenue?

   Grain: One row per product_key.
   Note: Products with no sales do not appear in fact_sales and are excluded.
============================================================================ */

SELECT TOP (5)
    p.product_key,
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    p.product_key,
    p.product_name
ORDER BY
    total_revenue ASC,
    p.product_key ASC;


/* ============================================================================
   04 | TOP 5 PRODUCT SUBCATEGORIES BY REVENUE

   Business question:
   Which five product subcategories generated the most revenue?

   Grain: One row per subcategory.
   Note: The original analysis selected subcategory, not category.
============================================================================ */

SELECT TOP (5)
    COALESCE(p.subcategory, 'Unmatched / Uncategorized') AS subcategory,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_products AS p
    ON f.product_key = p.product_key
GROUP BY
    COALESCE(p.subcategory, 'Unmatched / Uncategorized')
ORDER BY
    total_revenue DESC,
    subcategory ASC;


/* ============================================================================
   05 | TOP 10 CUSTOMERS BY REVENUE

   Business question:
   Which ten customers generated the highest recorded revenue?

   Grain: One row per customer_key.
   Note: Distinct customers are identified by key, not by name alone.
============================================================================ */

SELECT TOP (10)
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY
    total_revenue DESC,
    c.customer_key ASC;


/* ============================================================================
   06 | BOTTOM 3 PURCHASING CUSTOMERS BY DISTINCT ORDER COUNT

   Business question:
   Which three customers who have placed orders have the fewest orders?

   Grain: One row per customer_key.
   Technique: COUNT(DISTINCT ...), JOIN, GROUP BY, TOP.
   Note: Registered customers with zero orders are intentionally excluded.
============================================================================ */

SELECT TOP (3)
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT f.order_number) AS total_orders
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
    ON f.customer_key = c.customer_key
WHERE f.order_number IS NOT NULL
GROUP BY
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY
    total_orders ASC,
    c.customer_key ASC;


/* ============================================================================
   REUSABILITY & VALIDATION NOTES

   1. Review metric definitions: revenue, units, net vs. gross sales, returns.
   2. Check whether one order_number may be used by multiple customers.
   3. For all catalog products (including unsold), start from dim_products
      and LEFT JOIN fact_sales; COALESCE(SUM(sales_amount), 0).
   4. For all registered customers (including zero-order customers), start
      from dim_customers and LEFT JOIN fact_sales.
   5. If ties should share the same rank, use RANK() or DENSE_RANK(); decide
      whether you want exactly N rows or all rows tied at the cutoff.
   6. If product keys / customer keys are NULL due to unmatched dimensions,
      investigate referential integrity before publishing conclusions.
   7. Compare the TOP and ROW_NUMBER() versions of section 01/02 to verify
      they produce the same five products when tie-breaking is consistent.

   The SQL is supplied as a reusable portfolio template and has not been
   executed against the user's database.
============================================================================ */
