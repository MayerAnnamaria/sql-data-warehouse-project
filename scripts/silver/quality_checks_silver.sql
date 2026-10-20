/*
===============================================
Quality Checks
===============================================
Script Purpose:
  This script performs various quality checks for data consistency, accuracy, and standardization 
  across the 'silver' schemas. It includes checks for:
  - Null or duplicate primary keys.
  - Unwanted spaces in string fields.
  - Data standardization and consistency.
  - Invalid date ranges and orders.
  - Data consistency between related fields.

Usage Notes:
  - Run these checks after data loading Silver Layer.
  - Investigate and resolve any discrepancies found during the checks.
================================================
*/

USE DataWarehouse;
GO

-- =======================================================================
-- TABLE 1: bronze.crm_cust_info
-- ==========================================================================
-- Check for NULLS or Duplicates in the Primary Key
SELECT
cst_id,
COUNT(*) AS appears_this_many_times_or_is_null
FROM bronze.crm_cust_info
GROUP By cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- we have 3 identical rows, so we select the most recent data = sort data by the creation date
SELECT
*,
ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
FROM bronze.crm_cust_info
WHERE cst_id = 29466;
-- 
-- see all data and the duplicates, if flag_last > 1 then there are duplicates
SELECT
*
FROM (
    SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
    FROM bronze.crm_cust_info
)t WHERE flag_last != 1

-- see all data that we don't need, see all duplicates 
SELECT
*
FROM (
    SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
    FROM bronze.crm_cust_info
)t WHERE flag_last != 1

-- see the data without duplicates
-- see the data where the primary key (cst_id) is unique and not NULL
SELECT
*
FROM (
    SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
)t WHERE flag_last = 1

--------------------------------------------------------------------------------------
-- Check for unwanted spaces
-- see the list of all first names where we have spaces
-- Expectation: no results = no names with spaces, just like for cst_gndr
SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)

SELECT cst_lastname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_lastname)

SELECT cst_gndr
FROM bronze.crm_cust_info
WHERE cst_gndr != TRIM(cst_gndr)

-- Data Standardization and Consistency
SELECT DISTINCT cst_gndr
FROM bronze.crm_cust_info
--------------------------------------------------------------------------------------

-- remove unwanted spaces with TRIM
-- n/a : means unknown data
-- change cst_marital_status to cst_marital_status
-- recode data with the CASE WHEN
-- for date columns make sure that the date is not a string, but a real date type
-- then insert the data into the silver layer's table by running it with INSERT INTO

-- rename the wrong table column in the silver layer from cst_marital_status to cst_marital_status
-- EXEC sp_rename
--   'silver.crm_cust_info.cst_marital_status',
--    'cst_marital_status',
--    'COLUMN';

TRUNCATE TABLE silver.crm_cust_info; -- so that it doesn't insert the data twice
PRINT '>> Inserting Data Into: silver.crm_cust_info';
INSERT INTO silver.crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date )

SELECT
cst_id,
cst_key,
TRIM(cst_firstname) AS cst_firstname,
TRIM(cst_lastname) AS cst_lastname,
CASE WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
     WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
     ELSE 'n/a'
END AS cst_marital_status,
CASE WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
     WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
     ELSE 'n/a'
END AS cst_gndr,
cst_create_date
FROM (
    SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
)t WHERE flag_last = 1

-- Check for NULLS or Duplicates in the Primary Key in the Silver layer
-- Expected: no data is displayed
SELECT
cst_id,
COUNT(*) AS appears_this_many_times_or_is_null
FROM silver.crm_cust_info
GROUP By cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;


-- Check for unwanted spaces
-- see the list of all first names where we have spaces
-- Expectation: no results = no names with spaces, just like for cst_gndr
SELECT cst_firstname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)

SELECT cst_lastname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_lastname)

-- Data Standardization and Consistency
SELECT DISTINCT cst_gndr
FROM silver.crm_cust_info

SELECT * FROM silver.crm_cust_info

-- =======================================================================
-- TABLE 2: bronze.crm_prd_info
-- ==========================================================================

SELECT
prd_id,
prd_key,
-- extract the arguments, first 5 characters
-- replace minus with underscore
REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
-- extract the 2nd part from the string
SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
prd_nm,
ISNULL(prd_cost, 0) AS prd_cost,
CASE UPPER(TRIM(prd_line)) 
     WHEN 'M' THEN 'Mountain'
     WHEN 'R' THEN 'Road'
     WHEN 'S' THEN 'Other Sales'
     WHEN 'T' THEN 'Touring'
     ELSE 'n/a'
END AS prd_line,
CAST(prd_start_dt AS DATE) AS prd_start_dt,
CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) -1 AS DATE) AS prd_end_dt
FROM bronze.crm_prd_info
-- we need to have matching information in both the tables
-- see which cat_id is NOT IN the 2nd table, called: bronze.erp_px_cat_g1v2, use NOT IN
-- the CO_PE cat id is not in the 2nd table, called: bronze.erp_px_cat_g1v2, use NOT IN
-- the "IN" shows all
WHERE SUBSTRING(prd_key, 7, LEN(prd_key)) IN (
SELECT sls_prd_key FROM bronze.crm_sales_details)

-- in the bronze.erp_px_cat_g1v2 TABLE the ID is with underscore
SELECT DISTINCT id FROM bronze.erp_px_cat_g1v2

-- check the other table
SELECT sls_prd_key FROM bronze.crm_sales_details

-- Check for unwanted spaces
-- see the list of all first names where we have spaces
-- Expectation: no results = no names with spaces, just like for cst_gndr
SELECT prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)

-- Check for NULLS or Negative Numbers
SELECT prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL

-- Data Standardization and Consistency
SELECT DISTINCT prd_line
FROM bronze.crm_prd_info

-- Check for invalid date orders
-- end date must not be earlier than the start date
SELECT *
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt

-- reorganize bad data
-- access next record in the row: lead
-- -1: get the previous record

SELECT
    prd_id,
    prd_key,
    prd_nm,
    prd_start_dt,
    prd_end_dt,
    LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) -1 AS prd_end_dt_test
FROM bronze.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509')

-- ===============================================
-- INSERT the cleaned data into the silver layer
-- ===============================================
TRUNCATE TABLE silver.crm_prd_info; -- so that it doesn't insert the data twice
PRINT '>> Inserting Data Into: silver.crm_prd_info';
INSERT INTO silver.crm_prd_info (
    prd_id,
    cat_id,
    prd_key,
    prd_nm,
    prd_cost,
    prd_line,
    prd_start_dt,
    prd_end_dt
)
SELECT
prd_id,
-- extract the arguments, first 5 characters
-- replace minus with underscore
REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
-- extract the 2nd part from the string
SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,
prd_nm,
ISNULL(prd_cost, 0) AS prd_cost,
CASE UPPER(TRIM(prd_line)) 
     WHEN 'M' THEN 'Mountain'
     WHEN 'R' THEN 'Road'
     WHEN 'S' THEN 'Other Sales'
     WHEN 'T' THEN 'Touring'
     ELSE 'n/a'
END AS prd_line,
CAST(prd_start_dt AS DATE) AS prd_start_dt,
CAST(LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) -1 AS DATE) AS prd_end_dt
FROM bronze.crm_prd_info

-- check the data after inserting it into the table

-- Check for Nulls or duplicates in Primary Key
-- Expectation: No Result
SELECT
prd_id,
COUNT(*)
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL

-- Check for unwanted Spaces
-- Expectation: No Results
SELECT prd_nm
FROM silver.crm_prd_info
WHERE prd_nm != TRIM(prd_nm)

-- Check for NULLS or Negative Numbers
-- Expectation: No Results
SELECT prd_cost
FROM silver.crm_prd_info
WHERE prd_cost < 0 OR prd_cost IS NULL

-- Data Standardization and Consistency
SELECT DISTINCT prd_line
FROM silver.crm_prd_info

-- Check for Invalid Date Orders = for the order of the dates
SELECT *
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt

-- Have a final look at the silver table
SELECT *
FROM silver.crm_prd_info


-- =======================================================================
-- TABLE 3: bronze.crm_sales_details
-- ==========================================================================
SELECT
sls_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
sls_ship_dt,
sls_due_dt,
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details

-- check sls_ord_num column for white spaces
-- Expected: no data, so no white spaces
SELECT
sls_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
sls_ship_dt,
sls_due_dt,
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details
WHERE sls_ord_num != TRIM(sls_ord_num)

-- Check which product keys are not in the other table that we want to connect it with
-- so check which product keys from the bronze.crm_sales_details are not in the silver.crm_prd_info
-- Expected: no result means all product keys can be connected
SELECT
sls_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
sls_ship_dt,
sls_due_dt,
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)

-- check if we can connect the bronze.crm_sales_details with the silver.crm_prd_info
-- Expected: no results, so sls_prd_key from bronze.crm_sales_details can be connected to silver.crm_prd_info
SELECT
sls_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
sls_ship_dt,
sls_due_dt,
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)

-- check Dates columns
-- sls_order_dt, sls_ship_dt, sls_due_dt: change the datatype from INT to DATE
SELECT
sls_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
sls_ship_dt,
sls_due_dt,
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)

-- Check for Invalid Dates, where dates are 0 or less than 0
-- this is bad data, so we change this information to "NULL"
-- the data should be 8 digits, so this shows the bad data: LEN(sls_order_dt) !=8

SELECT
NULLIF(sls_order_dt, 0) sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 

-- it is bad data quality if length is not 8
SELECT
NULLIF(sls_order_dt, 0) sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 OR LEN(sls_order_dt) !=8 


-- then check data boundaries of the date range as well: sls_order_dt > 20500101
SELECT
NULLIF(sls_order_dt, 0) sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt > 20500101 OR sls_order_dt < 19000101

-- check the bad data for the shipping date column
-- Expected: no results, so no bad data
SELECT NULLIF(sls_ship_dt,0) sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt <= 0
OR LEN(sls_ship_dt) != 8
OR sls_ship_dt > 20500101
OR sls_ship_dt < 19000101

-- check: the order date should always be smaller than the shipping date or the due date
-- so check for invalid date orders
SELECT
*
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

-- Fix all the 3 date columns, order_dt, ship_dt, due_dt: the strange numbers that cannot be converted to a date
-- ELSE CAST(CAST(sls_order_dt AS VARCHAR)) AS DATE): transform and integer to a date
SELECT
sls_ord_num,
sls_prd_key,
sls_cust_id,
sls_order_dt,
CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
     ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
END AS sls_ship_dt,
CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
     ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
END AS sls_ship_dt,
CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
     ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
END AS sls_due_dt,
sls_ship_dt,
sls_due_dt,
CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
        THEN sls_quantity * ABS(sls_price)
     ELSE sls_sales
END AS sls_sales,
sls_quantity,
CASE WHEN sls_price is NULL OR sls_price <= 0
        THEN sls_sales / NULLIF(sls_quantity, 0)
     ELSE sls_price
END AS sls_price
FROM bronze.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)

-- check last 3 columns
-- sales must be equal to quantity * price
-- negative, zeros, Nulls are Not Allowed
SELECT DISTINCT
sls_sales,
sls_quantity,
sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price

-- so, to fix the bad data issues:
-- if the sales is negative, zero or null, then derive sales from quantity * price
-- if price is zero or null, then calculate it using sales and quantity
-- if the price is negative, then convert it to a positive value, e.g. -21 to 21 -> ABS() function
-- NULLIF(sls_quantity, 0): if you get any zero, then replace it with a NULL
SELECT DISTINCT
sls_sales AS old_sls_sales,
sls_quantity,
sls_price AS old_sls_price,
CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
        THEN sls_quantity * ABS(sls_price)
     ELSE sls_sales
END AS sls_sales,
CASE WHEN sls_price is NULL OR sls_price <= 0
        THEN sls_sales / NULLIF(sls_quantity, 0)
     ELSE sls_price
END AS sls_price
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price

-- the final cleaned table in the silver layer:
TRUNCATE TABLE silver.crm_sales_details; -- so that it doesn't insert the data twice
PRINT '>> Inserting Data Into: silver.crm_sales_details';
INSERT INTO silver.crm_sales_details (
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    sls_order_dt,
    sls_ship_dt,
    sls_due_dt,
    sls_sales,
    sls_quantity,
    sls_price
)
SELECT
sls_ord_num,
sls_prd_key,
sls_cust_id,
CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
     ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE)
END AS sls_ship_dt,
CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
     ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
END AS sls_ship_dt,
CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
     ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
END AS sls_due_dt,
CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
        THEN sls_quantity * ABS(sls_price)
     ELSE sls_sales
END AS sls_sales, -- Recalculate sales if original value is missing or incorrect
sls_quantity,
CASE WHEN sls_price is NULL OR sls_price <= 0
        THEN sls_sales / NULLIF(sls_quantity, 0)
     ELSE sls_price
END AS sls_price
FROM bronze.crm_sales_details


-- -----------------------
-- check data quality after inserting data 
-- -----------------------
-- check: the order date should always be smaller than the shipping date or the due date
-- so check for invalid date orders
SELECT
*
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

-- check the calculations
SELECT DISTINCT
sls_sales,
sls_quantity,
sls_price
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price

-- check the whole table
SELECT * FROM silver.crm_sales_details


-- =======================================================================
-- TABLE 4: bronze.erp_px_cat_g1v2
-- ==========================================================================
SELECT 
id,
cat,
subcat,
maintanance
FROM bronze.erp_px_cat_g1v2

-- Check string columns for unwanted Spaces
SELECT * FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintanance != TRIM(maintanance)

-- check the data standardization
SELECT DISTINCT
cat
FROM bronze.erp_px_cat_g1v2

-- check subcategory
SELECT DISTINCT
subcat
FROM bronze.erp_px_cat_g1v2

-- check maintanance column
SELECT DISTINCT
maintanance
FROM bronze.erp_px_cat_g1v2;

-- Clean the maintenance column, remove the strange characters
SELECT DISTINCT
    maintanance AS original_maintanance,
    CASE
        WHEN UPPER(TRIM(REPLACE(REPLACE(maintanance, CHAR(13), ''), CHAR(10), ''))) = 'YES'
            THEN 'Yes'
        WHEN UPPER(TRIM(REPLACE(REPLACE(maintanance, CHAR(13), ''), CHAR(10), ''))) = 'NO'
            THEN 'No'
        ELSE NULL
    END AS cleaned_maintanance
FROM bronze.erp_px_cat_g1v2;

-- insert the data
TRUNCATE TABLE silver.crm_sales_details; -- so that it doesn't insert the data twice
PRINT '>> Inserting Data Into: silver.crm_sales_details';
INSERT INTO silver.erp_px_cat_g1v2
(id, cat, subcat, maintanance)
SELECT
    id,
    cat,
    subcat,
    CASE
        WHEN UPPER(TRIM(REPLACE(REPLACE(maintanance, CHAR(13), ''), CHAR(10), ''))) = 'YES'
            THEN 'Yes'
        WHEN UPPER(TRIM(REPLACE(REPLACE(maintanance, CHAR(13), ''), CHAR(10), ''))) = 'NO'
            THEN 'No'
        ELSE NULL
    END AS maintanance
FROM bronze.erp_px_cat_g1v2; 

SELECT * FROM silver.erp_px_cat_g1v2; 

-- =======================================================================
-- TABLE 5: bronze.erp_cust_az12
-- ==========================================================================

SELECT
cid,
bdate,
gen 
FROM bronze.erp_cust_az12;

-- check data quality of gen column
SELECT DISTINCT
    gen AS original_value,
    NULLIF(
        TRIM(
            REPLACE(
                REPLACE(
                    REPLACE(gen, CHAR(13), ''),
                    CHAR(10), ''
                ),
                CHAR(9), ''
            )
        ),
        ''
    ) AS cleaned_gen
FROM bronze.erp_cust_az12;

-- fix bad data: F, M, and data with strange characters
SELECT 
    cid,
    bdate,
    CASE
        WHEN UPPER(TRIM(
            REPLACE(REPLACE(REPLACE(gen,
                CHAR(13), ''), CHAR(10), ''), CHAR(9), '')
        )) IN ('F', 'FEMALE')
            THEN 'Female'

        WHEN UPPER(TRIM(
            REPLACE(REPLACE(REPLACE(gen,
                CHAR(13), ''), CHAR(10), ''), CHAR(9), '')
        )) IN ('M', 'MALE')
            THEN 'Male'

        ELSE NULL
    END AS gen

FROM bronze.erp_cust_az12;

-- check the 2 tables that we want to join
SELECT
cid,
bdate,
gen
FROM bronze.erp_cust_az12;

SELECT * FROM silver.crm_cust_info;

-- what we see is that the bronze.erp_cust_az12 table in the cid column contains extra char:NASA
-- check a row
SELECT
cid,
bdate,
gen
FROM bronze.erp_cust_az12
WHERE cid LIKE '%AW00011000%';

SELECT * FROM silver.crm_cust_info;

-- so in order to be able to conect the bronze.erp_cust_az12 table to the silver.crm_cust_info
-- we remove the extra characters: NASA
-- clean cid column

SELECT 
    cid,
    CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- at position nr 4 extract the rest of the characters
        ELSE cid
    END cid,
    bdate,
    gen
FROM bronze.erp_cust_az12;

-- double check cid column
-- Expected: no data, so no unmatching data between the bronze.erp_cust_az12 and the silver.crm_cust_info tables
SELECT 
    cid,
    CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- at position nr 4 extract the rest of the characters
        ELSE cid
    END AS cid,
    bdate,
    gen
FROM bronze.erp_cust_az12
WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
      ELSE cid
END NOT IN (SELECT DISTINCT cst_key FROM silver.crm_cust_info)

-- check DATE column, check data type, identify out-of-range dates
-- check for bdates in the future
SELECT DISTINCT
bdate
FROM bronze.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE() -- check if we have customers older than 100 year or bdate higher than the current date

-- clean the bdate column
SELECT
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid))
     ELSE cid
END AS cid,
CASE WHEN bdate > GETDATE() THEN NULL -- if bdate larger than current time, then show NULL
     ELSE bdate
END AS bdate,
gen
FROM bronze.erp_cust_az12

-- check gen column
SELECT DISTINCT gen
FROM bronze.erp_cust_az12

--
SELECT 
    cid,
    CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- at position nr 4 extract the rest of the characters
        ELSE cid
    END cid,
    bdate,
    CASE
        WHEN UPPER(TRIM(
            REPLACE(REPLACE(REPLACE(gen,
                CHAR(13), ''), CHAR(10), ''), CHAR(9), '')
        )) IN ('F', 'FEMALE')
            THEN 'Female'

        WHEN UPPER(TRIM(
            REPLACE(REPLACE(REPLACE(gen,
                CHAR(13), ''), CHAR(10), ''), CHAR(9), '')
        )) IN ('M', 'MALE')
            THEN 'Male'
        ELSE 'n/a'
    END AS gen

FROM bronze.erp_cust_az12;

-- check 
SELECT DISTINCT 
gen as old_gen,
CASE
        WHEN UPPER(TRIM(
            REPLACE(REPLACE(REPLACE(gen,
                CHAR(13), ''), CHAR(10), ''), CHAR(9), '')
        )) IN ('F', 'FEMALE')
            THEN 'Female'

        WHEN UPPER(TRIM(
            REPLACE(REPLACE(REPLACE(gen,
                CHAR(13), ''), CHAR(10), ''), CHAR(9), '')
        )) IN ('M', 'MALE')
            THEN 'Male'
        ELSE 'n/a'
    END AS gen
FROM bronze.erp_cust_az12;

TRUNCATE TABLE silver.erp_cust_az12;
PRINT '>> Inserting Data Into: silver.erp_cust_az12';
INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
SELECT
CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) -- at position nr 4 extract the rest of the characters
    ELSE cid
END AS cid,
CASE WHEN bdate > GETDATE() THEN NULL -- if bdate larger than current time, then show NULL
     ELSE bdate
END AS bdate,
CASE
    WHEN UPPER(TRIM(
        REPLACE(REPLACE(REPLACE(gen,
            CHAR(13), ''), CHAR(10), ''), CHAR(9), '')
    )) IN ('F', 'FEMALE')
        THEN 'Female'

    WHEN UPPER(TRIM(
        REPLACE(REPLACE(REPLACE(gen,
            CHAR(13), ''), CHAR(10), ''), CHAR(9), '')
    )) IN ('M', 'MALE')
        THEN 'Male'
    ELSE 'n/a'
END AS gen
FROM bronze.erp_cust_az12;

-- CHECK data quality

-- Identify out-of-range dates
SELECT DISTINCT 
bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01' OR bdate > GETDATE()

-- Data Standardization and Consistency
SELECT DISTINCT 
gen 
FROM silver.erp_cust_az12

-- take a final look at the table
SELECT * FROM silver.erp_cust_az12;

-- =======================================================================
-- TABLE 6: bronze.erp_loc_a101
-- =======================================================================
-- check the 2 tables that we want to join bronze.erp_loc_a101 and silver.crm_cust_info
SELECT
cid,
cntry 
FROM bronze.erp_loc_a101;

SELECT cst_key FROM silver.crm_cust_info;


-- we need to remove the "-" in the cid column in the bronze.erp_loc_a101 table
SELECT
REPLACE(cid, '-', '') cid, 
cntry 
FROM bronze.erp_loc_a101;

-- check if we have any unmatching data in the cid column between the 2 tables
-- Expected: no result
SELECT
REPLACE(cid, '-', '') cid, 
cntry 
FROM bronze.erp_loc_a101 WHERE REPLACE(cid, '-', '') NOT IN 
(SELECT cst_key FROM silver.crm_cust_info)

-- Check cntry column: Data Standardization and Consistency
SELECT DISTINCT cntry 
FROM bronze.erp_loc_a101
ORDER BY cntry 

-- clean cntry column
-- CHAR(13) removes carriage returns.
-- CHAR(10) removes line breaks.
-- CHAR(9) removes tabs.

SELECT DISTINCT
    cntry AS original_cntry,
    REPLACE(cid, '-', '') AS cid,
    CASE
        WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) = 'DE'
            THEN 'Germany'
        WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) IN ('US', 'USA')
            THEN 'United States'
        WHEN TRIM(REPLACE(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''), CHAR(9), '')) = ''
             OR cntry IS NULL
            THEN 'n/a'
        ELSE TRIM(REPLACE(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''), CHAR(9), ''))
    END AS cntry
FROM bronze.erp_loc_a101;

-- check the distinct values
SELECT DISTINCT
    cntry AS original_cntry,
    CASE
        WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) = 'DE'
            THEN 'Germany'
        WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) IN ('US', 'USA')
            THEN 'United States'
        WHEN TRIM(REPLACE(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''), CHAR(9), '')) = ''
             OR cntry IS NULL
            THEN 'n/a'
        ELSE TRIM(REPLACE(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''), CHAR(9), ''))
    END AS cntry
FROM bronze.erp_loc_a101;

-- so the final cleaned table will be
TRUNCATE TABLE silver.erp_loc_a101;
PRINT '>> Inserting Data Into: silver.erp_loc_a101';
INSERT INTO silver.erp_loc_a101 (cid, cntry)
SELECT
REPLACE(cid, '-', '') cid, 
    CASE
        WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) = 'DE'
            THEN 'Germany'
        WHEN TRIM(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), '')) IN ('US', 'USA')
            THEN 'United States'
        WHEN TRIM(REPLACE(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''), CHAR(9), '')) = ''
             OR cntry IS NULL
            THEN 'n/a'
        ELSE TRIM(REPLACE(REPLACE(REPLACE(cntry, CHAR(13), ''), CHAR(10), ''), CHAR(9), ''))
    END AS cntry
FROM bronze.erp_loc_a101

-- double check data quality: Data standardization and Consistency
SELECT DISTINCT cntry 
FROM silver.erp_loc_a101 
ORDER BY cntry 

-- check the entire table
SELECT * FROM silver.erp_loc_a101 

-- =======================================================================
-- TABLE: bronze.erp_px_cat_g1v2
-- =======================================================================
SELECT 
id,
cat,
subcat,
maintanance
FROM bronze.erp_px_cat_g1v2

-- check for unwanted spaces
SELECT * FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat)

-- check for unwanted spaces
SELECT * FROM bronze.erp_px_cat_g1v2
WHERE subcat != TRIM(subcat) OR maintanance != TRIM(maintanance)

-- Data Standardization and Consistency
SELECT DISTINCT
cat
FROM bronze.erp_px_cat_g1v2

-- Data Standardization and Consistency
SELECT DISTINCT
subcat
FROM bronze.erp_px_cat_g1v2

-- Data Standardization and Consistency
SELECT DISTINCT
    TRIM(
        REPLACE(
            REPLACE(
                REPLACE(maintanance, CHAR(13), ''),
                CHAR(10), ''),
            CHAR(9), '')
    ) AS cleaned_maintanance
FROM bronze.erp_px_cat_g1v2

-- so final table
TRUNCATE TABLE silver.erp_px_cat_g1v2;
PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintanance)
SELECT 
id,
cat,
subcat,
    TRIM(
        REPLACE(
            REPLACE(
                REPLACE(maintanance, CHAR(13), ''),
                CHAR(10), ''),
            CHAR(9), '')
    ) AS maintanance
FROM bronze.erp_px_cat_g1v2

-- check the inserted data
SELECT * FROM silver.erp_px_cat_g1v2;
