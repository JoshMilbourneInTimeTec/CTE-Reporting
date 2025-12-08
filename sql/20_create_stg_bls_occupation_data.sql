-- ============================================================================
-- File: sql/20_create_stg_bls_occupation_data.sql
-- Purpose: Create staging table for BLS occupation data (SOC codes, wages, growth)
-- Phase: Phase 3.5 - Labor Market Data Integration
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop if exists
IF OBJECT_ID('SkillStack_Staging.stg.BLS_OccupationData', 'U') IS NOT NULL
    DROP TABLE SkillStack_Staging.stg.BLS_OccupationData;
GO

-- Create staging table for BLS occupation data
CREATE TABLE SkillStack_Staging.stg.BLS_OccupationData (
    -- Primary identification
    soc_code NVARCHAR(8) NOT NULL PRIMARY KEY,              -- SOC 6-digit code (e.g., '51-3011')
    occupation_title NVARCHAR(256) NOT NULL,               -- Official BLS occupation title

    -- Labor market data
    median_annual_wage NUMERIC(10,2) NULL,                 -- Median annual wage in USD
    median_hourly_wage NUMERIC(8,2) NULL,                  -- Median hourly wage in USD
    employment_count INT NULL,                             -- Total employment count

    -- Job outlook data
    job_growth_percentage NUMERIC(5,2) NULL,               -- Projected 10-year job growth %
    new_jobs_openings INT NULL,                            -- Estimated new job openings (10-yr)
    replacement_openings INT NULL,                         -- Estimated replacement openings (10-yr)

    -- Classification data
    is_stem BIT DEFAULT 0 NOT NULL,                        -- Flag if STEM-related occupation
    is_high_demand BIT DEFAULT 0 NOT NULL,                 -- Flag if high-demand occupation
    wage_quartile INT NULL,                                -- Wage quartile (1=lowest, 4=highest)

    -- Source tracking
    data_source NVARCHAR(100) DEFAULT 'BLS' NOT NULL,      -- Data source (BLS 2024)
    source_year INT NULL,                                   -- Year of BLS data
    source_url NVARCHAR(500) NULL,                         -- URL to source data

    -- Data quality
    confidence_level NUMERIC(3,2) NULL,                    -- Confidence in wage data (0.00-1.00)
    last_updated_source DATETIME2 NULL,                    -- When this data was last updated in source

    -- Audit columns
    created_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    updated_date DATETIME2 DEFAULT GETDATE() NOT NULL
);
GO

-- Create indexes for efficient lookups
CREATE NONCLUSTERED INDEX IX_stg_bls_soc_code ON SkillStack_Staging.stg.BLS_OccupationData (soc_code);
GO

CREATE NONCLUSTERED INDEX IX_stg_bls_occupation_title ON SkillStack_Staging.stg.BLS_OccupationData (occupation_title)
    INCLUDE (median_annual_wage, job_growth_percentage);
GO

CREATE NONCLUSTERED INDEX IX_stg_bls_stem ON SkillStack_Staging.stg.BLS_OccupationData (is_stem, is_high_demand)
    INCLUDE (median_annual_wage, job_growth_percentage);
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Staging Table stg.BLS_OccupationData Created Successfully';
PRINT '============================================================================';
GO
