/*
============================================================
DDL Script: Create Silver Tables
============================================================
Script Purpose:
  This script creates tables in the 'silver' schema, dropping existing tables if they already exist.
  Run this script to re-define the DDL structure of the 'bronze' Tables
============================================================
*/

USE DataWarehouse;
GO

-- Check if table exists in the database. 
-- If the table exists, then first drop the table and then create it
IF OBJECT_ID('silver.crm_cust_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_cust_info;

-- Follow the table naming convention: <sourcesystem>_<entity>
-- All names must start with the source system name, and the table names must match their original names without renaming
-- <sourcesystem>: Name of the source system (e.g. crm, erp)
-- <entity>: Exact table name from the source system
-- Example: crm_customer_info -> Customer information from the CRM system

CREATE TABLE silver.crm_cust_info (
    cst_id INT,
    cst_key NVARCHAR(50),
    cst_firstname NVARCHAR(50),
    cst_lastname NVARCHAR(50),
    cst_marital_status NVARCHAR(50),
    cst_gndr NVARCHAR(50),
    cst_create_date DATE,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);


IF OBJECT_ID('silver.crm_prd_info', 'U') IS NOT NULL
    DROP TABLE silver.crm_prd_info;

CREATE TABLE silver.crm_prd_info (
    prd_id          INT,
    cat_id          NVARCHAR(50),
    prd_key         NVARCHAR(50),
    prd_nm          NVARCHAR(50),
    prd_cost        INT,
    prd_line        NVARCHAR(50),
    prd_start_dt    DATE,
    prd_end_dt      DATE,
    -- indicates when we loaded this table
    dwh_create_date DATETIME2 DEFAULT GETDATE() 
);

SELECT
    @@SERVERNAME AS ServerName,
    DB_NAME() AS CurrentDatabase,
    SCHEMA_ID('silver') AS silverSchemaID;

IF OBJECT_ID('silver.crm_sales_details', 'U') IS NOT NULL
    DROP TABLE silver.crm_sales_details;

CREATE TABLE silver.crm_sales_details (
    sls_ord_num NVARCHAR(50),
    sls_prd_key NVARCHAR(50),
    sls_cust_id INT,
    sls_order_dt DATE,
    sls_ship_dt DATE,
    sls_due_dt DATE,
    sls_sales INT,
    sls_quantity INT,
    sls_price INT,
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('silver.erp_loc_a101', 'U') IS NOT NULL
    DROP TABLE silver.erp_loc_a101;

CREATE TABLE silver.erp_loc_a101 (
    cid NVARCHAR(50),
    cntry NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('silver.erp_cust_az12', 'U') IS NOT NULL
    DROP TABLE silver.erp_cust_az12;

CREATE TABLE silver.erp_cust_az12 (
    cid NVARCHAR(50),
    bdate DATE,
    gen NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('silver.erp_px_cat_g1v2', 'U') IS NOT NULL
    DROP TABLE silver.erp_px_cat_g1v2;

CREATE TABLE silver.erp_px_cat_g1v2 (
    ID          NVARCHAR(50),
    cat         NVARCHAR(50),
    subcat      NVARCHAR(50),
    maintanance NVARCHAR(50),
    dwh_create_date DATETIME2 DEFAULT GETDATE()
);




-- Insert the data into SQL Server
-- If you are using a Mac, SQL Server runs inside Docker and cannot directly access files stored on your Mac.

-- Step 1: Create a folder for CRM source files inside Docker using Terminal:
-- docker exec sqlserver mkdir -p /tmp/bulkload/crm_source

-- Step 2: Copy the CRM CSV files from your Mac into the crm_source folder:
-- docker cp "/Users/Shared/sql-data-warehouse-project/datasets/source_crm/cust_info.csv" sqlserver:/tmp/bulkload/crm_source/cust_info.csv
-- docker cp "/Users/Shared/sql-data-warehouse-project/datasets/source_crm/prd_info.csv" sqlserver:/tmp/bulkload/crm_source/prd_info.csv

-- Note: This assumes your Docker container is named sqlserver.

-- Step 3: Verify that the files were successfully copied:
-- docker exec sqlserver ls -l /tmp/bulkload/crm_source/

-- Step 4: Use the Docker file paths in your BULK INSERT statements:
-- /tmp/bulkload/crm_source/cust_info.csv
-- /tmp/bulkload/crm_source/prd_info.csv



