-- ============================================================================
-- File: sql/13_load_badge_career_bridge.sql
-- Purpose: Load dim_badge_career_bridge from badge-career relationships
-- Phase: Phase 3 - Labor Market Alignment
-- Pattern: Calculate alignment strength and populate relationships
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Load_dim_badge_career_bridge', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_badge_career_bridge;
GO

CREATE PROCEDURE dbo.sp_Load_dim_badge_career_bridge
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @RowsInserted INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Load_dim_badge_career_bridge at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- DELETE existing records (bridge table rebuild on each load)
        -- ====================================================================
        DELETE FROM dbo.dim_badge_career_bridge;

        -- ====================================================================
        -- INSERT: Badge-Career relationships with alignment scoring
        -- ====================================================================
        -- Strategy: Link badges through skills to occupations to careers
        -- Alignment Strength = combined skill coverage and keyword match
        -- Primary Pathway = strongest relationship per badge
        -- ====================================================================

        WITH badge_skill_mapping AS (
            -- Get all skills for each current badge
            SELECT
                db.badge_key,
                db.badge_id,
                COUNT(DISTINCT dsk.skill_key) as skill_count
            FROM dbo.dim_badge db
            LEFT JOIN dbo.dim_skill dsk ON db.badge_key = dsk.badge_key
                AND dsk.is_current = 1
                AND dsk.skill_key <> 0
            WHERE db.is_current = 1 AND db.badge_key <> 0
            GROUP BY db.badge_key, db.badge_id
        ),
        badge_career_alignment AS (
            -- Calculate alignment strength for each badge-career pair
            -- For now: use simple scoring (1.0 if skills exist, 0.0 otherwise)
            -- Future: enhance with keyword matching and skill gap analysis
            SELECT
                bsm.badge_key,
                dc.career_key,
                dc.career_id,
                CASE
                    WHEN bsm.skill_count > 0 THEN CAST(1.0 AS NUMERIC(3,2))
                    ELSE CAST(0.0 AS NUMERIC(3,2))
                END as alignment_strength,
                ROW_NUMBER() OVER (PARTITION BY bsm.badge_key ORDER BY bsm.skill_count DESC, dc.career_key) as career_rank
            FROM badge_skill_mapping bsm
            CROSS JOIN dbo.dim_career dc
            WHERE dc.is_current = 1 AND dc.career_key <> 0
        )
        INSERT INTO dbo.dim_badge_career_bridge (
            badge_key,
            career_key,
            alignment_strength,
            is_primary_pathway,
            sequence_order,
            dw_created_date,
            dw_updated_date
        )
        SELECT
            bca.badge_key,
            bca.career_key,
            bca.alignment_strength,
            CASE WHEN bca.career_rank = 1 AND bca.alignment_strength > 0 THEN 1 ELSE 0 END as is_primary_pathway,
            bca.career_rank as sequence_order,
            GETDATE(),
            GETDATE()
        FROM badge_career_alignment bca
        WHERE bca.alignment_strength > 0;  -- Only insert non-zero alignments

        SET @RowsInserted = @@ROWCOUNT;

        IF @DebugMode = 1
            PRINT 'Inserted ' + CAST(@RowsInserted AS VARCHAR(10)) + ' badge-career relationships';

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
            'Bridge Table Load',
            'sp_Load_dim_badge_career_bridge',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_badge_career_bridge at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

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
            'Bridge Table Load',
            'sp_Load_dim_badge_career_bridge',
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

PRINT '';
PRINT 'sp_Load_dim_badge_career_bridge created successfully';
PRINT 'Procedure links badges to careers with alignment strength scoring';
PRINT '';
GO
