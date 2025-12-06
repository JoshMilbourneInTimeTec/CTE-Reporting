-- ============================================================================
-- File: sql/07_create_dim_institution.sql
-- Purpose: Create the dim_institution dimension table for SkillStack_DW
-- Grain: One row per educational institution
-- SCD Type 2: Tracks historical changes with is_current flag
-- Usage: Both fact_user_badges and fact_user_skills reference AwardingInstitutionId
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop table if it exists (allows re-creation during development)
IF OBJECT_ID('dbo.dim_institution', 'U') IS NOT NULL
    DROP TABLE dbo.dim_institution;
GO

-- ============================================================================
-- CREATE TABLE: dim_institution
-- ============================================================================
CREATE TABLE dbo.dim_institution (
    -- ========================================================================
    -- PRIMARY KEY: Surrogate key (auto-incrementing)
    -- Starts at 0 for 'Unknown' record
    -- ========================================================================
    institution_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- NATURAL KEY: Business key from source system
    -- ========================================================================
    institution_id INT NOT NULL,

    -- ========================================================================
    -- DESCRIPTIVE ATTRIBUTES
    -- ========================================================================
    institution_name NVARCHAR(200) NOT NULL,
    institution_type NVARCHAR(100) NULL,
    institution_code NVARCHAR(50) NULL,

    -- ========================================================================
    -- ADDRESS INFORMATION
    -- ========================================================================
    address_line1 NVARCHAR(200) NULL,
    address_line2 NVARCHAR(200) NULL,
    city NVARCHAR(100) NULL,
    state CHAR(2) NULL,
    zip_code NVARCHAR(10) NULL,

    -- ========================================================================
    -- CONTACT INFORMATION
    -- ========================================================================
    phone NVARCHAR(20) NULL,
    email NVARCHAR(100) NULL,
    website_url NVARCHAR(500) NULL,

    -- ========================================================================
    -- REGIONAL MAPPING
    -- For Idaho institutions, links to regional hierarchy
    -- ========================================================================
    region_name NVARCHAR(100) NULL,
    region_number INT NULL,

    -- ========================================================================
    -- FEDERAL IDENTIFIERS
    -- ========================================================================
    ipeds_id NVARCHAR(20) NULL,
    ope_id NVARCHAR(20) NULL,

    -- ========================================================================
    -- ACCREDITATION
    -- ========================================================================
    accreditation_status NVARCHAR(100) NULL,

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
-- Usage: MERGE operations to find current version of institution_id
CREATE UNIQUE NONCLUSTERED INDEX IX_dim_institution_natural_key
    ON dbo.dim_institution (institution_id, is_current)
    WHERE is_current = 1;
GO

-- Index 2: Filter index for active institutions
-- Usage: WHERE is_active = 1 queries for current operational institutions
CREATE NONCLUSTERED INDEX IX_dim_institution_active
    ON dbo.dim_institution (is_active)
    WHERE is_active = 1 AND is_current = 1;
GO

-- Index 3: Regional analysis
-- Usage: WHERE region_number = ? for regional institution reporting
CREATE NONCLUSTERED INDEX IX_dim_institution_region
    ON dbo.dim_institution (region_number)
    WHERE is_current = 1 AND region_number IS NOT NULL;
GO

-- Index 4: City/State for geographic queries
-- Usage: WHERE state = 'ID' for state-level reporting
CREATE NONCLUSTERED INDEX IX_dim_institution_location
    ON dbo.dim_institution (state, city)
    WHERE is_current = 1;
GO

-- ============================================================================
-- INSERT UNKNOWN ROW
-- Every dimension must have an Unknown row at key=0 to handle NULL/unmapped values
-- ============================================================================
SET IDENTITY_INSERT dbo.dim_institution ON;

INSERT INTO dbo.dim_institution (
    institution_key,
    institution_id,
    institution_name,
    institution_code,
    is_active,
    is_current,
    dw_created_date,
    dw_updated_date
)
VALUES (
    0,                          -- institution_key
    -1,                         -- institution_id (natural key = -1 for Unknown)
    'Unknown',                  -- institution_name
    'UNK',                      -- institution_code
    0,                          -- is_active
    1,                          -- is_current
    GETDATE(),                  -- dw_created_date
    GETDATE()                   -- dw_updated_date
);

SET IDENTITY_INSERT dbo.dim_institution OFF;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_institution Table Created Successfully';
PRINT '============================================================================';
PRINT 'Grain:                 One row per educational institution (SCD Type 2)';
PRINT 'Clustered Index:       PK on institution_key (IDENTITY, starts at 0)';
PRINT 'Nonclustered Indexes:  4 indexes for analytical queries';
PRINT '  - IX_dim_institution_natural_key    (institution_id, is_current)';
PRINT '  - IX_dim_institution_active         (is_active filter)';
PRINT '  - IX_dim_institution_region         (region_number)';
PRINT '  - IX_dim_institution_location       (state, city)';
PRINT '';
PRINT 'Usage:                 Fact tables (fact_user_badges, fact_user_skills)';
PRINT '                       reference AwardingInstitutionId';
PRINT 'Unknown Row Inserted:  institution_key=0, institution_id=-1, name=Unknown';
PRINT '';

-- Verify the table and unknown row
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_institution'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT 'Unknown row verification:';
SELECT * FROM dbo.dim_institution WHERE institution_key = 0;

PRINT '';
PRINT '============================================================================';
GO
