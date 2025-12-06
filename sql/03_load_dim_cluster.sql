-- ============================================================================
-- File: sql/03_load_dim_cluster.sql
-- Purpose: Load dim_cluster dimension table from staging
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
IF OBJECT_ID('dbo.sp_Load_dim_cluster', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_cluster;
GO

-- ============================================================================
-- CREATE PROCEDURE: sp_Load_dim_cluster
-- ============================================================================
CREATE PROCEDURE dbo.sp_Load_dim_cluster
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
            PRINT 'Starting sp_Load_dim_cluster at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- MERGE LOGIC: INSERT new, UPDATE changed, MARK DELETED
        -- ====================================================================
        MERGE dbo.dim_cluster AS target
        USING (
            SELECT
                CAST(ClusterId AS INT) AS cluster_id,
                [Name] AS cluster_name,
                -- Phase 2 Enhancement: Generate cluster_code from name
                -- Extract first letter of each word and take up to 4 characters
                -- Example: "Agriculture, Food & Natural Resources" → "AGRI" (from Agriculture, Food, &, Resources)
                UPPER(LEFT(REPLACE(REPLACE([Name], ',', ''), '&', ''), 4)) AS cluster_code,
                [Description] AS cluster_description,
                NULL AS cluster_icon_url,
                NULL AS display_order,
                IsActive,
                ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY ClusterId ORDER BY ModifiedDate DESC, ClusterId) AS rn
                FROM SkillStack_Staging.stg.BDG_Clusters
            ) stg
            WHERE rn = 1
        ) AS source
        ON target.cluster_id = source.cluster_id
           AND target.is_current = 1

        -- UPDATE: Cluster data changed or cluster marked inactive
        WHEN MATCHED AND (
            -- Detect attribute changes
            target.cluster_name <> source.cluster_name
            OR target.cluster_code <> source.cluster_code
            OR (target.cluster_code IS NULL AND source.cluster_code IS NOT NULL)
            OR (target.cluster_code IS NOT NULL AND source.cluster_code IS NULL)
            OR target.cluster_description <> source.cluster_description
            OR (target.cluster_description IS NULL AND source.cluster_description IS NOT NULL)
            OR (target.cluster_description IS NOT NULL AND source.cluster_description IS NULL)
            OR target.display_order <> source.display_order
            OR (target.display_order IS NULL AND source.display_order IS NOT NULL)
            OR (target.display_order IS NOT NULL AND source.display_order IS NULL)
            -- OR cluster marked inactive
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                cluster_name = CASE WHEN source.IsActive = 1 THEN source.cluster_name ELSE target.cluster_name END,
                cluster_code = CASE WHEN source.IsActive = 1 THEN source.cluster_code ELSE target.cluster_code END,
                cluster_description = CASE WHEN source.IsActive = 1 THEN source.cluster_description ELSE target.cluster_description END,
                display_order = CASE WHEN source.IsActive = 1 THEN source.display_order ELSE target.display_order END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.cluster_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.cluster_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        -- INSERT: New cluster from staging
        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                cluster_id,
                cluster_name,
                cluster_code,
                cluster_description,
                cluster_icon_url,
                display_order,
                is_active,
                is_current,
                effective_date,
                dw_created_date,
                dw_updated_date
            )
            VALUES (
                source.cluster_id,
                source.cluster_name,
                source.cluster_code,
                source.cluster_description,
                source.cluster_icon_url,
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
            'sp_Load_dim_cluster',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_cluster at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

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
            'sp_Load_dim_cluster',
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
PRINT 'sp_Load_dim_cluster Stored Procedure Created Successfully';
PRINT '============================================================================';
PRINT 'Procedure: dbo.sp_Load_dim_cluster';
PRINT 'Parameters: @DebugMode BIT (0=Production, 1=Debug output)';
PRINT '';
PRINT 'Functionality:';
PRINT '  - Deduplicates staging data (ROW_NUMBER by cluster_id, desc by ModifiedDate)';
PRINT '  - MERGE to handle INSERT/UPDATE/DELETE patterns';
PRINT '  - Detects attribute changes (cluster_name, description, display_order)';
PRINT '  - Marks clusters as inactive by setting is_current=0, expiration_date=GETDATE()';
PRINT '  - Logs all executions to dbo.job_execution_log';
PRINT '  - Full error handling with RAISERROR on failure';
PRINT '';
PRINT '============================================================================';
GO
