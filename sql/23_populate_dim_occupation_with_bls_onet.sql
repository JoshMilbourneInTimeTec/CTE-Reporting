-- ============================================================================
-- File: sql/23_populate_dim_occupation_with_bls_onet.sql
-- Purpose: Populate SOC/O*NET codes and labor market data in dim_occupation
-- Phase: Phase 3.5 - Labor Market Data Integration
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Populate_dim_occupation_external_data', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Populate_dim_occupation_external_data;
GO

CREATE PROCEDURE dbo.sp_Populate_dim_occupation_external_data
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @RowsUpdated INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Populate_dim_occupation_external_data at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- Update dim_occupation with SOC codes, O*NET codes, and wage data from staging tables
        UPDATE dbo.dim_occupation
        SET
            soc_code = ISNULL(bls.soc_code, dim_occupation.soc_code),
            onet_code = ISNULL(onet.onet_code, dim_occupation.onet_code),
            median_annual_wage = ISNULL(bls.median_annual_wage, dim_occupation.median_annual_wage),
            job_growth_percentage = ISNULL(bls.job_growth_percentage, dim_occupation.job_growth_percentage),
            is_stem = CASE
                WHEN onet.is_stem = 1 THEN 1
                WHEN bls.is_stem = 1 THEN 1
                ELSE dim_occupation.is_stem
            END,
            is_high_demand = CASE
                WHEN bls.is_high_demand = 1 THEN 1
                WHEN onet.is_rapid_growth = 1 THEN 1
                ELSE dim_occupation.is_high_demand
            END,
            dw_updated_date = GETDATE()
        FROM dbo.dim_occupation
        LEFT JOIN SkillStack_Staging.stg.BLS_OccupationData bls
            ON dim_occupation.occupation_name = bls.occupation_title
            OR CHARINDEX(bls.occupation_title, dim_occupation.occupation_name) > 0
        LEFT JOIN SkillStack_Staging.stg.ONET_SOCCrosswalk onet
            ON bls.soc_code = onet.soc_code
            OR (onet.occupation_title = dim_occupation.occupation_name)
        WHERE dim_occupation.is_current = 1
            AND dim_occupation.occupation_key <> 0
            AND (bls.soc_code IS NOT NULL OR onet.onet_code IS NOT NULL);

        SET @RowsUpdated = @@ROWCOUNT;

        IF @DebugMode = 1
            PRINT 'Rows updated in dim_occupation: ' + CAST(@RowsUpdated AS VARCHAR(10));

        -- Log the operation
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Occupation External Data', 'sp_Populate_dim_occupation_external_data', 'Success', @RowsUpdated, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Populate_dim_occupation_external_data at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE();
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Occupation External Data', 'sp_Populate_dim_occupation_external_data', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Stored Procedure sp_Populate_dim_occupation_external_data Created Successfully';
PRINT '============================================================================';
GO
