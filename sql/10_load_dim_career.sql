-- ============================================================================
-- File: sql/10_load_dim_career.sql
-- Purpose: Load dim_career dimension table from staging
-- Phase: Phase 3 - Labor Market Alignment
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
IF OBJECT_ID('dbo.sp_Load_dim_career', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_career;
GO

-- ============================================================================
-- CREATE PROCEDURE: sp_Load_dim_career
-- ============================================================================
CREATE PROCEDURE dbo.sp_Load_dim_career
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
            PRINT 'Starting sp_Load_dim_career at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- MERGE LOGIC: INSERT new, UPDATE changed, MARK DELETED
        -- ====================================================================
        MERGE dbo.dim_career AS target
        USING (
            SELECT
                CAST(stg.CareerId AS INT) AS career_id,
                stg.Guid AS career_guid,
                ISNULL(dcg.career_group_key, 0) AS career_group_key,
                stg.[Name] AS career_name,
                stg.[Description] AS career_description,
                dcg.career_group_name,
                NULL AS median_salary,
                NULL AS job_outlook_percentage,
                NULL AS typical_education_level,
                0 AS is_high_demand,
                NULL AS priority_ordering,
                stg.IsActive,
                stg.ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY CareerId ORDER BY ModifiedDate DESC, CareerId) AS rn
                FROM SkillStack_Staging.stg.CL_Careers
            ) stg
            -- Note: CL_Careers does not have direct career_group relationship in source
            -- Career groups may be applied through application logic or business rules
            -- For now, LEFT JOIN is placeholder for future enhancement
            LEFT JOIN dbo.dim_career_group dcg
                ON 0 = 1  -- No join condition available in current source
            WHERE rn = 1
        ) AS source
        ON target.career_id = source.career_id
           AND target.is_current = 1

        -- UPDATE: Career data changed or career marked inactive
        WHEN MATCHED AND (
            -- Detect attribute changes
            target.career_name <> source.career_name
            OR target.career_description <> source.career_description
            OR (target.career_description IS NULL AND source.career_description IS NOT NULL)
            OR (target.career_description IS NOT NULL AND source.career_description IS NULL)
            OR target.career_group_key <> source.career_group_key
            OR (target.career_group_key IS NULL AND source.career_group_key IS NOT NULL)
            OR (target.career_group_key IS NOT NULL AND source.career_group_key IS NULL)
            OR target.median_salary <> source.median_salary
            OR (target.median_salary IS NULL AND source.median_salary IS NOT NULL)
            OR (target.median_salary IS NOT NULL AND source.median_salary IS NULL)
            OR target.job_outlook_percentage <> source.job_outlook_percentage
            OR (target.job_outlook_percentage IS NULL AND source.job_outlook_percentage IS NOT NULL)
            OR (target.job_outlook_percentage IS NOT NULL AND source.job_outlook_percentage IS NULL)
            -- OR career marked inactive
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                career_name = CASE WHEN source.IsActive = 1 THEN source.career_name ELSE target.career_name END,
                career_description = CASE WHEN source.IsActive = 1 THEN source.career_description ELSE target.career_description END,
                career_group_key = CASE WHEN source.IsActive = 1 THEN source.career_group_key ELSE target.career_group_key END,
                career_group_name = CASE WHEN source.IsActive = 1 THEN source.career_group_name ELSE target.career_group_name END,
                median_salary = CASE WHEN source.IsActive = 1 THEN source.median_salary ELSE target.median_salary END,
                job_outlook_percentage = CASE WHEN source.IsActive = 1 THEN source.job_outlook_percentage ELSE target.job_outlook_percentage END,
                typical_education_level = CASE WHEN source.IsActive = 1 THEN source.typical_education_level ELSE target.typical_education_level END,
                is_high_demand = CASE WHEN source.IsActive = 1 THEN source.is_high_demand ELSE target.is_high_demand END,
                priority_ordering = CASE WHEN source.IsActive = 1 THEN source.priority_ordering ELSE target.priority_ordering END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.career_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.career_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        -- INSERT: New career from staging
        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                career_id,
                career_guid,
                career_group_key,
                career_name,
                career_description,
                career_group_name,
                median_salary,
                job_outlook_percentage,
                typical_education_level,
                is_high_demand,
                priority_ordering,
                is_active,
                is_current,
                effective_date,
                dw_created_date,
                dw_updated_date
            )
            VALUES (
                source.career_id,
                source.career_guid,
                source.career_group_key,
                source.career_name,
                source.career_description,
                source.career_group_name,
                source.median_salary,
                source.job_outlook_percentage,
                source.typical_education_level,
                source.is_high_demand,
                source.priority_ordering,
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
            'sp_Load_dim_career',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_career at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

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
            'sp_Load_dim_career',
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
PRINT 'sp_Load_dim_career Stored Procedure Created Successfully';
PRINT '============================================================================';
PRINT 'Procedure: dbo.sp_Load_dim_career';
PRINT 'Parameters: @DebugMode BIT (0=Production, 1=Debug output)';
PRINT '';
PRINT 'Functionality:';
PRINT '  - Deduplicates staging data (ROW_NUMBER by career_id, desc by ModifiedDate)';
PRINT '  - Joins with dim_career_group to get career_group_key (placeholder for future)';
PRINT '  - MERGE to handle INSERT/UPDATE/DELETE patterns';
PRINT '  - Detects attribute changes (name, description, labor market data)';
PRINT '  - Marks careers as inactive by setting is_current=0, expiration_date=GETDATE()';
PRINT '  - Logs all executions to dbo.job_execution_log';
PRINT '  - Full error handling with RAISERROR on failure';
PRINT '';
PRINT 'Dependencies:';
PRINT '  - Source: SkillStack_Staging.stg.CL_Careers (24 rows expected)';
PRINT '  - Target: SkillStack_DW.dbo.dim_career';
PRINT '  - Requires: dim_career_group to be populated first (for FK)';
PRINT '';
PRINT 'Note:';
PRINT '  - Labor market data (salary, outlook %) currently NULL (external data needed)';
PRINT '  - Career-to-CareerGroup mapping currently null (business logic required)';
PRINT '';
PRINT '============================================================================';
GO
