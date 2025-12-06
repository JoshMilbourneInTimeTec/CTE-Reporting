-- ============================================================================
-- File: sql/05_load_dim_specialty.sql
-- Purpose: Load dim_specialty dimension table from staging
-- Pattern: SCD Type 2 with MERGE-based approach
-- Handles: INSERT new records, UPDATE changed records, MARK DELETED records
-- Dependencies: dim_pathway must be populated first
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- ============================================================================
-- DROP EXISTING PROCEDURE (allows re-creation)
-- ============================================================================
IF OBJECT_ID('dbo.sp_Load_dim_specialty', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_specialty;
GO

-- ============================================================================
-- CREATE PROCEDURE: sp_Load_dim_specialty
-- ============================================================================
CREATE PROCEDURE dbo.sp_Load_dim_specialty
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
            PRINT 'Starting sp_Load_dim_specialty at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- PRE-CALCULATION: Badge and skill counts per specialty
        -- ====================================================================
        DECLARE @BadgeCounts TABLE (
            specialty_id INT,
            badge_count INT,
            skill_count INT
        );

        INSERT INTO @BadgeCounts
        SELECT
            ds.specialty_id,
            COUNT(DISTINCT db.badge_key) AS badge_count,
            COUNT(DISTINCT dsk.skill_key) AS skill_count
        FROM dbo.dim_specialty ds
        LEFT JOIN dbo.dim_badge db ON ds.specialty_key = db.specialty_key AND db.is_current = 1 AND db.badge_key <> 0
        LEFT JOIN dbo.dim_skill dsk ON db.badge_key = dsk.badge_key AND dsk.is_current = 1 AND dsk.skill_key <> 0
        WHERE ds.is_current = 1 AND ds.specialty_key <> 0
        GROUP BY ds.specialty_id;

        -- ====================================================================
        -- MERGE LOGIC: INSERT new, UPDATE changed, MARK DELETED
        -- ====================================================================
        MERGE dbo.dim_specialty AS target
        USING (
            SELECT
                CAST(stg.SpecialtyId AS INT) AS specialty_id,
                ISNULL(dp.pathway_key, 0) AS pathway_key,
                stg.[Name] AS specialty_name,
                NULL AS specialty_code,
                stg.[Description] AS specialty_description,
                stg.ImageURL AS specialty_icon_url,
                NULL AS display_order,
                ISNULL(bc.badge_count, 0) AS required_badge_count,
                ISNULL(bc.skill_count, 0) AS required_skill_count,
                stg.IsActive,
                stg.ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY SpecialtyId ORDER BY ModifiedDate DESC, SpecialtyId) AS rn
                FROM SkillStack_Staging.stg.BDG_Specialties
            ) stg
            LEFT JOIN dbo.dim_pathway dp
                ON CAST(stg.PathwayId AS INT) = dp.pathway_id
                AND dp.is_current = 1
            LEFT JOIN @BadgeCounts bc
                ON CAST(stg.SpecialtyId AS INT) = bc.specialty_id
            WHERE rn = 1
        ) AS source
        ON target.specialty_id = source.specialty_id
           AND target.is_current = 1

        -- UPDATE: Specialty data changed or specialty marked inactive
        WHEN MATCHED AND (
            -- Detect attribute changes
            target.specialty_name <> source.specialty_name
            OR target.specialty_description <> source.specialty_description
            OR (target.specialty_description IS NULL AND source.specialty_description IS NOT NULL)
            OR (target.specialty_description IS NOT NULL AND source.specialty_description IS NULL)
            OR target.specialty_icon_url <> source.specialty_icon_url
            OR (target.specialty_icon_url IS NULL AND source.specialty_icon_url IS NOT NULL)
            OR (target.specialty_icon_url IS NOT NULL AND source.specialty_icon_url IS NULL)
            OR target.display_order <> source.display_order
            OR (target.display_order IS NULL AND source.display_order IS NOT NULL)
            OR (target.display_order IS NOT NULL AND source.display_order IS NULL)
            OR target.required_badge_count <> source.required_badge_count
            OR (target.required_badge_count IS NULL AND source.required_badge_count IS NOT NULL)
            OR (target.required_badge_count IS NOT NULL AND source.required_badge_count IS NULL)
            OR target.required_skill_count <> source.required_skill_count
            OR (target.required_skill_count IS NULL AND source.required_skill_count IS NOT NULL)
            OR (target.required_skill_count IS NOT NULL AND source.required_skill_count IS NULL)
            OR target.pathway_key <> source.pathway_key
            -- OR specialty marked inactive
            OR source.IsActive = 0
        ) THEN
            UPDATE SET
                pathway_key = CASE WHEN source.IsActive = 1 THEN source.pathway_key ELSE target.pathway_key END,
                specialty_name = CASE WHEN source.IsActive = 1 THEN source.specialty_name ELSE target.specialty_name END,
                specialty_description = CASE WHEN source.IsActive = 1 THEN source.specialty_description ELSE target.specialty_description END,
                specialty_icon_url = CASE WHEN source.IsActive = 1 THEN source.specialty_icon_url ELSE target.specialty_icon_url END,
                display_order = CASE WHEN source.IsActive = 1 THEN source.display_order ELSE target.display_order END,
                required_badge_count = CASE WHEN source.IsActive = 1 THEN source.required_badge_count ELSE target.required_badge_count END,
                required_skill_count = CASE WHEN source.IsActive = 1 THEN source.required_skill_count ELSE target.required_skill_count END,
                is_active = source.IsActive,
                is_current = CASE WHEN source.IsActive = 0 AND target.specialty_key <> 0 THEN 0 ELSE 1 END,
                expiration_date = CASE WHEN source.IsActive = 0 AND target.specialty_key <> 0 THEN GETDATE() ELSE NULL END,
                dw_updated_date = GETDATE()

        -- INSERT: New specialty from staging
        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                specialty_id,
                pathway_key,
                specialty_name,
                specialty_code,
                specialty_description,
                specialty_icon_url,
                display_order,
                required_badge_count,
                required_skill_count,
                is_active,
                is_current,
                effective_date,
                dw_created_date,
                dw_updated_date
            )
            VALUES (
                source.specialty_id,
                source.pathway_key,
                source.specialty_name,
                source.specialty_code,
                source.specialty_description,
                source.specialty_icon_url,
                source.display_order,
                source.required_badge_count,
                source.required_skill_count,
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
            'sp_Load_dim_specialty',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_specialty at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

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
            'sp_Load_dim_specialty',
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
PRINT 'sp_Load_dim_specialty Stored Procedure Created Successfully';
PRINT '============================================================================';
PRINT 'Procedure: dbo.sp_Load_dim_specialty';
PRINT 'Parameters: @DebugMode BIT (0=Production, 1=Debug output)';
PRINT '';
PRINT 'Functionality:';
PRINT '  - Deduplicates staging data (ROW_NUMBER by specialty_id, desc by ModifiedDate)';
PRINT '  - Joins with dim_pathway to get pathway_key';
PRINT '  - MERGE to handle INSERT/UPDATE/DELETE patterns';
PRINT '  - Detects attribute changes (specialty_name, description, pathway mapping)';
PRINT '  - Marks specialties as inactive by setting is_current=0, expiration_date=GETDATE()';
PRINT '  - Logs all executions to dbo.job_execution_log';
PRINT '  - Full error handling with RAISERROR on failure';
PRINT '';
PRINT 'Dependencies:';
PRINT '  - Requires dim_pathway to be populated first (for pathway_key FK)';
PRINT '  - Uses LEFT JOIN to handle missing pathway mappings (maps to Unknown/key=0)';
PRINT '';
PRINT 'CRITICAL:';
PRINT '  - This dimension fixes the blocking issue with dim_badge.specialty_key FK';
PRINT '  - After loading, must add FK constraint to dim_badge.specialty_key';
PRINT '';
PRINT '============================================================================';
GO
