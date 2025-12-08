-- ============================================================================
-- File: sql/19_load_badge_tag_bridge.sql
-- Purpose: Load dim_badge_tag_bridge relationships
-- Phase: Phase 4 - Classification & Workflow Dimensions
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Load_dim_badge_tag_bridge', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_badge_tag_bridge;
GO

CREATE PROCEDURE dbo.sp_Load_dim_badge_tag_bridge
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @RowsInserted INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Load_dim_badge_tag_bridge at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        DELETE FROM dbo.dim_badge_tag_bridge;

        WITH badge_tag_alignment AS (
            SELECT
                db.badge_key,
                dt.tag_key,
                CAST(IsActive AS BIT) as is_active,
                ROW_NUMBER() OVER (PARTITION BY db.badge_key ORDER BY dt.tag_key) as tag_rank
            FROM dbo.dim_badge db
            INNER JOIN SkillStack_Staging.stg.BDG_BadgeTags bbt
                ON db.badge_id = bbt.BadgeId
            INNER JOIN dbo.dim_badge_tag dt
                ON bbt.TagId = dt.tag_id AND dt.is_current = 1
            WHERE db.is_current = 1 AND db.badge_key <> 0
        )
        INSERT INTO dbo.dim_badge_tag_bridge (
            badge_key, tag_key, is_active, sequence_order, dw_created_date, dw_updated_date
        )
        SELECT
            badge_key, tag_key, is_active, tag_rank, GETDATE(), GETDATE()
        FROM badge_tag_alignment;

        SET @RowsInserted = @@ROWCOUNT;

        IF @DebugMode = 1
            PRINT 'Rows inserted: ' + CAST(@RowsInserted AS VARCHAR(10));

        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Bridge Table Load', 'sp_Load_dim_badge_tag_bridge', 'Success', @RowsInserted, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_badge_tag_bridge at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE();
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Bridge Table Load', 'sp_Load_dim_badge_tag_bridge', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'sp_Load_dim_badge_tag_bridge Stored Procedure Created Successfully';
PRINT '============================================================================';
GO
