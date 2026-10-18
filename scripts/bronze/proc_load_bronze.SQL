/*
=============================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
=============================================================
Script Purpose:
  This stored procedure loads data into the 'bronze' schema from external CSV files.
  It performs the following action:
  - Truncates the bronze tables before loading data.
  - Uses the 'BULK INSERT' command to load data from csv Files to bronze tables.

  Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

  Usage Example:
    EXEC bronze.load_bronze;
===========================================================
*/

USE DataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    -- declare the variables for checking the data load duration time
    DECLARE @start_time DATETIME, @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY
      SET @batch_start_time = GETDATE();
      PRINT '===========================================';
      PRINT 'Loading Bronze Layer';
      PRINT '===========================================';
  
      PRINT '-----------------------------------------';
      PRINT 'Loading CRM Tables'
      PRINT '-----------------------------------------';
  
      -- get the exact starting time of the loading
      SET @start_time = GETDATE();
      
      -- First make the table empty and then load the data from the scratch = means full load the data
      TRUNCATE TABLE bronze.crm_cust_info;
  
      PRINT '>> Inserting Data Into: bronze.crm_cust_info';
      BULK INSERT bronze.crm_cust_info
      FROM '/tmp/bulkload/crm_source/cust_info.csv'
      WITH (
          -- we only read the data from the 2nd row
          FIRSTROW = 2,
          -- the delimiter is a comma
          FIELDTERMINATOR = ',',
          TABLOCK
      );
  
      -- get the end loading time of the table
      SET @end_time = GETDATE();
      PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
      PRINT '>> --------------------------';
  
      -- Check imported data
      --   SELECT * FROM bronze.crm_cust_info;
  
      --   SELECT COUNT(*) FROM bronze.crm_cust_info;
  
  
      -- To use it on a mac:
      -- Copy the CRM CSV files from your Mac into the crm_source folder in the Docker
      -- docker cp "/Users/Shared/sql-data-warehouse-project/datasets/source_crm/prd_info.csv" sqlserver:/tmp/bulkload/crm_source/prd_info.csv
      -- Use the Docker file paths in your BULK INSERT statements:
      -- /tmp/bulkload/crm_source/prd_info.csv
  
      --
      SET @start_time = GETDATE();
  
      TRUNCATE TABLE bronze.crm_prd_info;
      PRINT '>> Inserting Data Into: bronze.crm_prd_info';
      BULK INSERT bronze.crm_prd_info
      FROM '/tmp/bulkload/crm_source/prd_info.csv'
      WITH (
          -- we only read the data from the 2nd row
          FIRSTROW = 2,
          -- the delimiter is a comma
          FIELDTERMINATOR = ',',
          TABLOCK
      );
  
      -- get the end loading time of the table
      SET @end_time = GETDATE();
      PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
      PRINT '>> --------------------------';
  
  
      --   SELECT * FROM bronze.crm_prd_info;
  
      --   SELECT COUNT(*) FROM bronze.crm_prd_info;
  
      -- To use it on a mac:
      -- Copy the CRM CSV files from your Mac into the crm_source folder in the Docker
      -- docker cp "/Users/Shared/sql-data-warehouse-project/datasets/source_crm/sales_details.csv" sqlserver:/tmp/bulkload/crm_sourcesales_detail.scsv
      -- Use the Docker file paths in your BULK INSERT statements:
      -- /tmp/bulkload/crm_source/sales_details.csv
  
      SET @start_time = GETDATE();
  
      TRUNCATE TABLE bronze.crm_sales_details;
      PRINT '>> Inserting Data Into: bronze.crm_sales_details';
      BULK INSERT bronze.crm_sales_details
      FROM '/tmp/bulkload/crm_source/sales_details.csv'
      WITH (
          FIRSTROW = 2,
          FIELDTERMINATOR = ',',
          ROWTERMINATOR = '0x0a',
          TABLOCK
      );
  
      -- get the end loading time of the table
      SET @end_time = GETDATE();
      PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
      PRINT '>> --------------------------';
  
      --   SELECT * FROM bronze.crm_sales_details;
  
      --   SELECT COUNT(*) FROM bronze.crm_sales_details;
  
      -- To use it on a mac:
      -- To load the data from the source erp folder:
      -- Copy the CRM CSV files from your Mac into the crm_source folder in the Docker
      -- docker cp "/Users/Shared/sql-data-warehouse-project/datasets/source_erp/CUST_AZ12.csv" sqlserver:/tmp/bulkload/erp_CUST_AZ12.csv
      -- Use the Docker file paths in your BULK INSERT statements:
      -- /tmp/bulkload/erp_source/CUST_AZ12.csv
      -- Verify that the files were successfully copied:
      -- docker exec sqlserver ls -l /tmp/bulkload/erp_source/
  
      -- =====================================================
      -- 2. ERP SOURCE FILES
      -- =====================================================
  
      PRINT '-----------------------------------------';
      PRINT 'Loading ERP Tables'
      PRINT '-----------------------------------------';
  
      -- Customer Information
      SET @start_time = GETDATE();
  
      TRUNCATE TABLE bronze.erp_cust_az12;
      PRINT '>> Inserting Data Into: bronze.erp_cust_az12';
      BULK INSERT bronze.erp_cust_az12
      FROM '/tmp/bulkload/source_erp/CUST_AZ12.csv'
      WITH (
          FIRSTROW = 2,
          FIELDTERMINATOR = ',',
          TABLOCK
      );
  
      -- get the end loading time of the table
      SET @end_time = GETDATE();
      PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
      PRINT '>> --------------------------';
  
      -- SELECT * FROM bronze.erp_cust_az12;
  
      -- SELECT COUNT(*) FROM bronze.erp_cust_az12;
  
      -- Location Information
  
      SET @start_time = GETDATE();
  
      TRUNCATE TABLE bronze.erp_loc_a101;
      PRINT '>> Inserting Data Into: bronze.erp_loc_a101';
      BULK INSERT bronze.erp_loc_a101
      FROM '/tmp/bulkload/source_erp/LOC_A101.csv'
      WITH (
          FIRSTROW = 2,
          FIELDTERMINATOR = ',',
          TABLOCK
      );
  
      -- get the end loading time of the table
      SET @end_time = GETDATE();
      PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
      PRINT '>> --------------------------';
  
      --   SELECT * FROM bronze.erp_loc_a101;
  
      --   SELECT COUNT(*) FROM bronze.erp_loc_a101;
  
  
      -- Product Category Information
      SET @start_time = GETDATE();
  
      TRUNCATE TABLE bronze.erp_px_cat_g1v2;
      PRINT '>> Inserting Data Into: bronze.erp_px_cat_g1v2';
      BULK INSERT bronze.erp_px_cat_g1v2
      FROM '/tmp/bulkload/source_erp/PX_CAT_G1V2.csv'
      WITH (
          FIRSTROW = 2,
          FIELDTERMINATOR = ',',
          TABLOCK
      );
  
      -- get the end loading time of the table
      SET @end_time = GETDATE();
      PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';
      PRINT '>> --------------------------';
  
      SET @batch_end_time = GETDATE();
      PRINT '=======================================';
      PRINT 'Loading Bronze Layer is Completed';
      PRINT '- Total Load Duration:' + CAST(DATEDIFF(SECOND, @batch_start_time, @batch_end_time) AS NVARCHAR) + ' seconds';
      PRINT '=======================================';
  
  
    --   SELECT * FROM bronze.erp_px_cat_g1v2;
    --   SELECT COUNT(*) FROM bronze.erp_px_cat_g1v2;
    END TRY
    BEGIN CATCH
        PRINT '=============================';
        PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
        PRINT 'ERROR Message' + ERROR_MESSAGE();
        PRINT 'ERROR Message' + CAST (ERROR_NUMBER() AS NVARCHAR);
        PRINT 'ERROR Message' + CAST (ERROR_STATE() AS NVARCHAR);
        PRINT '=============================';
    END CATCH
END

