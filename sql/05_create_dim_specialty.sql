-- ============================================================================
-- File: sql/05_create_dim_specialty.sql
-- Purpose: Create the dim_specialty dimension table for SkillStack_DW
-- Grain: One row per specialty (third level of hierarchy)
-- SCD Type 2: Tracks historical changes with is_current flag
-- Foreign Key: specialty_key references dim_pathway
-- CRITICAL: This dimension fixes the blocking issue with dim_badge.specialty_key
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop table if it exists (allows re-creation during development)
IF OBJECT_ID('dbo.dim_specialty', 'U') IS NOT NULL
    DROP TABLE dbo.dim_specialty;
GO

-- ============================================================================
-- CREATE TABLE: dim_specialty
-- ============================================================================
CREATE TABLE dbo.dim_specialty (
    -- ========================================================================
    -- PRIMARY KEY: Surrogate key (auto-incrementing)
    -- Starts at 0 for 'Unknown' record
    -- ========================================================================
    specialty_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- NATURAL KEY: Business key from source system
    -- ========================================================================
    specialty_id INT NOT NULL,

    -- ========================================================================
    -- FOREIGN KEY: Parent hierarchy relationship
    -- References dim_pathway for specialty grouping
    -- ========================================================================
    pathway_key INT NOT NULL,

    -- ========================================================================
    -- DESCRIPTIVE ATTRIBUTES
    -- ========================================================================
    specialty_name NVARCHAR(200) NOT NULL,
    specialty_code NVARCHAR(50) NULL,
    specialty_description NVARCHAR(MAX) NULL,
    specialty_icon_url NVARCHAR(500) NULL,
    display_order INT NULL,

    -- ========================================================================
    -- REQUIREMENTS
    -- ========================================================================
    required_badge_count INT NULL,
    required_skill_count INT NULL,

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
    -- CONSTRAINTS
    -- ========================================================================
    CONSTRAINT FK_specialty_pathway FOREIGN KEY (pathway_key)
        REFERENCES dbo.dim_pathway(pathway_key)
);

GO

-- ============================================================================
-- INDEXES: Optimized for common analytical patterns
-- ============================================================================

-- Index 1: Unique on natural key + is_current for SCD Type 2 lookups
-- Usage: MERGE operations to find current version of specialty_id
CREATE UNIQUE NONCLUSTERED INDEX IX_dim_specialty_natural_key
    ON dbo.dim_specialty (specialty_id, is_current)
    WHERE is_current = 1;
GO

-- Index 2: Foreign key to pathway for joins
-- Usage: SELECT * FROM dim_specialty WHERE pathway_key = ?
CREATE NONCLUSTERED INDEX IX_dim_specialty_pathway_key
    ON dbo.dim_specialty (pathway_key)
    WHERE is_current = 1;
GO

-- Index 3: Filter index for active specialties
-- Usage: WHERE is_active = 1 queries for current operational specialties
CREATE NONCLUSTERED INDEX IX_dim_specialty_active
    ON dbo.dim_specialty (is_active)
    WHERE is_active = 1 AND is_current = 1;
GO

-- Index 4: Display order for UI sorting
-- Usage: ORDER BY display_order for portal navigation
CREATE NONCLUSTERED INDEX IX_dim_specialty_display_order
    ON dbo.dim_specialty (display_order)
    WHERE is_current = 1;
GO

-- ============================================================================
-- INSERT UNKNOWN ROW
-- Every dimension must have an Unknown row at key=0 to handle NULL/unmapped values
-- ============================================================================
SET IDENTITY_INSERT dbo.dim_specialty ON;

INSERT INTO dbo.dim_specialty (
    specialty_key,
    specialty_id,
    pathway_key,
    specialty_name,
    specialty_code,
    specialty_description,
    is_active,
    is_current,
    dw_created_date,
    dw_updated_date
)
VALUES (
    0,                          -- specialty_key
    -1,                         -- specialty_id (natural key = -1 for Unknown)
    0,                          -- pathway_key (Unknown pathway)
    'Unknown',                  -- specialty_name
    'UNK',                      -- specialty_code
    'Unknown specialty',        -- specialty_description
    0,                          -- is_active
    1,                          -- is_current
    GETDATE(),                  -- dw_created_date
    GETDATE()                   -- dw_updated_date
);

SET IDENTITY_INSERT dbo.dim_specialty OFF;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_specialty Table Created Successfully';
PRINT '============================================================================';
PRINT 'Grain:                 One row per specialty (SCD Type 2)';
PRINT 'Clustered Index:       PK on specialty_key (IDENTITY, starts at 0)';
PRINT 'Nonclustered Indexes:  4 indexes for analytical queries';
PRINT '  - IX_dim_specialty_natural_key       (specialty_id, is_current)';
PRINT '  - IX_dim_specialty_pathway_key       (pathway_key FK)';
PRINT '  - IX_dim_specialty_active            (is_active filter)';
PRINT '  - IX_dim_specialty_display_order     (display_order)';
PRINT '';
PRINT 'Foreign Key:           FK_specialty_pathway -> dim_pathway(pathway_key)';
PRINT 'Unknown Row Inserted:  specialty_key=0, specialty_id=-1, pathway_key=0, name=Unknown';
PRINT '';

-- Verify the table and unknown row
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_specialty'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT 'Unknown row verification:';
SELECT * FROM dbo.dim_specialty WHERE specialty_key = 0;

PRINT '';
PRINT '============================================================================';
GO
