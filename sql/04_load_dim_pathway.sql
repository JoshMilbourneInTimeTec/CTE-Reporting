-- ============================================================================
-- File: sql/04_load_dim_pathway.sql
-- Purpose: Load dim_pathway dimension table from staging
-- Pattern: SCD Type 2 with MERGE-based approach
-- Handles: INSERT new records, UPDATE changed records, MARK DELETED records
-- Dependencies: dim_cluster must be populated first
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- ============================================================================
-- DROP EXISTING PROCEDURE (allows re-creation)
-- ============================================================================
IF OBJECT_ID('dbo.sp_Load_dim_pathway', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_pathway;
GO

-- ============================================================================
-- CREATE PROCEDURE: sp_Load_dim_pathway
-- ============================================================================
CREATE PROCEDURE dbo.sp_Load_dim_pathway
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
            PRINT 'Starting sp_Load_dim_pathway at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- MERGE LOGIC: INSERT new, UPDATE changed, MARK DELETED
        -- ====================================================================
        MERGE dbo.dim_pathway AS target
        USING (
            SELECT
                CAST(stg.PathwayId AS INT) AS pathway_id,
                ISNULL(dc.cluster_key, 0) AS cluster_key,
                stg.[Name] AS pathway_name,
                -- Phase 2 Enhancement: Generate pathway_code from name
                -- Extract first 4 characters of pathway name
                -- Example: "Food Products & Processing Systems" → "FOOD"
                UPPER(LEFT(REPLACE(REPLACE(stg.[Name], '&', ''), ' ', ''), 4)) AS pathway_code,
                stg.[Description] AS pathway_description,
                stg.ImageURL AS pathway_icon_url,
                NULL AS display_order,
                NULL AS cip_code,
                stg.IsActive,
                stg.ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY PathwayId ORDER BY ModifiedDate DESC, PathwayId) AS rn
                FROM SkillStack_Staging.stg.BDG_Pathways
            ) stg
            LEFT JOIN dbo.dim_cluster dc
                ON CAST(stg.ClusterId AS INT) = dc.cluster_id
                AND dc.is_current = 1
            WHERE rn = 1
        ) AS source
        ON target.pathway_id = source.pathway_id
           AND target.is_current = 1

        -- UPDATE: Pathway data changed or pathway marked inactive
        WHEN MATCHED AND (
            -- Detect attribute changes
            target.pathway_name <> source.pathway_name
            OR target.pathway_code <> source.pathway_code
            OR (target.pathway_code IS NULL AND source.pathway_code IS NOT NULL)
            OR (target.pathway_code IS NOT NULL AND source.pathway_code IS NULL)
            OR target.pathway_description <> source.pathway_description
            OR (target.pathway_description IS NULL AND source.pathway_description IS NOT NULL)
            OR (target.pathway_description IS NOT NULL AND source.pathway_description IS NULL)
            OR target.pathway_icon_url <> source.pathway_icon_url
            OR (target.pathway_icon_url IS NULL AND source.pathway_icon_url IS NOT NULL)
            OR (target.pathway_icon_url IS NOT NULL AND source.pathway_icon_url IS NULL)
            OR target.display_order <> source.display_order
            OR (target.display_order IS NULL AND source.display_order IS NOT NULL)
            OR (target.display_order IS NOT NULL AND source.display_order IS NULL)
            OR target.cluster_key <> source.cluster_key
            -- OR pathway marked inactive
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                cluster_key = CASE WHEN source.IsActive = 1 THEN source.cluster_key ELSE target.cluster_key END,
                pathway_name = CASE WHEN source.IsActive = 1 THEN source.pathway_name ELSE target.pathway_name END,
                pathway_code = CASE WHEN source.IsActive = 1 THEN source.pathway_code ELSE target.pathway_code END,
                pathway_description = CASE WHEN source.IsActive = 1 THEN source.pathway_description ELSE target.pathway_description END,
                pathway_icon_url = CASE WHEN source.IsActive = 1 THEN source.pathway_icon_url ELSE target.pathway_icon_url END,
                display_order = CASE WHEN source.IsActive = 1 THEN source.display_order ELSE target.display_order END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.pathway_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.pathway_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        -- INSERT: New pathway from staging
        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                pathway_id,
                cluster_key,
                pathway_name,
                pathway_code,
                pathway_description,
                pathway_icon_url,
                display_order,
                cip_code,
                is_active,
                is_current,
                effective_date,
                dw_created_date,
                dw_updated_date
            )
            VALUES (
                source.pathway_id,
                source.cluster_key,
                source.pathway_name,
                source.pathway_code,
                source.pathway_description,
                source.pathway_icon_url,
                source.display_order,
                source.cip_code,
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
            'sp_Load_dim_pathway',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_pathway at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

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
            'sp_Load_dim_pathway',
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
PRINT 'sp_Load_dim_pathway Stored Procedure Created Successfully';
PRINT '============================================================================';
PRINT 'Procedure: dbo.sp_Load_dim_pathway';
PRINT 'Parameters: @DebugMode BIT (0=Production, 1=Debug output)';
PRINT '';
PRINT 'Functionality:';
PRINT '  - Deduplicates staging data (ROW_NUMBER by pathway_id, desc by ModifiedDate)';
PRINT '  - Joins with dim_cluster to get cluster_key (currently all map to Unknown)';
PRINT '  - MERGE to handle INSERT/UPDATE/DELETE patterns';
PRINT '  - Detects attribute changes (pathway_name, description, display_order)';
PRINT '  - Marks pathways as inactive by setting is_current=0, expiration_date=GETDATE()';
PRINT '  - Logs all executions to dbo.job_execution_log';
PRINT '  - Full error handling with RAISERROR on failure';
PRINT '';
PRINT 'Dependencies:';
PRINT '  - Requires dim_cluster to be populated first (for cluster_key FK)';
PRINT '  - Uses LEFT JOIN to handle missing cluster mappings';
PRINT '';
PRINT '============================================================================';
GO
