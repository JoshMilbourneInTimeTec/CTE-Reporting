-- ============================================================================
-- File: sql/11_load_dim_occupation.sql
-- Purpose: Load dim_occupation dimension table from staging
-- Phase: Phase 3 - Labor Market Alignment
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Load_dim_occupation', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_occupation;
GO

CREATE PROCEDURE dbo.sp_Load_dim_occupation
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
            PRINT 'Starting sp_Load_dim_occupation at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        MERGE dbo.dim_occupation AS target
        USING (
            SELECT
                CAST(OccupationId AS INT) AS occupation_id,
                NULL AS soc_code,
                NULL AS onet_code,
                [Name] AS occupation_name,
                [Description] AS occupation_description,
                NULL AS education_required,
                NULL AS training_required,
                NULL AS median_annual_wage,
                NULL AS job_growth_percentage,
                NULL AS typical_work_hours_per_week,
                0 AS is_high_demand,
                0 AS is_stem,
                IsActive,
                ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY OccupationId ORDER BY ModifiedDate DESC, OccupationId) AS rn
                FROM SkillStack_Staging.stg.CL_Occupations
            ) stg
            WHERE rn = 1
        ) AS source
        ON target.occupation_id = source.occupation_id AND target.is_current = 1

        WHEN MATCHED AND (
            target.occupation_name <> source.occupation_name
            OR target.occupation_description <> source.occupation_description
            OR (target.occupation_description IS NULL AND source.occupation_description IS NOT NULL)
            OR (target.occupation_description IS NOT NULL AND source.occupation_description IS NULL)
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                occupation_name = CASE WHEN source.IsActive = 1 THEN source.occupation_name ELSE target.occupation_name END,
                occupation_description = CASE WHEN source.IsActive = 1 THEN source.occupation_description ELSE target.occupation_description END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.occupation_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.occupation_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (occupation_id, soc_code, onet_code, occupation_name, occupation_description, education_required,
                    training_required, median_annual_wage, job_growth_percentage, typical_work_hours_per_week,
                    is_high_demand, is_stem, is_active, is_current, effective_date, dw_created_date, dw_updated_date)
            VALUES (source.occupation_id, source.soc_code, source.onet_code, source.occupation_name,
                    source.occupation_description, source.education_required, source.training_required,
                    source.median_annual_wage, source.job_growth_percentage, source.typical_work_hours_per_week,
                    source.is_high_demand, source.is_stem, source.IsActive, 1, GETDATE(), GETDATE(), GETDATE());

        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Dimension Load', 'sp_Load_dim_occupation', 'Success', @@ROWCOUNT, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_occupation at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Dimension Load', 'sp_Load_dim_occupation', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END;
GO

PRINT 'sp_Load_dim_occupation created successfully';
GO
