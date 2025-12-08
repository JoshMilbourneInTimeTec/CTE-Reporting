-- ============================================================================
-- File: sql/26_create_labor_market_analytical_views.sql
-- Purpose: Create analytical views for labor market reporting and analysis
-- Phase: Phase 3.5 - Labor Market Data Integration
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- View 1: Badge to Career Alignment Analysis
IF OBJECT_ID('dbo.vw_badge_career_alignment_analysis', 'V') IS NOT NULL
    DROP VIEW dbo.vw_badge_career_alignment_analysis;
GO

CREATE VIEW dbo.vw_badge_career_alignment_analysis
AS
SELECT
    db.badge_name,
    db.badge_id,
    db.required_hours_to_complete,
    dc.career_name,
    dc.career_id,
    dc.median_annual_wage,
    dc.job_growth_percentage,
    dcg.career_group_name,
    dbc.alignment_strength,
    dbc.is_primary_pathway,
    CASE
        WHEN dbc.alignment_strength >= 0.80 THEN 'Excellent'
        WHEN dbc.alignment_strength >= 0.60 THEN 'Good'
        WHEN dbc.alignment_strength >= 0.40 THEN 'Fair'
        WHEN dbc.alignment_strength >= 0.20 THEN 'Weak'
        ELSE 'No Alignment'
    END as alignment_quality,
    dc.is_stem,
    dc.is_high_demand,
    COUNT(DISTINCT dbtb.tag_key) as badge_tag_count
FROM dbo.dim_badge db
INNER JOIN dbo.dim_badge_career_bridge dbc ON db.badge_key = dbc.badge_key
INNER JOIN dbo.dim_career dc ON dbc.career_key = dc.career_key
LEFT JOIN dbo.dim_career_group dcg ON dc.career_group_key = dcg.career_group_key
LEFT JOIN dbo.dim_badge_tag_bridge dbtb ON db.badge_key = dbtb.badge_key AND dbtb.tag_key <> 0
WHERE db.is_current = 1 AND db.badge_key <> 0
    AND dc.is_current = 1 AND dc.career_key <> 0
    AND dbc.alignment_strength > 0
GROUP BY db.badge_name, db.badge_id, db.required_hours_to_complete,
         dc.career_name, dc.career_id, dc.median_annual_wage, dc.job_growth_percentage,
         dcg.career_group_name, dbc.alignment_strength, dbc.is_primary_pathway,
         dc.is_stem, dc.is_high_demand;
GO

-- View 2: Career High-Demand Analysis
IF OBJECT_ID('dbo.vw_career_high_demand_analysis', 'V') IS NOT NULL
    DROP VIEW dbo.vw_career_high_demand_analysis;
GO

CREATE VIEW dbo.vw_career_high_demand_analysis
AS
SELECT
    dc.career_name,
    dc.career_id,
    dcg.career_group_name,
    dc.soc_code,
    dc.onet_code,
    dc.median_annual_wage,
    dc.job_growth_percentage,
    dc.is_stem,
    dc.is_high_demand,
    COUNT(DISTINCT dbc.badge_key) as badge_count,
    AVG(CAST(dbc.alignment_strength AS NUMERIC(5,2))) as avg_alignment_strength,
    SUM(CASE WHEN dbc.is_primary_pathway = 1 THEN 1 ELSE 0 END) as primary_pathway_count,
    COUNT(DISTINCT dbtb.tag_key) as unique_tag_count
FROM dbo.dim_career dc
LEFT JOIN dbo.dim_career_group dcg ON dc.career_group_key = dcg.career_group_key
LEFT JOIN dbo.dim_badge_career_bridge dbc ON dc.career_key = dbc.career_key AND dbc.alignment_strength > 0
LEFT JOIN dbo.dim_badge db ON dbc.badge_key = db.badge_key AND db.is_current = 1
LEFT JOIN dbo.dim_badge_tag_bridge dbtb ON db.badge_key = dbtb.badge_key AND dbtb.tag_key <> 0
WHERE dc.is_current = 1 AND dc.career_key <> 0
GROUP BY dc.career_name, dc.career_id, dcg.career_group_name, dc.soc_code, dc.onet_code,
         dc.median_annual_wage, dc.job_growth_percentage, dc.is_stem, dc.is_high_demand;
GO

-- View 3: Badge Coverage by Career Group
IF OBJECT_ID('dbo.vw_badge_coverage_by_career_group', 'V') IS NOT NULL
    DROP VIEW dbo.vw_badge_coverage_by_career_group;
GO

CREATE VIEW dbo.vw_badge_coverage_by_career_group
AS
SELECT
    dcg.career_group_name,
    dcg.career_group_id,
    COUNT(DISTINCT dc.career_key) as career_count,
    COUNT(DISTINCT CASE WHEN dbc.badge_key <> 0 THEN dbc.badge_key END) as aligned_badge_count,
    ROUND(
        CAST(COUNT(DISTINCT CASE WHEN dbc.badge_key <> 0 THEN dbc.badge_key END) AS NUMERIC(5,2)) /
        NULLIF(CAST(COUNT(DISTINCT db.badge_key) AS NUMERIC(5,2)), 0) * 100,
        2
    ) as badge_coverage_percentage,
    AVG(CAST(dbc.alignment_strength AS NUMERIC(5,2))) as avg_alignment_strength,
    COUNT(DISTINCT dbs.badge_key) as occupation_aligned_badge_count,
    MIN(dc.median_annual_wage) as min_career_wage,
    MAX(dc.median_annual_wage) as max_career_wage,
    AVG(dc.job_growth_percentage) as avg_job_growth
FROM dbo.dim_career_group dcg
LEFT JOIN dbo.dim_career dc ON dcg.career_group_key = dc.career_group_key AND dc.is_current = 1
LEFT JOIN dbo.dim_badge_career_bridge dbc ON dc.career_key = dbc.career_key AND dbc.alignment_strength > 0
LEFT JOIN dbo.dim_badge db ON dbc.badge_key = db.badge_key AND db.is_current = 1 AND db.badge_key <> 0
LEFT JOIN dbo.dim_badge_occupation_bridge dbs ON db.badge_key = dbs.badge_key
WHERE dcg.is_current = 1 AND dcg.career_group_key <> 0
GROUP BY dcg.career_group_name, dcg.career_group_id;
GO

-- View 4: STEM & High-Demand Career Pipeline
IF OBJECT_ID('dbo.vw_stem_high_demand_pipeline', 'V') IS NOT NULL
    DROP VIEW dbo.vw_stem_high_demand_pipeline;
GO

CREATE VIEW dbo.vw_stem_high_demand_pipeline
AS
SELECT
    CASE WHEN dc.is_stem = 1 AND dc.is_high_demand = 1 THEN 'STEM High-Demand'
         WHEN dc.is_stem = 1 THEN 'STEM Standard'
         WHEN dc.is_high_demand = 1 THEN 'Non-STEM High-Demand'
         ELSE 'Standard'
    END as pipeline_category,
    dcg.career_group_name,
    COUNT(DISTINCT dc.career_key) as career_count,
    COUNT(DISTINCT CASE WHEN dbc.alignment_strength >= 0.6 THEN dbc.badge_key END) as well_aligned_badge_count,
    COUNT(DISTINCT CASE WHEN dbc.alignment_strength >= 0.6 THEN dbc.badge_key END) /
        NULLIF(COUNT(DISTINCT db.badge_key), 0) as badge_alignment_ratio,
    AVG(dc.median_annual_wage) as avg_median_wage,
    AVG(dc.job_growth_percentage) as avg_job_growth_percentage,
    COUNT(DISTINCT do.occupation_key) as occupation_count,
    COUNT(DISTINCT dcert.certification_key) as certification_count
FROM dbo.dim_career dc
LEFT JOIN dbo.dim_career_group dcg ON dc.career_group_key = dcg.career_group_key
LEFT JOIN dbo.dim_badge_career_bridge dbc ON dc.career_key = dbc.career_key
LEFT JOIN dbo.dim_badge db ON dbc.badge_key = db.badge_key AND db.is_current = 1 AND db.badge_key <> 0
LEFT JOIN dbo.dim_badge_occupation_bridge dbo ON db.badge_key = dbo.badge_key
LEFT JOIN dbo.dim_occupation do ON dbo.occupation_key = do.occupation_key AND do.is_current = 1
LEFT JOIN dbo.dim_badge_certification_bridge dbcert ON db.badge_key = dbcert.badge_key
LEFT JOIN dbo.dim_certification dcert ON dbcert.certification_key = dcert.certification_key AND dcert.is_current = 1
WHERE dc.is_current = 1 AND dc.career_key <> 0
GROUP BY dc.is_stem, dc.is_high_demand, dcg.career_group_name;
GO

-- View 5: Occupation Alignment Summary
IF OBJECT_ID('dbo.vw_occupation_alignment_summary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_occupation_alignment_summary;
GO

CREATE VIEW dbo.vw_occupation_alignment_summary
AS
SELECT
    do.occupation_name,
    do.occupation_id,
    do.soc_code,
    do.onet_code,
    do.median_annual_wage,
    do.job_growth_percentage,
    do.is_stem,
    do.is_high_demand,
    COUNT(DISTINCT dbo.badge_key) as badge_count,
    COUNT(DISTINCT dc.career_key) as career_count,
    COUNT(DISTINCT CASE WHEN dbo.alignment_strength > 0 THEN dbo.badge_key END) as aligned_badge_count,
    AVG(CAST(dbc.alignment_strength AS NUMERIC(5,2))) as avg_badge_career_alignment,
    MIN(do.dw_created_date) as first_seen,
    MAX(do.dw_updated_date) as last_updated
FROM dbo.dim_occupation do
LEFT JOIN dbo.dim_badge_occupation_bridge dbo ON do.occupation_key = dbo.occupation_key
LEFT JOIN dbo.dim_badge db ON dbo.badge_key = db.badge_key AND db.is_current = 1 AND db.badge_key <> 0
LEFT JOIN dbo.dim_badge_career_bridge dbc ON db.badge_key = dbc.badge_key AND dbc.alignment_strength > 0
LEFT JOIN dbo.dim_career dc ON dbc.career_key = dc.career_key AND dc.is_current = 1
WHERE do.is_current = 1 AND do.occupation_key <> 0
GROUP BY do.occupation_name, do.occupation_id, do.soc_code, do.onet_code,
         do.median_annual_wage, do.job_growth_percentage, do.is_stem, do.is_high_demand,
         do.dw_created_date, do.dw_updated_date;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Labor Market Analytical Views Created Successfully';
PRINT '============================================================================';
PRINT '  - vw_badge_career_alignment_analysis';
PRINT '  - vw_career_high_demand_analysis';
PRINT '  - vw_badge_coverage_by_career_group';
PRINT '  - vw_stem_high_demand_pipeline';
PRINT '  - vw_occupation_alignment_summary';
PRINT '============================================================================';
GO
