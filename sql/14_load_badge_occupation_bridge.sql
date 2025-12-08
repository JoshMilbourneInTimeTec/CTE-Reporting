-- ============================================================================
-- File: sql/14_load_badge_occupation_bridge.sql
-- Purpose: Load dim_badge_occupation_bridge relationships
-- Phase: Phase 3 - Labor Market Alignment
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Load_dim_badge_occupation_bridge', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_badge_occupation_bridge;
GO

CREATE PROCEDURE dbo.sp_Load_dim_badge_occupation_bridge
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Load_dim_badge_occupation_bridge at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        DELETE FROM dbo.dim_badge_occupation_bridge;

        WITH badge_occupation_alignment AS (
            SELECT
                db.badge_key,
                do_occ.occupation_key,
                CAST(1.0 AS NUMERIC(3,2)) as alignment_strength,
                ROW_NUMBER() OVER (PARTITION BY db.badge_key ORDER BY do_occ.occupation_key) as occ_rank
            FROM dbo.dim_badge db
            CROSS JOIN dbo.dim_occupation do_occ
            WHERE db.is_current = 1 AND db.badge_key <> 0
              AND do_occ.is_current = 1 AND do_occ.occupation_key <> 0
        )
        INSERT INTO dbo.dim_badge_occupation_bridge (
            badge_key, occupation_key, alignment_strength,
            is_primary_pathway, sequence_order, dw_created_date, dw_updated_date
        )
        SELECT
            badge_key, occupation_key, alignment_strength,
            CASE WHEN occ_rank = 1 THEN 1 ELSE 0 END,
            occ_rank, GETDATE(), GETDATE()
        FROM badge_occupation_alignment;

        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Bridge Table Load', 'sp_Load_dim_badge_occupation_bridge', 'Success', @@ROWCOUNT, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_badge_occupation_bridge at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE();
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Bridge Table Load', 'sp_Load_dim_badge_occupation_bridge', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT 'sp_Load_dim_badge_occupation_bridge created successfully';
GO
