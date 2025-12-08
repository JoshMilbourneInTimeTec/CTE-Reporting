-- ============================================================================
-- File: sql/22_create_ctl_career_group_mapping.sql
-- Purpose: Create control table for Career-to-CareerGroup mapping logic
-- Phase: Phase 3.5 - Labor Market Data Integration
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop if exists
IF OBJECT_ID('SkillStack_Control.ctl.CareerGroupMapping', 'U') IS NOT NULL
    DROP TABLE SkillStack_Control.ctl.CareerGroupMapping;
GO

-- Create control table for career group mappings
CREATE TABLE SkillStack_Control.ctl.CareerGroupMapping (
    -- Identification
    mapping_id INT IDENTITY(1,1) PRIMARY KEY,
    career_id INT NOT NULL,                                 -- FK to dim_career source ID
    career_group_id INT NOT NULL,                           -- FK to dim_career_group source ID

    -- Mapping details
    mapping_rule_name NVARCHAR(256) NOT NULL,              -- Human-readable rule name
    mapping_confidence NUMERIC(3,2) NOT NULL,              -- Confidence score (0.00-1.00)
    mapping_method NVARCHAR(50) NOT NULL,                  -- 'Business Logic', 'SOC Based', 'Manual', 'Algorithm'

    -- Classification
    is_primary_mapping BIT DEFAULT 1 NOT NULL,             -- Is this the primary group for career
    priority_order INT DEFAULT 1 NOT NULL,                 -- Order if multiple mappings (1=highest)

    -- Validation
    mapping_status NVARCHAR(20) DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE, PENDING_REVIEW, REJECTED, OVERRIDE
    validation_notes NVARCHAR(MAX) NULL,                   -- Notes on validation/review

    -- Source data
    source_soc_code NVARCHAR(8) NULL,                      -- SOC code used for mapping
    source_occupation_title NVARCHAR(256) NULL,            -- Occupation title used for mapping
    source_skills_matched INT NULL,                        -- Number of skills matched

    -- Audit
    created_by NVARCHAR(100) DEFAULT USER_NAME() NOT NULL,
    created_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    updated_by NVARCHAR(100) DEFAULT USER_NAME() NOT NULL,
    updated_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    reviewed_by NVARCHAR(100) NULL,
    reviewed_date DATETIME2 NULL,

    -- Constraints
    CONSTRAINT UC_career_group_mapping UNIQUE (career_id, career_group_id, is_primary_mapping)
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_ctl_career_id ON SkillStack_Control.ctl.CareerGroupMapping (career_id)
    INCLUDE (career_group_id, is_primary_mapping, mapping_status);
GO

CREATE NONCLUSTERED INDEX IX_ctl_career_group_id ON SkillStack_Control.ctl.CareerGroupMapping (career_group_id)
    INCLUDE (career_id, mapping_status);
GO

CREATE NONCLUSTERED INDEX IX_ctl_mapping_status ON SkillStack_Control.ctl.CareerGroupMapping (mapping_status)
    INCLUDE (career_id, career_group_id, mapping_confidence);
GO

CREATE NONCLUSTERED INDEX IX_ctl_primary_mapping ON SkillStack_Control.ctl.CareerGroupMapping (is_primary_mapping, mapping_status)
    WHERE is_primary_mapping = 1;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Control Table ctl.CareerGroupMapping Created Successfully';
PRINT '============================================================================';
GO
