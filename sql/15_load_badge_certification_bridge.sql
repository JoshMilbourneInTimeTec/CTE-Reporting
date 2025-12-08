-- ============================================================================
-- File: sql/15_load_badge_certification_bridge.sql
-- Purpose: Load dim_badge_certification_bridge relationships
-- Phase: Phase 3 - Labor Market Alignment
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Load_dim_badge_certification_bridge', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_badge_certification_bridge;
GO

CREATE PROCEDURE dbo.sp_Load_dim_badge_certification_bridge
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Load_dim_badge_certification_bridge at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        DELETE FROM dbo.dim_badge_certification_bridge;

        WITH badge_certification_alignment AS (
            SELECT
                db.badge_key,
                dc_cert.certification_key,
                NULL as certification_covers_percentage,
                0 as is_prerequisite,
                1 as is_recommended,
                ROW_NUMBER() OVER (PARTITION BY db.badge_key ORDER BY dc_cert.certification_key) as cert_rank
            FROM dbo.dim_badge db
            CROSS JOIN dbo.dim_certification dc_cert
            WHERE db.is_current = 1 AND db.badge_key <> 0
              AND dc_cert.is_current = 1 AND dc_cert.certification_key <> 0
        )
        INSERT INTO dbo.dim_badge_certification_bridge (
            badge_key, certification_key, certification_covers_percentage,
            is_prerequisite, is_recommended, sequence_order, dw_created_date, dw_updated_date
        )
        SELECT
            badge_key, certification_key, certification_covers_percentage,
            is_prerequisite, is_recommended, cert_rank, GETDATE(), GETDATE()
        FROM badge_certification_alignment;

        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Bridge Table Load', 'sp_Load_dim_badge_certification_bridge', 'Success', @@ROWCOUNT, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_badge_certification_bridge at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE();
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Bridge Table Load', 'sp_Load_dim_badge_certification_bridge', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT 'sp_Load_dim_badge_certification_bridge created successfully';
GO
