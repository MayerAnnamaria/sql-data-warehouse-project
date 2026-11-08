/* ============================================================================
   DATA WAREHOUSE ANALYTICS | CUSTOMER REPORT
   File        : 12_report_customers.sql
   Database    : DataWarehouseAnalytics
   Platform    : Microsoft SQL Server (T-SQL)
   Output      : gold.report_customers

   PURPOSE
   Consolidate customer demographics, purchasing behavior, customer segments,
   and key performance indicators into a reusable customer-level reporting view.

   DATA SOURCES
   - gold.fact_sales      : Sales transactions (order-line grain)
   - gold.dim_customers   : Customer attributes (customer_key grain)

   REPORT GRAIN
   One row per purchasing customer_key with a non-NULL order_date.
   Customers who have never ordered are intentionally excluded.

   METRICS
   - Distinct orders, revenue, units purchased, distinct products
   - First and last order dates, observed purchasing lifespan (months)
   - Recency (calendar-month boundaries since last order)
   - Average order value and average monthly spending

   SEGMENT DEFINITIONS (original business rules)
   - VIP     : Purchasing lifespan >= 12 months AND revenue > 5000
   - Regular : Purchasing lifespan >= 12 months AND revenue <= 5000
   - New     : Purchasing lifespan < 12 months

   ASSUMPTIONS
   - sales_amount is the revenue amount for each sales row.
   - fact_sales can contain multiple rows per order_number.
   - customer_key uniquely identifies customers in dim_customers.
   - SQL Server's DATEDIFF(MONTH, ...) counts calendar-month boundaries,
     not completed months of elapsed time.
   - Monetary units are inherited from the source data; no currency is assumed.
   - The view uses GETDATE(), so age and recency change as time passes.
   - The report calculates average monthly spend over inclusive calendar
     months touched by purchasing activity (lifespan_months + 1).

   EXECUTION
   Run the complete script in SSMS or VS Code's SQL Server query editor.
   GO separates the view definition from the optional verification queries.
   CREATE OR ALTER VIEW requires SQL Server 2016 SP1 or later.
============================================================================ */

USE DataWarehouseAnalytics;
GO

/* ============================================================================
   01 | BUILD CUSTOMER REPORT VIEW

   Business question:
   What is each purchasing customer's demographic profile, spending behavior,
   and customer segment?

   Implementation:
   1. Collect eligible sales rows and customer attributes.
   2. Aggregate transaction metrics at customer_key grain.
   3. Derive age, lifecycle segments, recency, and reporting KPIs.
============================================================================ */

CREATE OR ALTER VIEW gold.report_customers
AS
WITH base_sales AS (
    /* 01.01 | Base transactional data with customer attributes. */
    SELECT
        f.customer_key,
        c.customer_number,
        CONCAT_WS(' ', c.first_name, c.last_name) AS customer_name,
        c.birthdate,
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_customers AS c
        ON f.customer_key = c.customer_key
    WHERE f.order_date IS NOT NULL
      AND f.customer_key IS NOT NULL
),
customer_aggregation AS (
    /* 01.02 | One row per purchasing customer. */
    SELECT
        customer_key,
        MAX(customer_number) AS customer_number,
        MAX(customer_name) AS customer_name,
        MAX(birthdate) AS birthdate,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date))
            AS lifespan_months
    FROM base_sales
    GROUP BY customer_key
),
customer_profile AS (
    /* 01.03 | Age at execution date (birthday-aware). */
    SELECT
        a.*,
        CASE
            WHEN a.birthdate IS NULL THEN NULL
            WHEN CAST(a.birthdate AS DATE) > CAST(GETDATE() AS DATE)
                THEN NULL
            ELSE
                DATEDIFF(YEAR, a.birthdate, GETDATE())
                - CASE
                    WHEN DATEADD(
                        YEAR,
                        DATEDIFF(YEAR, a.birthdate, GETDATE()),
                        a.birthdate
                    ) > GETDATE() THEN 1
                    ELSE 0
                  END
        END AS age
    FROM customer_aggregation AS a
)
SELECT
    p.customer_key,
    p.customer_number,
    p.customer_name,
    p.age,

    /* 01.04 | Demographic age grouping. */
    CASE
        WHEN p.age IS NULL THEN 'Unknown'
        WHEN p.age < 20 THEN 'Under 20'
        WHEN p.age < 30 THEN '20-29'
        WHEN p.age < 40 THEN '30-39'
        WHEN p.age < 50 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,

    /* 01.05 | Customer segmentation using original thresholds. */
    CASE
        WHEN p.lifespan_months >= 12 AND p.total_sales > 5000
            THEN 'VIP'
        WHEN p.lifespan_months >= 12 AND p.total_sales <= 5000
            THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,

    /* 01.06 | Customer-level activity measures. */
    p.total_orders,
    p.total_sales,
    p.total_quantity,
    p.total_products,
    p.first_order_date,
    p.last_order_date,
    DATEDIFF(MONTH, p.last_order_date, GETDATE()) AS recency_months,
    p.lifespan_months,

    /* 01.07 | Monetary KPIs: cast to decimal to avoid integer division. */
    CAST(
        CAST(p.total_sales AS DECIMAL(19, 4))
        / NULLIF(p.total_orders, 0)
        AS DECIMAL(19, 2)
    ) AS avg_order_value,

    /* Inclusive count of observed calendar months: lifespan + 1. */
    CAST(
        CAST(p.total_sales AS DECIMAL(19, 4))
        / NULLIF(p.lifespan_months + 1, 0)
        AS DECIMAL(19, 2)
    ) AS avg_monthly_spend
FROM customer_profile AS p;
GO

/* ============================================================================
   02 | VERIFY REPORT OUTPUT

   Read-only checks executed AFTER the view has been created.
   These are examples, not additional views or tables.
============================================================================ */

-- 02.01 | Review the first 100 customer records.
SELECT TOP (100)
    customer_key,
    customer_number,
    customer_name,
    age,
    age_group,
    customer_segment,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    last_order_date,
    recency_months,
    lifespan_months,
    avg_order_value,
    avg_monthly_spend
FROM gold.report_customers
ORDER BY customer_key;

-- 02.02 | Customer distribution and total revenue by age group.
SELECT
    age_group,
    COUNT(*) AS total_customers,
    SUM(total_sales) AS total_sales
FROM gold.report_customers
GROUP BY age_group
ORDER BY
    CASE age_group
        WHEN 'Under 20' THEN 1
        WHEN '20-29' THEN 2
        WHEN '30-39' THEN 3
        WHEN '40-49' THEN 4
        WHEN '50 and above' THEN 5
        ELSE 6
    END;

-- 02.03 | Sanity check: one report row per purchasing customer key.
SELECT
    COUNT(*) AS report_rows,
    COUNT(DISTINCT customer_key) AS distinct_customer_keys
FROM gold.report_customers;

/* ============================================================================
   03 | REUSABILITY & VALIDATION NOTES

   - Change USE, source tables, and field names when adapting to new projects.
   - Verify customer_key uniqueness in gold.dim_customers before joining.
   - Confirm whether sales_amount includes discounts, refunds, or taxes.
   - Consider transaction date completeness when interpreting recency/lifespan.
   - If historical reproducibility is required, replace GETDATE() with a
     fixed as-of date in a parameterized query or table-valued function.
   - 'New' means short observed purchasing history, not recent registration.
   - The output excludes zero-order customers; use dim_customers as the
     driving table if they should appear in a separate full-customer report.
   - Distinct order_number must uniquely identify an order; if order numbers
     are only unique within a customer, the per-customer count is appropriate.
   - Average monthly spend uses inclusive calendar months to avoid an
     inconsistent special case when the lifespan is zero.
============================================================================ */
