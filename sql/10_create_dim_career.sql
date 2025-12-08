-- ============================================================================
-- File: sql/10_create_dim_career.sql
-- Purpose: Create the dim_career dimension table for SkillStack_DW
-- Phase: Phase 3 - Labor Market Alignment
-- Grain: One row per career (SCD Type 2)
-- Dependencies: dim_career_group (for FK constraint)
-- SCD Type 2: Tracks historical changes with is_current flag
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop table if it exists (allows re-creation during development)
IF OBJECT_ID('dbo.dim_career', 'U') IS NOT NULL
    DROP TABLE dbo.dim_career;
GO

-- ============================================================================
-- CREATE TABLE: dim_career
-- ============================================================================
CREATE TABLE dbo.dim_career (
    -- ========================================================================
    -- PRIMARY KEY: Surrogate key (auto-incrementing)
    -- Starts at 0 for 'Unknown' record
    -- ========================================================================
    career_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- NATURAL KEY: Business key from source system
    -- ========================================================================
    career_id INT NOT NULL,
    career_guid UNIQUEIDENTIFIER NULL,

    -- ========================================================================
    -- FOREIGN KEYS: Relationships to other dimensions
    -- ========================================================================
    career_group_key INT NULL,           -- FK to dim_career_group

    -- ========================================================================
    -- DESCRIPTIVE ATTRIBUTES
    -- ========================================================================
    career_name NVARCHAR(255) NOT NULL,
    career_description NVARCHAR(MAX) NULL,
    career_group_name NVARCHAR(255) NULL,   -- Denormalized from dim_career_group

    -- ========================================================================
    -- LABOR MARKET DATA
    -- ========================================================================
    median_salary NUMERIC(12,2) NULL,
    job_outlook_percentage NUMERIC(5,2) NULL,
    typical_education_level NVARCHAR(100) NULL,
    is_high_demand BIT DEFAULT 0,
    priority_ordering INT NULL,

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
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- ========================================================================
    -- CONSTRAINTS: Foreign keys and relationships
    -- ========================================================================
    CONSTRAINT FK_career_career_group FOREIGN KEY (career_group_key)
        REFERENCES dbo.dim_career_group(career_group_key)
);

GO

-- ============================================================================
-- INDEXES: Optimized for common analytical patterns
-- ============================================================================

-- Index 1: Unique on natural key + is_current for SCD Type 2 lookups
-- Usage: MERGE operations to find current version of career_id
CREATE UNIQUE NONCLUSTERED INDEX IX_dim_career_natural_key
    ON dbo.dim_career (career_id, is_current)
    WHERE is_current = 1;
GO

-- Index 2: Foreign key index for career_group_key joins
-- Usage: JOIN to dim_career_group for career group reporting
CREATE NONCLUSTERED INDEX IX_dim_career_career_group_key
    ON dbo.dim_career (career_group_key)
    WHERE is_current = 1;
GO

-- Index 3: Filter index for active careers
-- Usage: WHERE is_active = 1 queries for current operational careers
CREATE NONCLUSTERED INDEX IX_dim_career_active
    ON dbo.dim_career (is_active)
    WHERE is_active = 1 AND is_current = 1;
GO

-- Index 4: High demand careers for filtering
-- Usage: WHERE is_high_demand = 1 for in-demand career analysis
CREATE NONCLUSTERED INDEX IX_dim_career_high_demand
    ON dbo.dim_career (is_high_demand)
    WHERE is_high_demand = 1 AND is_current = 1;
GO

-- ============================================================================
-- INSERT UNKNOWN ROW
-- Every dimension must have an Unknown row at key=0 to handle NULL/unmapped values
-- ============================================================================
SET IDENTITY_INSERT dbo.dim_career ON;

INSERT INTO dbo.dim_career (
    career_key,
    career_id,
    career_guid,
    career_group_key,
    career_name,
    career_description,
    career_group_name,
    is_active,
    is_current,
    dw_created_date,
    dw_updated_date
)
VALUES (
    0,                              -- career_key
    -1,                             -- career_id (natural key = -1 for Unknown)
    NULL,                           -- career_guid
    0,                              -- career_group_key (Unknown)
    'Unknown',                      -- career_name
    'Unknown career',               -- career_description
    'Unknown',                      -- career_group_name
    0,                              -- is_active
    1,                              -- is_current
    GETDATE(),                      -- dw_created_date
    GETDATE()                       -- dw_updated_date
);

SET IDENTITY_INSERT dbo.dim_career OFF;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_career Table Created Successfully';
PRINT '============================================================================';
PRINT 'Grain:                 One row per career (SCD Type 2)';
PRINT 'Clustered Index:       PK on career_key (IDENTITY, starts at 0)';
PRINT 'Nonclustered Indexes:  4 indexes for analytical queries';
PRINT '  - IX_dim_career_natural_key          (career_id, is_current)';
PRINT '  - IX_dim_career_career_group_key     (career_group_key FK)';
PRINT '  - IX_dim_career_active               (is_active filter)';
PRINT '  - IX_dim_career_high_demand          (is_high_demand filter)';
PRINT '';
PRINT 'Foreign Keys:';
PRINT '  - FK_career_career_group → dim_career_group(career_group_key)';
PRINT '';
PRINT 'Unknown Row Inserted:  career_key=0, career_id=-1, name=Unknown';
PRINT '';

-- Verify the table and unknown row
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_career'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT 'Unknown row verification:';
SELECT * FROM dbo.dim_career WHERE career_key = 0;

PRINT '';
PRINT '============================================================================';
GO
