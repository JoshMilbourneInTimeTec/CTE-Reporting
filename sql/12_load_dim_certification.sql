-- ============================================================================
-- File: sql/12_load_dim_certification.sql
-- Purpose: Load dim_certification dimension table from staging
-- Phase: Phase 3 - Labor Market Alignment
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Load_dim_certification', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_certification;
GO

CREATE PROCEDURE dbo.sp_Load_dim_certification
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @ErrorMessage NVARCHAR(4000);
    DECLARE @ErrorSeverity INT;
    DECLARE @ErrorState INT;

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Load_dim_certification at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        MERGE dbo.dim_certification AS target
        USING (
            SELECT
                CAST(CertificationId AS INT) AS certification_id,
                [Text] AS certification_name,
                NULL AS certification_description,
                NULL AS issuing_organization,
                NULL AS certification_code,
                NULL AS renewal_period_months,
                NULL AS cost_usd,
                NULL AS typical_preparation_hours,
                1 AS is_industry_recognized,
                0 AS is_stackable,
                CAST(Priority AS INT) AS priority_level,
                IsActive,
                ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY CertificationId ORDER BY ModifiedDate DESC, CertificationId) AS rn
                FROM SkillStack_Staging.stg.CL_Certifications
            ) stg
            WHERE rn = 1
        ) AS source
        ON target.certification_id = source.certification_id AND target.is_current = 1

        WHEN MATCHED AND (
            target.certification_name <> source.certification_name
            OR target.priority_level <> source.priority_level
            OR (target.priority_level IS NULL AND source.priority_level IS NOT NULL)
            OR (target.priority_level IS NOT NULL AND source.priority_level IS NULL)
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                certification_name = CASE WHEN source.IsActive = 1 THEN source.certification_name ELSE target.certification_name END,
                priority_level = CASE WHEN source.IsActive = 1 THEN source.priority_level ELSE target.priority_level END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.certification_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.certification_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (certification_id, certification_name, certification_description, issuing_organization, certification_code,
                    renewal_period_months, cost_usd, typical_preparation_hours, is_industry_recognized, is_stackable,
                    priority_level, is_active, is_current, effective_date, dw_created_date, dw_updated_date)
            VALUES (source.certification_id, source.certification_name, source.certification_description,
                    source.issuing_organization, source.certification_code, source.renewal_period_months,
                    source.cost_usd, source.typical_preparation_hours, source.is_industry_recognized,
                    source.is_stackable, source.priority_level, source.IsActive, 1, GETDATE(), GETDATE(), GETDATE());

        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Dimension Load', 'sp_Load_dim_certification', 'Success', @@ROWCOUNT, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_certification at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Dimension Load', 'sp_Load_dim_certification', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

PRINT 'sp_Load_dim_certification created successfully';
GO
