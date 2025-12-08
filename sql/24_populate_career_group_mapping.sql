-- ============================================================================
-- File: sql/24_populate_career_group_mapping.sql
-- Purpose: Implement business logic for Career-to-CareerGroup mapping
-- Phase: Phase 3.5 - Labor Market Data Integration
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Populate_career_group_mapping', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Populate_career_group_mapping;
GO

CREATE PROCEDURE dbo.sp_Populate_career_group_mapping
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @MappingsCreated INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Populate_career_group_mapping at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- Clear existing mappings for recalculation
        DELETE FROM SkillStack_Control.ctl.CareerGroupMapping
        WHERE mapping_status = 'ACTIVE' AND mapping_method IN ('SOC Based', 'Algorithm');

        IF @DebugMode = 1
            PRINT 'Cleared existing algorithm-based mappings for recalculation';

        -- Algorithm-based mapping: Map careers to career groups based on SOC code prefixes
        -- SOC Structure: Division (2-digit) → Group (4-digit) → Detailed (6-digit)
        -- Career Groups in SkillStack typically align with SOC divisions and groups

        WITH career_soc_analysis AS (
            SELECT
                dc.career_key,
                dc.career_id,
                dc.career_name,
                SUBSTRING(dc.soc_code, 1, 2) AS soc_division,
                SUBSTRING(dc.soc_code, 1, 4) AS soc_group,
                dc.soc_code,
                COUNT(DISTINCT dbs.badge_key) as badge_count,
                -- Determine career group based on SOC division
                CASE
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('11', '13', '15', '17', '19') THEN 1  -- Management & Business
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('21', '23', '25', '27', '29') THEN 2  -- Professional & Related
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('31', '33', '35', '37', '39') THEN 3  -- Service Occupations
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('41', '43', '45', '47', '49') THEN 4  -- Sales & Administrative
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('51', '53', '55', '57', '59') THEN 5  -- Production & Transportation
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('61', '62', '63', '65') THEN 6        -- Natural Resources & Agriculture
                    ELSE NULL
                END AS mapped_career_group_id,
                CASE
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('11', '13', '15', '17', '19') THEN 'Management & Business Operations'
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('21', '23', '25', '27', '29') THEN 'Professional & Related Occupations'
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('31', '33', '35', '37', '39') THEN 'Service Occupations'
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('41', '43', '45', '47', '49') THEN 'Sales & Office & Administrative Support'
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('51', '53', '55', '57', '59') THEN 'Production & Transportation'
                    WHEN SUBSTRING(dc.soc_code, 1, 2) IN ('61', '62', '63', '65') THEN 'Natural Resources & Agriculture'
                    ELSE 'Unmapped'
                END AS soc_division_name
            FROM dbo.dim_career dc
            LEFT JOIN dbo.dim_badge_career_bridge dbs ON dc.career_key = dbs.career_key
            WHERE dc.is_current = 1
                AND dc.career_key <> 0
                AND dc.soc_code IS NOT NULL
                AND dc.soc_code <> ''
            GROUP BY dc.career_key, dc.career_id, dc.career_name, dc.soc_code
        )
        INSERT INTO SkillStack_Control.ctl.CareerGroupMapping (
            career_id, career_group_id, mapping_rule_name, mapping_confidence,
            mapping_method, is_primary_mapping, priority_order, mapping_status,
            source_soc_code, source_occupation_title, source_skills_matched
        )
        SELECT
            csa.career_id,
            ISNULL(dcg.career_group_key, 0) AS career_group_id,
            CONCAT('SOC Division ', SUBSTRING(csa.soc_code, 1, 2), ' → ', csa.soc_division_name) AS mapping_rule_name,
            0.85 AS mapping_confidence,  -- High confidence SOC-based mapping
            'SOC Based' AS mapping_method,
            1 AS is_primary_mapping,
            1 AS priority_order,
            'ACTIVE' AS mapping_status,
            csa.soc_code,
            csa.career_name,
            csa.badge_count
        FROM career_soc_analysis csa
        LEFT JOIN dbo.dim_career_group dcg
            ON dcg.career_group_name = csa.soc_division_name
            AND dcg.is_current = 1
        WHERE csa.mapped_career_group_id IS NOT NULL;

        SET @MappingsCreated = @@ROWCOUNT;

        IF @DebugMode = 1
            PRINT 'Career-to-CareerGroup mappings created: ' + CAST(@MappingsCreated AS VARCHAR(10));

        -- Update dim_career with mapped career group keys
        UPDATE dbo.dim_career
        SET
            career_group_key = ISNULL(cgm.career_group_id, 0),
            dw_updated_date = GETDATE()
        FROM dbo.dim_career dc
        INNER JOIN SkillStack_Control.ctl.CareerGroupMapping cgm
            ON dc.career_id = cgm.career_id
            AND cgm.is_primary_mapping = 1
            AND cgm.mapping_status = 'ACTIVE'
        WHERE dc.is_current = 1 AND dc.career_key <> 0;

        IF @DebugMode = 1
            PRINT 'dim_career updated with mapped career group keys';

        -- Log the operation
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Career Mapping', 'sp_Populate_career_group_mapping', 'Success', @MappingsCreated, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Populate_career_group_mapping at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE();
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Career Mapping', 'sp_Populate_career_group_mapping', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Stored Procedure sp_Populate_career_group_mapping Created Successfully';
PRINT '============================================================================';
GO
