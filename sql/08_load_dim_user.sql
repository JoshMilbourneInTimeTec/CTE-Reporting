-- ============================================================================
-- File: sql/08_load_dim_user.sql
-- Purpose: Load/update dim_user dimension table from staging
-- Pattern: SCD Type 2 with MERGE-based approach
-- Handles: INSERT new records, UPDATE changed records, MARK DELETED records
-- Phase 2 Enhancement: Populate user_type from IsHighSchool flag
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- ============================================================================
-- DROP EXISTING PROCEDURE (allows re-creation)
-- ============================================================================
IF OBJECT_ID('dbo.sp_Load_dim_user', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Load_dim_user;
GO

-- ============================================================================
-- CREATE PROCEDURE: sp_Load_dim_user
-- ============================================================================
CREATE PROCEDURE dbo.sp_Load_dim_user
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
            PRINT 'Starting sp_Load_dim_user at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- ====================================================================
        -- MERGE LOGIC: INSERT new, UPDATE changed, MARK DELETED
        -- ====================================================================
        MERGE dbo.dim_user AS target
        USING (
            SELECT
                CAST(u_stg.UserId AS INT) AS user_id,
                u_stg.PortfolioGuid AS user_guid,
                u_stg.LoginId AS username,
                COALESCE(u_stg.SchoolEmailAddress, u_stg.PersonalEmailAddress) AS email,
                u_stg.FirstName AS first_name,
                u_stg.LastName AS last_name,
                COALESCE(u_stg.PreferedName, u_stg.FirstName + ' ' + u_stg.LastName) AS display_name,
                -- Phase 2 Enhancement: Derive user_type from IsHighSchool flag
                CASE WHEN u_stg.IsHighSchool = 1 THEN 'High School' ELSE 'Post-Secondary' END AS user_type,
                u_stg.GraduationYear AS graduation_year,
                COALESCE(d.district_key, 0) AS district_key,
                COALESCE(s.school_key, 0) AS school_key,
                u_stg.AddressLine1 AS address,
                u_stg.City AS city,
                u_stg.State AS state,
                u_stg.ZIP AS zip_code,
                u_stg.Phone AS phone,
                u_stg.IsActive,
                u_stg.ModifiedDate
            FROM (
                SELECT *,
                    ROW_NUMBER() OVER (PARTITION BY UserId ORDER BY ModifiedDate DESC, UserId) AS rn
                FROM SkillStack_Staging.stg.USR_Users
            ) u_stg
            LEFT JOIN dbo.dim_district d
                ON CAST(u_stg.DistrictId AS VARCHAR(50)) = d.district_id
                AND d.is_current = 1
            LEFT JOIN dbo.dim_school s
                ON CAST(u_stg.SchoolId AS VARCHAR(50)) = s.school_id
                AND s.is_current = 1
            WHERE u_stg.rn = 1
        ) AS source
        ON target.user_id = source.user_id
           AND target.is_current = 1

        -- UPDATE: User data changed
        WHEN MATCHED AND (
            -- Detect attribute changes
            target.username <> source.username
            OR target.email <> source.email
            OR (target.email IS NULL AND source.email IS NOT NULL)
            OR (target.email IS NOT NULL AND source.email IS NULL)
            OR target.first_name <> source.first_name
            OR target.last_name <> source.last_name
            OR target.display_name <> source.display_name
            OR target.user_type <> source.user_type
            OR (target.user_type IS NULL AND source.user_type IS NOT NULL)
            OR (target.user_type IS NOT NULL AND source.user_type IS NULL)
            OR target.graduation_year <> source.graduation_year
            OR (target.graduation_year IS NULL AND source.graduation_year IS NOT NULL)
            OR (target.graduation_year IS NOT NULL AND source.graduation_year IS NULL)
            OR target.district_key <> source.district_key
            OR target.school_key <> source.school_key
            OR target.address <> source.address
            OR (target.address IS NULL AND source.address IS NOT NULL)
            OR (target.address IS NOT NULL AND source.address IS NULL)
            OR target.city <> source.city
            OR (target.city IS NULL AND source.city IS NOT NULL)
            OR (target.city IS NOT NULL AND source.city IS NULL)
            OR target.state <> source.state
            OR (target.state IS NULL AND source.state IS NOT NULL)
            OR (target.state IS NOT NULL AND source.state IS NULL)
            OR target.zip_code <> source.zip_code
            OR (target.zip_code IS NULL AND source.zip_code IS NOT NULL)
            OR (target.zip_code IS NOT NULL AND source.zip_code IS NULL)
            OR target.phone <> source.phone
            OR (target.phone IS NULL AND source.phone IS NOT NULL)
            OR (target.phone IS NOT NULL AND source.phone IS NULL)
        ) THEN
            UPDATE SET
                username = source.username,
                email = source.email,
                first_name = source.first_name,
                last_name = source.last_name,
                display_name = source.display_name,
                user_type = source.user_type,
                graduation_year = source.graduation_year,
                district_key = source.district_key,
                school_key = source.school_key,
                address = source.address,
                city = source.city,
                state = source.state,
                zip_code = source.zip_code,
                phone = source.phone,
                is_current = 1,
                dw_updated_date = GETDATE()

        -- INSERT: New user from staging
        WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
            INSERT (
                user_id,
                user_guid,
                username,
                email,
                first_name,
                last_name,
                display_name,
                user_type,
                graduation_year,
                district_key,
                school_key,
                address,
                city,
                state,
                zip_code,
                phone,
                is_current,
                dw_created_date,
                dw_updated_date
            )
            VALUES (
                source.user_id,
                source.user_guid,
                source.username,
                source.email,
                source.first_name,
                source.last_name,
                source.display_name,
                source.user_type,
                source.graduation_year,
                source.district_key,
                source.school_key,
                source.address,
                source.city,
                source.state,
                source.zip_code,
                source.phone,
                1,
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
            'sp_Load_dim_user',
            'Success',
            @RowsInserted,
            @StartTime,
            GETDATE(),
            NULL
        );

        IF @DebugMode = 1
            PRINT 'Completed sp_Load_dim_user at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

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
            'sp_Load_dim_user',
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
PRINT 'sp_Load_dim_user Stored Procedure Updated Successfully';
PRINT '============================================================================';
PRINT 'Procedure: dbo.sp_Load_dim_user';
PRINT 'Parameters: @DebugMode BIT (0=Production, 1=Debug output)';
PRINT '';
PRINT 'Functionality:';
PRINT '  - Deduplicates staging data (ROW_NUMBER by user_id, desc by ModifiedDate)';
PRINT '  - Joins with dim_district and dim_school for FKs';
PRINT '  - MERGE to handle INSERT/UPDATE/DELETE patterns';
PRINT '  - Detects attribute changes (name, email, user_type, graduation_year, etc.)';
PRINT '  - Phase 2 Enhancement: Derives user_type from IsHighSchool flag';
PRINT '    * IsHighSchool = 1 → "High School"';
PRINT '    * IsHighSchool = 0 → "Post-Secondary"';
PRINT '  - Logs all executions to dbo.job_execution_log';
PRINT '  - Full error handling with RAISERROR on failure';
PRINT '';
PRINT 'Dependencies:';
PRINT '  - Requires dim_district and dim_school to be populated first';
PRINT '  - Uses LEFT JOINs to handle missing mappings (maps to Unknown/key=0)';
PRINT '';
PRINT '============================================================================';
GO
