-- ============================================================================
-- File: sql/25_recalculate_alignment_scores.sql
-- Purpose: Recalculate badge-career alignment scores with nuanced algorithm
-- Phase: Phase 3.5 - Labor Market Data Integration
-- Algorithm: (Skill Match × 0.5) + (Cert Coverage × 0.3) + (Growth Potential × 0.2)
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Recalculate_alignment_scores', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Recalculate_alignment_scores;
GO

CREATE PROCEDURE dbo.sp_Recalculate_alignment_scores
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @RowsUpdated INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Recalculate_alignment_scores at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- Create temporary table for alignment score calculations
        CREATE TABLE #alignment_calculations (
            badge_key INT,
            career_key INT,
            skill_match_score NUMERIC(5,2),
            cert_coverage_score NUMERIC(5,2),
            growth_potential_score NUMERIC(5,2),
            composite_score NUMERIC(5,2),
            is_primary NUMERIC(5,2)
        );

        -- Calculate skill match factor (0.00-1.00)
        -- Factor: Badges and careers with overlapping skill requirements score higher
        WITH badge_skill_count AS (
            SELECT db.badge_key, COUNT(DISTINCT ds.skill_key) as skill_count
            FROM dbo.dim_badge db
            LEFT JOIN dbo.dim_skill ds ON db.badge_key <> 0
            WHERE db.is_current = 1 AND db.badge_key <> 0
            GROUP BY db.badge_key
        ),
        career_skill_requirements AS (
            SELECT dc.career_key, COUNT(DISTINCT dbs.badge_key) as career_related_badges
            FROM dbo.dim_career dc
            LEFT JOIN dbo.dim_badge_career_bridge dbs ON dc.career_key = dbs.career_key
            WHERE dc.is_current = 1 AND dc.career_key <> 0
            GROUP BY dc.career_key
        )
        INSERT INTO #alignment_calculations (badge_key, career_key, skill_match_score)
        SELECT
            db.badge_key,
            dc.career_key,
            -- Skill match: Higher score if badge has many skills and career requires similar skills
            CAST(ROUND(
                CAST(ISNULL(bsc.skill_count, 0) AS NUMERIC(5,2)) /
                NULLIF(CAST(ISNULL(csr.career_related_badges, 1) AS NUMERIC(5,2)), 0) * 0.5,
                2
            ) AS NUMERIC(5,2)) * 2  -- Normalize to 0-1 scale
        FROM dbo.dim_badge db
        CROSS JOIN dbo.dim_career dc
        LEFT JOIN badge_skill_count bsc ON db.badge_key = bsc.badge_key
        LEFT JOIN career_skill_requirements csr ON dc.career_key = csr.career_key
        WHERE db.is_current = 1 AND db.badge_key <> 0
            AND dc.is_current = 1 AND dc.career_key <> 0;

        IF @DebugMode = 1
            PRINT 'Calculated skill match scores: ' + CAST(@@ROWCOUNT AS VARCHAR(10)) + ' combinations';

        -- Calculate certification coverage factor (0.00-1.00)
        -- Factor: Careers requiring certifications map higher with badge-cert alignments
        UPDATE #alignment_calculations
        SET cert_coverage_score = CAST(ROUND(
            CAST((SELECT COUNT(*) FROM dbo.dim_badge_certification_bridge dbc
                WHERE dbc.badge_key = #alignment_calculations.badge_key) AS NUMERIC(5,2)) /
            NULLIF(CAST((SELECT COUNT(*) FROM dbo.dim_certification) - 1 AS NUMERIC(5,2)), 0),
            2
        ) AS NUMERIC(5,2))
        WHERE badge_key <> 0;

        IF @DebugMode = 1
            PRINT 'Calculated certification coverage scores';

        -- Calculate growth potential factor (0.00-1.00)
        -- Factor: Careers with high growth % and high wages score higher
        UPDATE #alignment_calculations
        SET growth_potential_score = CAST(ROUND(
            CASE
                WHEN dc.job_growth_percentage >= 15 THEN 1.0
                WHEN dc.job_growth_percentage >= 10 THEN 0.8
                WHEN dc.job_growth_percentage >= 5 THEN 0.6
                WHEN dc.job_growth_percentage >= 0 THEN 0.4
                ELSE 0.2
            END *
            CASE
                WHEN dc.median_annual_wage >= 100000 THEN 1.0
                WHEN dc.median_annual_wage >= 75000 THEN 0.8
                WHEN dc.median_annual_wage >= 50000 THEN 0.6
                WHEN dc.median_annual_wage >= 30000 THEN 0.4
                ELSE 0.2
            END,
            2
        ) AS NUMERIC(5,2))
        FROM dbo.dim_career dc
        WHERE #alignment_calculations.career_key = dc.career_key
            AND dc.is_current = 1;

        IF @DebugMode = 1
            PRINT 'Calculated growth potential scores';

        -- Calculate composite alignment score using weighted formula
        -- Formula: (Skill Match × 0.5) + (Cert Coverage × 0.3) + (Growth Potential × 0.2)
        UPDATE #alignment_calculations
        SET composite_score = CAST(ROUND(
            ISNULL(skill_match_score, 0) * 0.50 +
            ISNULL(cert_coverage_score, 0) * 0.30 +
            ISNULL(growth_potential_score, 0) * 0.20,
            2
        ) AS NUMERIC(5,2)),
        is_primary = ROW_NUMBER() OVER (PARTITION BY badge_key ORDER BY composite_score DESC);

        IF @DebugMode = 1
            PRINT 'Calculated composite scores using weighted algorithm';

        -- Update dim_badge_career_bridge with new alignment scores
        UPDATE dbo.dim_badge_career_bridge
        SET
            alignment_strength = ac.composite_score,
            is_primary_pathway = CASE WHEN ac.is_primary = 1 THEN 1 ELSE 0 END,
            dw_updated_date = GETDATE()
        FROM #alignment_calculations ac
        WHERE dbo.dim_badge_career_bridge.badge_key = ac.badge_key
            AND dbo.dim_badge_career_bridge.career_key = ac.career_key;

        SET @RowsUpdated = @@ROWCOUNT;

        IF @DebugMode = 1
            PRINT 'Updated bridge table with new alignment scores: ' + CAST(@RowsUpdated AS VARCHAR(10));

        -- Validate new scores are within expected range
        DECLARE @MinScore NUMERIC(5,2) = (SELECT MIN(alignment_strength) FROM dbo.dim_badge_career_bridge);
        DECLARE @MaxScore NUMERIC(5,2) = (SELECT MAX(alignment_strength) FROM dbo.dim_badge_career_bridge);
        DECLARE @AvgScore NUMERIC(5,2) = (SELECT AVG(alignment_strength) FROM dbo.dim_badge_career_bridge);

        IF @DebugMode = 1
        BEGIN
            PRINT 'Alignment Score Statistics:';
            PRINT '  Min: ' + CAST(ISNULL(@MinScore, 0) AS VARCHAR(10));
            PRINT '  Max: ' + CAST(ISNULL(@MaxScore, 0) AS VARCHAR(10));
            PRINT '  Avg: ' + CAST(ISNULL(@AvgScore, 0) AS VARCHAR(10));
        END;

        -- Clean up temporary table
        DROP TABLE #alignment_calculations;

        -- Log the operation
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Alignment Scoring', 'sp_Recalculate_alignment_scores', 'Success', @RowsUpdated, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Recalculate_alignment_scores at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE();
        IF OBJECT_ID('tempdb..#alignment_calculations') IS NOT NULL
            DROP TABLE #alignment_calculations;
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Alignment Scoring', 'sp_Recalculate_alignment_scores', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Stored Procedure sp_Recalculate_alignment_scores Created Successfully';
PRINT '============================================================================';
GO
