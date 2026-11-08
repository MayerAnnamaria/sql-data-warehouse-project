/* ============================================================================
   DATA WAREHOUSE ANALYTICS | 10 - DATA SEGMENTATION
   ============================================================================
   Project       : Data Warehouse Analytics
   Database      : DataWarehouseAnalytics
   Platform      : Microsoft SQL Server (T-SQL)
   Data layer    : Gold (dimensional model)
   Tables        : gold.dim_products, gold.dim_customers, gold.fact_sales
   Analysis type : Data segmentation

   OBJECTIVE
   ---------
   Classify products by unit cost and purchasing customers by observed purchase
   history and lifetime spending. Summarize the size of each resulting segment.

   BUSINESS RULES
   --------------
   Product cost bands (cost units are those stored in the source database):
       Below 100      : cost < 100
       100-499.99     : 100 <= cost < 500
       500-999.99     : 500 <= cost < 1000
       1000 and above : cost >= 1000
       Unknown        : cost IS NULL

   Customer segments (based on orders observed in the available dataset):
       VIP     : >= 12 calendar-month boundaries AND total spending > 5000
       Regular : >= 12 calendar-month boundaries AND total spending <= 5000
       New     : < 12 calendar-month boundaries

   NOTE: DATEDIFF(MONTH, first_order_date, last_order_date) counts month
   boundaries crossed, not elapsed full months. The 'New' label describes
   observed purchasing history, NOT necessarily the customer's account age.
   Customers with no qualifying dated order are excluded from these purchasing
   segments. Monetary thresholds should be reviewed for other datasets.

   SCOPE
   -----
   This script contains segmentation ONLY. Trend analysis, rankings,
   performance comparisons, and customer/product reporting belong elsewhere.

   SAFETY
   ------
   Read-only queries. No objects or data are created, updated, or deleted.
   ============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | PRODUCT COST SEGMENTATION
   Business question: How many products belong to each unit-cost range?
   Grain: One row per cost band.
   Techniques: CASE, CTE, COUNT, GROUP BY.
   ============================================================================ */

-- 01.01 | Product count by mutually exclusive cost band.
WITH product_cost_segments AS (
    SELECT
        p.product_key,
        CASE
            WHEN p.cost IS NULL THEN 'Unknown'
            WHEN p.cost < 100 THEN 'Below 100'
            WHEN p.cost < 500 THEN '100-499.99'
            WHEN p.cost < 1000 THEN '500-999.99'
            ELSE '1000 and above'
        END AS cost_segment,
        CASE
            WHEN p.cost IS NULL THEN 5
            WHEN p.cost < 100 THEN 1
            WHEN p.cost < 500 THEN 2
            WHEN p.cost < 1000 THEN 3
            ELSE 4
        END AS segment_sort_order
    FROM gold.dim_products AS p
)
SELECT
    cost_segment,
    COUNT(*) AS total_products
FROM product_cost_segments
GROUP BY
    cost_segment,
    segment_sort_order
ORDER BY
    segment_sort_order;
GO

/* ============================================================================
   02 | CUSTOMER SPENDING & LIFESPAN SEGMENTATION
   Business question: Which purchasing customers are VIP, Regular, or New?
   Grain: One row per customer with at least one dated order.
   Techniques: JOIN, SUM, MIN, MAX, DATEDIFF, CASE, CTE.
   ============================================================================ */

-- 02.01 | Customer-level spending, first/last order, and segment assignment.
WITH customer_purchase_history AS (
    SELECT
        f.customer_key,
        SUM(f.sales_amount) AS total_spending,
        MIN(f.order_date) AS first_order_date,
        MAX(f.order_date) AS last_order_date,
        DATEDIFF(
            MONTH,
            MIN(f.order_date),
            MAX(f.order_date)
        ) AS observed_lifespan_months
    FROM gold.fact_sales AS f
    WHERE f.order_date IS NOT NULL
      AND f.customer_key IS NOT NULL
    GROUP BY
        f.customer_key
)
SELECT
    h.customer_key,
    h.total_spending,
    h.first_order_date,
    h.last_order_date,
    h.observed_lifespan_months,
    CASE
        WHEN h.observed_lifespan_months >= 12
             AND h.total_spending > 5000 THEN 'VIP'
        WHEN h.observed_lifespan_months >= 12
             AND h.total_spending <= 5000 THEN 'Regular'
        WHEN h.observed_lifespan_months < 12 THEN 'New'
        ELSE 'Unclassified'
    END AS customer_segment
FROM customer_purchase_history AS h
ORDER BY
    h.total_spending DESC,
    h.customer_key;
GO

/* ============================================================================
   03 | CUSTOMER SEGMENT DISTRIBUTION
   Business question: How many purchasing customers are in each segment?
   Grain: One row per customer segment.
   Techniques: CTEs, CASE, COUNT, GROUP BY.
   ============================================================================ */

-- 03.01 | Count customers in each spending/lifespan segment.
WITH customer_purchase_history AS (
    SELECT
        f.customer_key,
        SUM(f.sales_amount) AS total_spending,
        DATEDIFF(
            MONTH,
            MIN(f.order_date),
            MAX(f.order_date)
        ) AS observed_lifespan_months
    FROM gold.fact_sales AS f
    WHERE f.order_date IS NOT NULL
      AND f.customer_key IS NOT NULL
    GROUP BY
        f.customer_key
),
customer_segments AS (
    SELECT
        h.customer_key,
        CASE
            WHEN h.observed_lifespan_months >= 12
                 AND h.total_spending > 5000 THEN 'VIP'
            WHEN h.observed_lifespan_months >= 12
                 AND h.total_spending <= 5000 THEN 'Regular'
            WHEN h.observed_lifespan_months < 12 THEN 'New'
            ELSE 'Unclassified'
        END AS customer_segment
    FROM customer_purchase_history AS h
)
SELECT
    customer_segment,
    COUNT(*) AS total_customers
FROM customer_segments
GROUP BY
    customer_segment
ORDER BY
    CASE customer_segment
        WHEN 'VIP' THEN 1
        WHEN 'Regular' THEN 2
        WHEN 'New' THEN 3
        ELSE 4
    END;
GO

/* ============================================================================
   REUSABILITY & VALIDATION NOTES
   ============================================================================
   1. Rename the database, schema, and fields when adapting this file.
   2. Verify that product_key is unique in gold.dim_products; if this table is
      historical (SCD Type 2), decide whether to count all versions or current
      products before using COUNT(*).
   3. Confirm that fact_sales.sales_amount represents the intended measure.
      Refunds, credits, canceled orders, and the dataset's currency may affect
      customer spending and thresholds.
   4. Check that fact_sales has the intended grain (typically one order line)
      and that order_date represents the transaction date you wish to analyze.
   5. The original segmentation uses first-to-last purchase lifespan, so a
      customer with one observed order will be 'New' regardless of account age.
   6. Adjust cost/spending thresholds and display labels for other datasets.
   7. Validate segment totals against distinct qualifying customer keys:

       SELECT COUNT(DISTINCT customer_key) AS qualifying_customers
       FROM gold.fact_sales
       WHERE order_date IS NOT NULL AND customer_key IS NOT NULL;

   8. The current customer queries use fact_sales customer keys. To include
      non-purchasing registered customers, start from gold.dim_customers and
      LEFT JOIN the aggregated purchase history, assigning a separate segment
      such as 'No Purchases'. That is a different business definition.
   ============================================================================ */
