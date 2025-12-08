-- ============================================================================
-- File: sql/18_load_dim_approval_set.sql
-- Purpose: Load dim_approval_set dimension from staging
-- Phase: Phase 4 - Classification & Workflow Dimensions
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Load_dim_approval_set', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_approval_set;
GO

CREATE PROCEDURE dbo.sp_Load_dim_approval_set
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @RowsInserted INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Load_dim_approval_set at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        MERGE dbo.dim_approval_set AS target
        USING (
            SELECT
                CAST(ApprovalSetId AS INT) AS approval_set_id,
                [Name] AS approval_set_name,
                [Description] AS approval_set_description,
                NULL AS approval_type,
                NULL AS required_approver_count,
                NULL AS approval_timeout_days,
                CAST(0 AS BIT) AS escalation_enabled,
                NULL AS notification_recipients_count,
                CAST(CASE WHEN DateDisabled IS NULL THEN 1 ELSE 0 END AS BIT) AS IsActive,
                ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY ApprovalSetId ORDER BY ModifiedDate DESC, ApprovalSetId) AS rn
                FROM SkillStack_Staging.stg.BDG_ApprovalSets
            ) stg
            WHERE rn = 1
        ) AS source
        ON target.approval_set_id = source.approval_set_id
           AND target.is_current = 1

        WHEN MATCHED AND (
            target.approval_set_name <> source.approval_set_name
            OR target.approval_set_description <> source.approval_set_description
            OR (target.approval_set_description IS NULL AND source.approval_set_description IS NOT NULL)
            OR (target.approval_set_description IS NOT NULL AND source.approval_set_description IS NULL)
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                approval_set_name = CASE WHEN source.IsActive = 1 THEN source.approval_set_name ELSE target.approval_set_name END,
                approval_set_description = CASE WHEN source.IsActive = 1 THEN source.approval_set_description ELSE target.approval_set_description END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.approval_set_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.approval_set_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                approval_set_id, approval_set_name, approval_set_description,
                approval_type, required_approver_count, approval_timeout_days,
                escalation_enabled, notification_recipients_count,
                is_active, is_current, effective_date, dw_created_date, dw_updated_date
            )
            VALUES (
                source.approval_set_id, source.approval_set_name, source.approval_set_description,
                source.approval_type, source.required_approver_count, source.approval_timeout_days,
                source.escalation_enabled, source.notification_recipients_count,
                source.IsActive, 1, GETDATE(), GETDATE(), GETDATE()
            );

        SET @RowsInserted = @@ROWCOUNT;

        IF @DebugMode = 1
            PRINT 'MERGE completed. Rows affected: ' + CAST(@RowsInserted AS VARCHAR(10));

        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Dimension Load', 'sp_Load_dim_approval_set', 'Success', @RowsInserted, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_approval_set at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE();
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Dimension Load', 'sp_Load_dim_approval_set', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'sp_Load_dim_approval_set Stored Procedure Created Successfully';
PRINT '============================================================================';
GO
