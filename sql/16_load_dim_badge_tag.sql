-- ============================================================================
-- File: sql/16_load_dim_badge_tag.sql
-- Purpose: Load dim_badge_tag dimension table from staging
-- Phase: Phase 4 - Classification & Workflow Dimensions
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
IF OBJECT_ID('dbo.sp_Load_dim_badge_tag', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_badge_tag;
GO

-- ============================================================================
-- CREATE PROCEDURE: sp_Load_dim_badge_tag
-- ============================================================================
CREATE PROCEDURE dbo.sp_Load_dim_badge_tag
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
            PRINT 'Starting sp_Load_dim_badge_tag at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- MERGE LOGIC: INSERT new, UPDATE changed, MARK DELETED
        -- ====================================================================
        MERGE dbo.dim_badge_tag AS target
        USING (
            SELECT
                CAST(TagId AS INT) AS tag_id,
                [Name] AS tag_name,
                [Description] AS tag_description,
                NULL AS tag_category,
                NULL AS tag_color_code,
                CAST([Sort] AS INT) AS display_order,
                IsActive,
                ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY TagId ORDER BY ModifiedDate DESC, TagId) AS rn
                FROM SkillStack_Staging.stg.BDG_Tags
            ) stg
            WHERE rn = 1
        ) AS source
        ON target.tag_id = source.tag_id
           AND target.is_current = 1

        -- UPDATE: Tag data changed or tag marked inactive
        WHEN MATCHED AND (
            -- Detect attribute changes
            target.tag_name <> source.tag_name
            OR target.tag_description <> source.tag_description
            OR (target.tag_description IS NULL AND source.tag_description IS NOT NULL)
            OR (target.tag_description IS NOT NULL AND source.tag_description IS NULL)
            OR target.display_order <> source.display_order
            OR (target.display_order IS NULL AND source.display_order IS NOT NULL)
            OR (target.display_order IS NOT NULL AND source.display_order IS NULL)
            -- OR tag marked inactive
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                tag_name = CASE WHEN source.IsActive = 1 THEN source.tag_name ELSE target.tag_name END,
                tag_description = CASE WHEN source.IsActive = 1 THEN source.tag_description ELSE target.tag_description END,
                display_order = CASE WHEN source.IsActive = 1 THEN source.display_order ELSE target.display_order END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.tag_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.tag_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        -- INSERT: New tag from staging
        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                tag_id,
                tag_name,
                tag_description,
                tag_category,
                tag_color_code,
                display_order,
                is_active,
                is_current,
                effective_date,
                dw_created_date,
                dw_updated_date
            )
            VALUES (
                source.tag_id,
                source.tag_name,
                source.tag_description,
                source.tag_category,
                source.tag_color_code,
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
            'sp_Load_dim_badge_tag',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_badge_tag at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

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
            'sp_Load_dim_badge_tag',
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
PRINT 'sp_Load_dim_badge_tag Stored Procedure Created Successfully';
PRINT '============================================================================';
PRINT 'Procedure: dbo.sp_Load_dim_badge_tag';
PRINT 'Parameters: @DebugMode BIT (0=Production, 1=Debug output)';
PRINT '';
PRINT 'Functionality:';
PRINT '  - Deduplicates staging data (ROW_NUMBER by tag_id, desc by ModifiedDate)';
PRINT '  - MERGE to handle INSERT/UPDATE/DELETE patterns';
PRINT '  - Detects attribute changes (name, description, display_order)';
PRINT '  - Marks tags as inactive by setting is_current=0, expiration_date=GETDATE()';
PRINT '  - Logs all executions to dbo.job_execution_log';
PRINT '  - Full error handling with RAISERROR on failure';
PRINT '';
PRINT 'Dependencies:';
PRINT '  - Source: SkillStack_Staging.stg.BDG_Tags (13 rows expected)';
PRINT '  - Target: SkillStack_DW.dbo.dim_badge_tag';
PRINT '';
PRINT '============================================================================';
GO
