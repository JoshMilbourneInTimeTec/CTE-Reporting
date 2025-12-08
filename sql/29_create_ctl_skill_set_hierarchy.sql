-- ============================================================================
-- File: sql/29_create_ctl_skill_set_hierarchy.sql
-- Purpose: Create control table for skill set hierarchy and relationships
-- Phase: Phase 4.5 - Workflow & UI Enhancement
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop if exists
IF OBJECT_ID('SkillStack_Control.ctl.SkillSetHierarchy', 'U') IS NOT NULL
    DROP TABLE SkillStack_Control.ctl.SkillSetHierarchy;
GO

-- Create control table for skill set hierarchy
CREATE TABLE SkillStack_Control.ctl.SkillSetHierarchy (
    -- Identification
    hierarchy_id INT IDENTITY(1,1) PRIMARY KEY,
    skill_set_key INT NOT NULL,                            -- FK to dim_skill_set
    parent_skill_set_key INT NULL,                         -- FK to parent dim_skill_set (self-referencing)

    -- Hierarchy positioning
    hierarchy_depth INT DEFAULT 1 NOT NULL,                -- Nesting level (1=root, 2=child, etc.)
    hierarchy_sequence INT DEFAULT 1 NOT NULL,             -- Order within parent (1, 2, 3...)
    path_to_root NVARCHAR(MAX) NULL,                       -- Breadcrumb path for navigation

    -- Competency progression
    competency_level_from INT DEFAULT 1 NOT NULL,          -- Starting competency level (1-5)
    competency_level_to INT DEFAULT 1 NOT NULL,            -- Ending competency level (1-5)
    progression_order INT DEFAULT 1 NOT NULL,              -- Skill mastery progression order

    -- Relationships
    prerequisite_skill_set_key INT NULL,                   -- Skill set that must be completed first
    related_skill_set_key INT NULL,                        -- Related skill set (not prerequisite)
    dependency_count INT DEFAULT 0 NOT NULL,               -- Number of dependent skill sets

    -- Learning characteristics
    estimated_hours_to_mastery INT NULL,                   -- Hours to master this level
    difficulty_level INT DEFAULT 1 NOT NULL,               -- 1=Beginner, 2=Intermediate, 3=Advanced, 4=Expert
    typical_learner_duration_weeks INT NULL,               -- Typical learning duration

    -- Assessment and validation
    requires_assessment BIT DEFAULT 0 NOT NULL,            -- Requires formal assessment
    assessment_method NVARCHAR(100) NULL,                  -- 'Practical', 'Written', 'Portfolio', 'Certification'
    passing_score_percentage INT DEFAULT 70 NOT NULL,      -- Required passing score

    -- Configuration
    is_active BIT DEFAULT 1 NOT NULL,                      -- Configuration active
    hierarchy_status NVARCHAR(20) DEFAULT 'ACTIVE' NOT NULL, -- 'ACTIVE', 'PROPOSED', 'ARCHIVED'
    is_core_skill_set BIT DEFAULT 0 NOT NULL,              -- Essential for all learners

    -- Audit
    created_by NVARCHAR(100) DEFAULT USER_NAME() NOT NULL,
    created_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    updated_by NVARCHAR(100) DEFAULT USER_NAME() NOT NULL,
    updated_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    hierarchy_notes NVARCHAR(MAX) NULL,

    -- Constraints
    CONSTRAINT FK_skill_set_parent FOREIGN KEY (parent_skill_set_key) REFERENCES dbo.dim_skill_set(skill_set_key)
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_ctl_skill_set_key ON SkillStack_Control.ctl.SkillSetHierarchy (skill_set_key)
    INCLUDE (parent_skill_set_key, hierarchy_depth, hierarchy_status);
GO

CREATE NONCLUSTERED INDEX IX_ctl_parent_skill_set ON SkillStack_Control.ctl.SkillSetHierarchy (parent_skill_set_key)
    INCLUDE (skill_set_key, hierarchy_sequence);
GO

CREATE NONCLUSTERED INDEX IX_ctl_hierarchy_depth ON SkillStack_Control.ctl.SkillSetHierarchy (hierarchy_depth, hierarchy_status)
    WHERE hierarchy_status = 'ACTIVE';
GO

CREATE NONCLUSTERED INDEX IX_ctl_prerequisite ON SkillStack_Control.ctl.SkillSetHierarchy (prerequisite_skill_set_key)
    INCLUDE (skill_set_key, progression_order);
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Control Table ctl.SkillSetHierarchy Created Successfully';
PRINT '============================================================================';
GO
