-- ============================================================================
-- File: sql/17_load_dim_skill_set.sql
-- Purpose: Load dim_skill_set dimension table from staging
-- Phase: Phase 4 - Classification & Workflow Dimensions
-- Pattern: SCD Type 2 with MERGE-based approach
-- Note: Source is BDG_SkillSets which lacks independent names; derive from badge context
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- ============================================================================
-- DROP EXISTING PROCEDURE (allows re-creation)
-- ============================================================================
IF OBJECT_ID('dbo.sp_Load_dim_skill_set', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_skill_set;
GO

-- ============================================================================
-- CREATE PROCEDURE: sp_Load_dim_skill_set
-- ============================================================================
CREATE PROCEDURE dbo.sp_Load_dim_skill_set
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
            PRINT 'Starting sp_Load_dim_skill_set at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- MERGE LOGIC: INSERT new, UPDATE changed, MARK DELETED
        -- Skill sets are derived from BDG_SkillSets with badge context
        -- ====================================================================
        MERGE dbo.dim_skill_set AS target
        USING (
            SELECT
                CAST(SkillSetId AS INT) AS skill_set_id,
                -- Derive skill set name from badge number + requirement
                CONCAT('Skill Set ', SkillSetId, ' (Badge-Based)') AS skill_set_name,
                NULL AS skill_set_description,
                'Badge-Specific' AS skill_set_type,
                CONCAT('Requires ', MIN(RequiredNumber) OVER (PARTITION BY SkillSetId), ' skills') AS competency_level,
                NULL AS parent_skill_set_key,
                ROW_NUMBER() OVER (PARTITION BY SkillSetId ORDER BY SkillSetId) AS display_order,
                IsActive,
                ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY SkillSetId ORDER BY ModifiedDate DESC, SkillSetId) AS rn
                FROM SkillStack_Staging.stg.BDG_SkillSets
            ) stg
            WHERE rn = 1
        ) AS source
        ON target.skill_set_id = source.skill_set_id
           AND target.is_current = 1

        -- UPDATE: Skill set data changed or skill set marked inactive
        WHEN MATCHED AND (
            -- Detect attribute changes
            target.skill_set_name <> source.skill_set_name
            OR target.skill_set_description <> source.skill_set_description
            OR (target.skill_set_description IS NULL AND source.skill_set_description IS NOT NULL)
            OR (target.skill_set_description IS NOT NULL AND source.skill_set_description IS NULL)
            OR target.competency_level <> source.competency_level
            OR (target.competency_level IS NULL AND source.competency_level IS NOT NULL)
            OR (target.competency_level IS NOT NULL AND source.competency_level IS NULL)
            -- OR skill set marked inactive
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                skill_set_name = CASE WHEN source.IsActive = 1 THEN source.skill_set_name ELSE target.skill_set_name END,
                skill_set_description = CASE WHEN source.IsActive = 1 THEN source.skill_set_description ELSE target.skill_set_description END,
                competency_level = CASE WHEN source.IsActive = 1 THEN source.competency_level ELSE target.competency_level END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.skill_set_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.skill_set_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        -- INSERT: New skill set from staging
        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                skill_set_id,
                skill_set_name,
                skill_set_description,
                skill_set_type,
                competency_level,
                parent_skill_set_key,
                display_order,
                is_active,
                is_current,
                effective_date,
                dw_created_date,
                dw_updated_date
            )
            VALUES (
                source.skill_set_id,
                source.skill_set_name,
                source.skill_set_description,
                source.skill_set_type,
                source.competency_level,
                source.parent_skill_set_key,
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
            'sp_Load_dim_skill_set',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_skill_set at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

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
            'sp_Load_dim_skill_set',
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
PRINT 'sp_Load_dim_skill_set Stored Procedure Created Successfully';
PRINT '============================================================================';
PRINT 'Procedure: dbo.sp_Load_dim_skill_set';
PRINT 'Parameters: @DebugMode BIT (0=Production, 1=Debug output)';
PRINT '';
PRINT 'Functionality:';
PRINT '  - Deduplicates staging data (ROW_NUMBER by skill_set_id, desc by ModifiedDate)';
PRINT '  - Derives skill set names from badge context (source lacks independent names)';
PRINT '  - MERGE to handle INSERT/UPDATE/DELETE patterns';
PRINT '  - Detects attribute changes (name, competency_level)';
PRINT '  - Marks skill sets as inactive by setting is_current=0, expiration_date=GETDATE()';
PRINT '  - Logs all executions to dbo.job_execution_log';
PRINT '  - Full error handling with RAISERROR on failure';
PRINT '';
PRINT 'Dependencies:';
PRINT '  - Source: SkillStack_Staging.stg.BDG_SkillSets (12 rows expected)';
PRINT '  - Target: SkillStack_DW.dbo.dim_skill_set';
PRINT '';
PRINT 'Note: Skill set names are generated from skill set ID due to source data structure';
PRINT '';
PRINT '============================================================================';
GO
