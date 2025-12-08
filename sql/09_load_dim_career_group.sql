-- ============================================================================
-- File: sql/09_load_dim_career_group.sql
-- Purpose: Load dim_career_group dimension table from staging
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
IF OBJECT_ID('dbo.sp_Load_dim_career_group', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_career_group;
GO

-- ============================================================================
-- CREATE PROCEDURE: sp_Load_dim_career_group
-- ============================================================================
CREATE PROCEDURE dbo.sp_Load_dim_career_group
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
            PRINT 'Starting sp_Load_dim_career_group at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- MERGE LOGIC: INSERT new, UPDATE changed, MARK DELETED
        -- ====================================================================
        MERGE dbo.dim_career_group AS target
        USING (
            SELECT
                CAST(CareerGroupId AS INT) AS career_group_id,
                [Name] AS career_group_name,
                [Description] AS career_group_description,
                NULL AS display_order,
                IsActive,
                ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY CareerGroupId ORDER BY ModifiedDate DESC, CareerGroupId) AS rn
                FROM SkillStack_Staging.stg.CL_CareerGroups
            ) stg
            WHERE rn = 1
        ) AS source
        ON target.career_group_id = source.career_group_id
           AND target.is_current = 1

        -- UPDATE: Career group data changed or career group marked inactive
        WHEN MATCHED AND (
            -- Detect attribute changes
            target.career_group_name <> source.career_group_name
            OR target.career_group_description <> source.career_group_description
            OR (target.career_group_description IS NULL AND source.career_group_description IS NOT NULL)
            OR (target.career_group_description IS NOT NULL AND source.career_group_description IS NULL)
            OR target.display_order <> source.display_order
            OR (target.display_order IS NULL AND source.display_order IS NOT NULL)
            OR (target.display_order IS NOT NULL AND source.display_order IS NULL)
            -- OR career group marked inactive
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                career_group_name = CASE WHEN source.IsActive = 1 THEN source.career_group_name ELSE target.career_group_name END,
                career_group_description = CASE WHEN source.IsActive = 1 THEN source.career_group_description ELSE target.career_group_description END,
                display_order = CASE WHEN source.IsActive = 1 THEN source.display_order ELSE target.display_order END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.career_group_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.career_group_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        -- INSERT: New career group from staging
        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                career_group_id,
                career_group_name,
                career_group_description,
                display_order,
                is_active,
                is_current,
                effective_date,
                dw_created_date,
                dw_updated_date
            )
            VALUES (
                source.career_group_id,
                source.career_group_name,
                source.career_group_description,
                source.display_order,
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
            'sp_Load_dim_career_group',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_career_group at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

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
            'sp_Load_dim_career_group',
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
PRINT 'sp_Load_dim_career_group Stored Procedure Created Successfully';
PRINT '============================================================================';
PRINT 'Procedure: dbo.sp_Load_dim_career_group';
PRINT 'Parameters: @DebugMode BIT (0=Production, 1=Debug output)';
PRINT '';
PRINT 'Functionality:';
PRINT '  - Deduplicates staging data (ROW_NUMBER by career_group_id, desc by ModifiedDate)';
PRINT '  - MERGE to handle INSERT/UPDATE/DELETE patterns';
PRINT '  - Detects attribute changes (name, description)';
PRINT '  - Marks career groups as inactive by setting is_current=0, expiration_date=GETDATE()';
PRINT '  - Logs all executions to dbo.job_execution_log';
PRINT '  - Full error handling with RAISERROR on failure';
PRINT '';
PRINT 'Dependencies:';
PRINT '  - Source: SkillStack_Staging.stg.CL_CareerGroups (18 rows expected)';
PRINT '  - Target: SkillStack_DW.dbo.dim_career_group';
PRINT '';
PRINT '============================================================================';
GO
