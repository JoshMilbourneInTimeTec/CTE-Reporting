-- ============================================================================
-- File: sql/07_load_dim_institution.sql
-- Purpose: Load dim_institution dimension table from staging
-- Pattern: SCD Type 2 with MERGE-based approach
-- Handles: INSERT new records, UPDATE changed records, MARK DELETED records
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- ============================================================================
-- DROP EXISTING PROCEDURE (allows re-creation)
-- ============================================================================
IF OBJECT_ID('dbo.sp_Load_dim_institution', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_institution;
GO

-- ============================================================================
-- CREATE PROCEDURE: sp_Load_dim_institution
-- ============================================================================
CREATE PROCEDURE dbo.sp_Load_dim_institution
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @RowsInserted INT = 0;
    DECLARE @RowsUpdated INT = 0;
    DECLARE @RowsMarkedDeleted INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Load_dim_institution at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- MERGE LOGIC: INSERT new, UPDATE changed, MARK DELETED
        -- ====================================================================
        MERGE dbo.dim_institution AS target
        USING (
            SELECT
                CAST(InstitutionId AS INT) AS institution_id,
                [Name] AS institution_name,
                NULL AS institution_type,
                Abbreviation AS institution_code,
                NULL AS address_line1,
                NULL AS address_line2,
                NULL AS city,
                NULL AS state,
                NULL AS zip_code,
                NULL AS phone,
                NULL AS email,
                SiteURL AS website_url,
                NULL AS region_name,
                NULL AS region_number,
                NULL AS ipeds_id,
                NULL AS ope_id,
                NULL AS accreditation_status,
                IsActive,
                ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY InstitutionId ORDER BY ModifiedDate DESC, InstitutionId) AS rn
                FROM SkillStack_Staging.stg.INST_Institutions
            ) stg
            WHERE rn = 1
        ) AS source
        ON target.institution_id = source.institution_id
           AND target.is_current = 1

        -- UPDATE: Institution data changed or institution marked inactive
        WHEN MATCHED AND (
            -- Detect attribute changes
            target.institution_name <> source.institution_name
            OR target.institution_code <> source.institution_code
            OR (target.institution_code IS NULL AND source.institution_code IS NOT NULL)
            OR (target.institution_code IS NOT NULL AND source.institution_code IS NULL)
            OR target.website_url <> source.website_url
            OR (target.website_url IS NULL AND source.website_url IS NOT NULL)
            OR (target.website_url IS NOT NULL AND source.website_url IS NULL)
            OR target.region_name <> source.region_name
            OR (target.region_name IS NULL AND source.region_name IS NOT NULL)
            OR (target.region_name IS NOT NULL AND source.region_name IS NULL)
            -- OR institution marked inactive
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                institution_name = CASE WHEN source.IsActive = 1 THEN source.institution_name ELSE target.institution_name END,
                institution_code = CASE WHEN source.IsActive = 1 THEN source.institution_code ELSE target.institution_code END,
                website_url = CASE WHEN source.IsActive = 1 THEN source.website_url ELSE target.website_url END,
                region_name = CASE WHEN source.IsActive = 1 THEN source.region_name ELSE target.region_name END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.institution_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.institution_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        -- INSERT: New institution from staging
        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                institution_id,
                institution_name,
                institution_type,
                institution_code,
                address_line1,
                address_line2,
                city,
                state,
                zip_code,
                phone,
                email,
                website_url,
                region_name,
                region_number,
                ipeds_id,
                ope_id,
                accreditation_status,
                is_active,
                is_current,
                effective_date,
                dw_created_date,
                dw_updated_date
            )
            VALUES (
                source.institution_id,
                source.institution_name,
                source.institution_type,
                source.institution_code,
                source.address_line1,
                source.address_line2,
                source.city,
                source.state,
                source.zip_code,
                source.phone,
                source.email,
                source.website_url,
                source.region_name,
                source.region_number,
                source.ipeds_id,
                source.ope_id,
                source.accreditation_status,
                source.IsActive,
                1,
                GETDATE(),
                GETDATE(),
                GETDATE()
            );

        SET @RowsInserted = @@ROWCOUNT;

        IF @DebugMode = 1
            PRINT 'MERGE completed. Rows affected: ' + CAST(@RowsInserted AS VARCHAR(10));

        -- ====================================================================
        -- LOG TO JOB EXECUTION LOG
        -- ====================================================================
        INSERT INTO dbo.job_execution_log (
            job_name,
            step_name,
            status,
            rows_affected,
            execution_start_time,
            execution_end_time,
            error_message
        )
        VALUES (
            'Dimension Load',
            'sp_Load_dim_institution',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_institution at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        -- Log error
        INSERT INTO dbo.job_execution_log (
            job_name,
            step_name,
            status,
            rows_affected,
            execution_start_time,
            execution_end_time,
            error_message
        )
        VALUES (
            'Dimension Load',
            'sp_Load_dim_institution',
            'Failed',
            0,
            @StartTime,
            GETDATE(),
            @ErrorMessage
        );

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'sp_Load_dim_institution Stored Procedure Created Successfully';
PRINT '============================================================================';
PRINT 'Procedure: dbo.sp_Load_dim_institution';
PRINT 'Parameters: @DebugMode BIT (0=Production, 1=Debug output)';
PRINT '';
PRINT 'Functionality:';
PRINT '  - Deduplicates staging data (ROW_NUMBER by institution_id, desc by ModifiedDate)';
PRINT '  - Joins with INST_InstitutionRegions for regional mapping';
PRINT '  - MERGE to handle INSERT/UPDATE/DELETE patterns';
PRINT '  - Detects attribute changes (institution_name, code, website, region)';
PRINT '  - Marks institutions as inactive by setting is_current=0, expiration_date=GETDATE()';
PRINT '  - Logs all executions to dbo.job_execution_log';
PRINT '  - Full error handling with RAISERROR on failure';
PRINT '';
PRINT 'Source Tables:';
PRINT '  - SkillStack_Staging.stg.INST_Institutions (12 rows)';
PRINT '  - SkillStack_Staging.stg.INST_InstitutionRegions (15 rows)';
PRINT '';
PRINT '============================================================================';
GO
