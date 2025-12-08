-- ============================================================================
-- File: sql/09_create_dim_career_group.sql
-- Purpose: Create the dim_career_group dimension table for SkillStack_DW
-- Phase: Phase 3 - Labor Market Alignment
-- Grain: One row per career group (hierarchical grouping of careers)
-- SCD Type 2: Tracks historical changes with is_current flag
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop table if it exists (allows re-creation during development)
IF OBJECT_ID('dbo.dim_career_group', 'U') IS NOT NULL
    DROP TABLE dbo.dim_career_group;
GO

-- ============================================================================
-- CREATE TABLE: dim_career_group
-- ============================================================================
CREATE TABLE dbo.dim_career_group (
    -- ========================================================================
    -- PRIMARY KEY: Surrogate key (auto-incrementing)
    -- Starts at 0 for 'Unknown' record
    -- ========================================================================
    career_group_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- NATURAL KEY: Business key from source system
    -- ========================================================================
    career_group_id INT NOT NULL,

    -- ========================================================================
    -- DESCRIPTIVE ATTRIBUTES
    -- ========================================================================
    career_group_name NVARCHAR(255) NOT NULL,
    career_group_description NVARCHAR(MAX) NULL,
    display_order INT NULL,

    -- ========================================================================
    -- STATUS
    -- ========================================================================
    is_active BIT NOT NULL DEFAULT 1,

    -- ========================================================================
    -- SCD TYPE 2 ATTRIBUTES
    -- Tracks: is_current (current row flag), effective_date, expiration_date
    -- ========================================================================
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,

    -- ========================================================================
    -- AUDIT FIELDS
    -- ========================================================================
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE()
);

GO

-- ============================================================================
-- INDEXES: Optimized for common analytical patterns
-- ============================================================================

-- Index 1: Unique on natural key + is_current for SCD Type 2 lookups
-- Usage: MERGE operations to find current version of career_group_id
CREATE UNIQUE NONCLUSTERED INDEX IX_dim_career_group_natural_key
    ON dbo.dim_career_group (career_group_id, is_current)
    WHERE is_current = 1;
GO

-- Index 2: Filter index for active career groups
-- Usage: WHERE is_active = 1 queries for current operational career groups
CREATE NONCLUSTERED INDEX IX_dim_career_group_active
    ON dbo.dim_career_group (is_active)
    WHERE is_active = 1 AND is_current = 1;
GO

-- Index 3: Display order for UI sorting
-- Usage: ORDER BY display_order for portal/dashboard navigation
CREATE NONCLUSTERED INDEX IX_dim_career_group_display_order
    ON dbo.dim_career_group (display_order)
    WHERE is_current = 1;
GO

-- ============================================================================
-- INSERT UNKNOWN ROW
-- Every dimension must have an Unknown row at key=0 to handle NULL/unmapped values
-- ============================================================================
SET IDENTITY_INSERT dbo.dim_career_group ON;

INSERT INTO dbo.dim_career_group (
    career_group_key,
    career_group_id,
    career_group_name,
    career_group_description,
    is_active,
    is_current,
    dw_created_date,
    dw_updated_date
)
VALUES (
    0,                              -- career_group_key
    -1,                             -- career_group_id (natural key = -1 for Unknown)
    'Unknown',                      -- career_group_name
    'Unknown career group',         -- career_group_description
    0,                              -- is_active
    1,                              -- is_current
    GETDATE(),                      -- dw_created_date
    GETDATE()                       -- dw_updated_date
);

SET IDENTITY_INSERT dbo.dim_career_group OFF;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_career_group Table Created Successfully';
PRINT '============================================================================';
PRINT 'Grain:                 One row per career group (SCD Type 2)';
PRINT 'Clustered Index:       PK on career_group_key (IDENTITY, starts at 0)';
PRINT 'Nonclustered Indexes:  3 indexes for analytical queries';
PRINT '  - IX_dim_career_group_natural_key    (career_group_id, is_current)';
PRINT '  - IX_dim_career_group_active         (is_active filter)';
PRINT '  - IX_dim_career_group_display_order  (display_order)';
PRINT '';
PRINT 'Unknown Row Inserted:  career_group_key=0, career_group_id=-1, name=Unknown';
PRINT '';

-- Verify the table and unknown row
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_career_group'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT 'Unknown row verification:';
SELECT * FROM dbo.dim_career_group WHERE career_group_key = 0;

PRINT '';
PRINT '============================================================================';
GO
