-- ============================================================================
-- File: sql/17_create_dim_skill_set.sql
-- Purpose: Create dim_skill_set dimension for skill groupings and competencies
-- Phase: Phase 4 - Classification & Workflow Dimensions
-- Grain: One row per skill set (SCD Type 2)
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- ============================================================================
-- DROP EXISTING TABLE (allows re-creation during development)
-- ============================================================================
IF OBJECT_ID('dbo.dim_skill_set', 'U') IS NOT NULL
    DROP TABLE dbo.dim_skill_set;
GO

-- ============================================================================
-- CREATE TABLE: dim_skill_set
-- ============================================================================
CREATE TABLE dbo.dim_skill_set (
    -- ========================================================================
    -- PRIMARY KEY: Surrogate key for dimensional analysis
    -- ========================================================================
    skill_set_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- NATURAL KEY: Business identifier from source system
    -- ========================================================================
    skill_set_id INT NOT NULL,

    -- ========================================================================
    -- DESCRIPTIVE ATTRIBUTES: Skill set characteristics
    -- ========================================================================
    skill_set_name NVARCHAR(256) NOT NULL,
    skill_set_description NVARCHAR(MAX) NULL,

    -- Classification and competency
    skill_set_type NVARCHAR(100) NULL,           -- e.g., "Badge-Specific", "Category"
    competency_level NVARCHAR(100) NULL,         -- e.g., "Beginner", "Intermediate", "Advanced"

    -- Organizational
    parent_skill_set_key INT NULL,              -- Self-referencing FK for hierarchy
    display_order INT NULL,                     -- Sort order for UI presentation

    -- ========================================================================
    -- STATUS COLUMNS
    -- ========================================================================
    is_active BIT NOT NULL DEFAULT 1,           -- Current active status

    -- ========================================================================
    -- SLOWLY CHANGING DIMENSION TYPE 2: Track historical changes
    -- ========================================================================
    is_current BIT NOT NULL DEFAULT 1,          -- 1 = current version, 0 = historical
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),  -- When record became effective
    expiration_date DATETIME2 NULL,             -- When record expired (NULL = still current)

    -- ========================================================================
    -- AUDIT COLUMNS: Data warehouse tracking
    -- ========================================================================
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- ========================================================================
    -- CONSTRAINTS: Data integrity and uniqueness
    -- ========================================================================
    CONSTRAINT UQ_skill_set_natural_key UNIQUE NONCLUSTERED (skill_set_id, is_current),
    CONSTRAINT FK_skill_set_parent FOREIGN KEY (parent_skill_set_key)
        REFERENCES dbo.dim_skill_set(skill_set_key)
);
GO

-- ============================================================================
-- INDEXES: Optimized for analytical query patterns
-- ============================================================================

-- Index 1: Natural key lookup (essential for SCD Type 2 joins)
CREATE UNIQUE NONCLUSTERED INDEX IX_dim_skill_set_natural_key
    ON dbo.dim_skill_set(skill_set_id, is_current)
    INCLUDE (skill_set_key, skill_set_name);
GO

-- Index 2: Active skill set filtering (common report query)
CREATE NONCLUSTERED INDEX IX_dim_skill_set_active
    ON dbo.dim_skill_set(is_active, is_current)
    INCLUDE (skill_set_key, skill_set_name)
    WHERE is_active = 1 AND is_current = 1;
GO

-- Index 3: Parent hierarchy navigation
CREATE NONCLUSTERED INDEX IX_dim_skill_set_parent
    ON dbo.dim_skill_set(parent_skill_set_key)
    INCLUDE (skill_set_key, skill_set_name, is_current)
    WHERE parent_skill_set_key IS NOT NULL;
GO

-- ============================================================================
-- INSERT UNKNOWN ROW: Required for all dimensions (SCD Type 2)
-- ============================================================================
-- Unknown row represents NULL/unmapped skill set values
-- Key: 0 (surrogate), ID: -1 (natural key), Name: 'Unknown'
SET IDENTITY_INSERT dbo.dim_skill_set ON;
INSERT INTO dbo.dim_skill_set (
    skill_set_key, skill_set_id, skill_set_name, skill_set_description, skill_set_type,
    competency_level, parent_skill_set_key, display_order, is_active, is_current,
    effective_date, expiration_date, dw_created_date, dw_updated_date
)
VALUES (
    0, -1, 'Unknown', 'Unknown skill set', NULL,
    NULL, NULL, NULL, 0, 1,
    GETDATE(), NULL, GETDATE(), GETDATE()
);
SET IDENTITY_INSERT dbo.dim_skill_set OFF;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_skill_set Table Created Successfully';
PRINT '============================================================================';
PRINT 'Table: dbo.dim_skill_set';
PRINT 'Purpose: Skill set groupings and competency levels';
PRINT '';
PRINT 'Schema:';
PRINT '  - skill_set_key: PK surrogate key (IDENTITY 0,1)';
PRINT '  - skill_set_id: Natural key from source BDG_SkillSets';
PRINT '  - skill_set_name: Skill set name (NOT NULL)';
PRINT '  - skill_set_description: Skill set description (nullable)';
PRINT '  - skill_set_type: Type classification (nullable)';
PRINT '  - competency_level: Competency level (nullable)';
PRINT '  - parent_skill_set_key: Self-referencing FK for hierarchy';
PRINT '  - display_order: Sort order (nullable)';
PRINT '  - is_active: Active status (BIT)';
PRINT '  - is_current: SCD Type 2 current flag (BIT)';
PRINT '  - effective_date: SCD Type 2 effective date (DATETIME2)';
PRINT '  - expiration_date: SCD Type 2 expiration date (nullable)';
PRINT '  - dw_created_date: DW audit timestamp';
PRINT '  - dw_updated_date: DW audit timestamp';
PRINT '';
PRINT 'Indexes:';
PRINT '  - PK Clustered: skill_set_key';
PRINT '  - IX_dim_skill_set_natural_key: (skill_set_id, is_current) unique';
PRINT '  - IX_dim_skill_set_active: (is_active, is_current) filtered';
PRINT '  - IX_dim_skill_set_parent: (parent_skill_set_key) for hierarchy';
PRINT '';
PRINT 'Initial Data:';
PRINT '  - 1 Unknown row (skill_set_key=0, skill_set_id=-1)';
PRINT '';
PRINT '============================================================================';
GO
