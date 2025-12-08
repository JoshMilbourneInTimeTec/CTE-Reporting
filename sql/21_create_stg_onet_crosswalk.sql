-- ============================================================================
-- File: sql/21_create_stg_onet_crosswalk.sql
-- Purpose: Create staging table for O*NET SOC crosswalk mapping
-- Phase: Phase 3.5 - Labor Market Data Integration
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop if exists
IF OBJECT_ID('SkillStack_Staging.stg.ONET_SOCCrosswalk', 'U') IS NOT NULL
    DROP TABLE SkillStack_Staging.stg.ONET_SOCCrosswalk;
GO

-- Create staging table for O*NET SOC crosswalk
CREATE TABLE SkillStack_Staging.stg.ONET_SOCCrosswalk (
    -- Identification
    onet_code NVARCHAR(10) NOT NULL PRIMARY KEY,           -- O*NET-SOC code (e.g., '51-3011.00')
    soc_code NVARCHAR(8) NOT NULL,                         -- Corresponding SOC code (e.g., '51-3011')
    occupation_title NVARCHAR(256) NOT NULL,               -- O*NET occupation title

    -- O*NET data attributes
    dwa_occupation_title NVARCHAR(256) NULL,               -- Detailed Work Activity title
    is_rapid_growth BIT DEFAULT 0 NOT NULL,                -- Rapidly growing occupation
    is_emerging BIT DEFAULT 0 NOT NULL,                    -- Emerging/innovative occupation

    -- Skills mapping
    typical_entry_education NVARCHAR(100) NULL,            -- Entry education level (HS, AA, BA, MA, etc.)
    typical_experience_required INT NULL,                  -- Typical years of experience (0-30)
    on_the_job_training_days INT NULL,                     -- Typical on-job-training duration (days)

    -- Competency levels (1-5 scale or importance ratings)
    skills_complexity_level INT NULL,                      -- Overall skills complexity (1-5)
    technology_level INT NULL,                             -- Technology skills level (1-5)

    -- Wage information
    mean_wage_national NUMERIC(10,2) NULL,                 -- National mean wage from O*NET
    percentile_25_wage NUMERIC(10,2) NULL,                 -- 25th percentile wage
    percentile_75_wage NUMERIC(10,2) NULL,                 -- 75th percentile wage

    -- Source tracking
    data_source NVARCHAR(100) DEFAULT 'O*NET' NOT NULL,    -- Data source
    source_year INT NULL,                                   -- Year of O*NET data
    source_version NVARCHAR(20) NULL,                      -- O*NET version (e.g., 24.1)

    -- Audit columns
    created_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    updated_date DATETIME2 DEFAULT GETDATE() NOT NULL
);
GO

-- Create indexes for efficient lookups and joins
CREATE NONCLUSTERED INDEX IX_stg_onet_soc_code ON SkillStack_Staging.stg.ONET_SOCCrosswalk (soc_code);
GO

CREATE NONCLUSTERED INDEX IX_stg_onet_occupation_title ON SkillStack_Staging.stg.ONET_SOCCrosswalk (occupation_title)
    INCLUDE (soc_code, typical_entry_education);
GO

CREATE NONCLUSTERED INDEX IX_stg_onet_rapid_growth ON SkillStack_Staging.stg.ONET_SOCCrosswalk (is_rapid_growth, is_emerging)
    INCLUDE (soc_code, occupation_title);
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Staging Table stg.ONET_SOCCrosswalk Created Successfully';
PRINT '============================================================================';
GO
