-- ============================================================================
-- File: sql/03_create_dim_cluster.sql
-- Purpose: Create the dim_cluster dimension table for SkillStack_DW
-- Grain: One row per career cluster (top of badge/skill hierarchy)
-- SCD Type 2: Tracks historical changes with is_current flag
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop table if it exists (allows re-creation during development)
IF OBJECT_ID('dbo.dim_cluster', 'U') IS NOT NULL
    DROP TABLE dbo.dim_cluster;
GO

-- ============================================================================
-- CREATE TABLE: dim_cluster
-- ============================================================================
CREATE TABLE dbo.dim_cluster (
    -- ========================================================================
    -- PRIMARY KEY: Surrogate key (auto-incrementing)
    -- Starts at 0 for 'Unknown' record
    -- ========================================================================
    cluster_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- NATURAL KEY: Business key from source system
    -- ========================================================================
    cluster_id INT NOT NULL,

    -- ========================================================================
    -- DESCRIPTIVE ATTRIBUTES
    -- ========================================================================
    cluster_name NVARCHAR(200) NOT NULL,
    cluster_code NVARCHAR(50) NULL,
    cluster_description NVARCHAR(MAX) NULL,
    cluster_icon_url NVARCHAR(500) NULL,
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
-- Usage: MERGE operations to find current version of cluster_id
CREATE UNIQUE NONCLUSTERED INDEX IX_dim_cluster_natural_key
    ON dbo.dim_cluster (cluster_id, is_current)
    WHERE is_current = 1;
GO

-- Index 2: Filter index for active clusters
-- Usage: WHERE is_active = 1 queries for current operational clusters
CREATE NONCLUSTERED INDEX IX_dim_cluster_active
    ON dbo.dim_cluster (is_active)
    WHERE is_active = 1 AND is_current = 1;
GO

-- Index 3: Display order for UI sorting
-- Usage: ORDER BY display_order for portal/dashboard navigation
CREATE NONCLUSTERED INDEX IX_dim_cluster_display_order
    ON dbo.dim_cluster (display_order)
    WHERE is_current = 1;
GO

-- ============================================================================
-- INSERT UNKNOWN ROW
-- Every dimension must have an Unknown row at key=0 to handle NULL/unmapped values
-- ============================================================================
SET IDENTITY_INSERT dbo.dim_cluster ON;

INSERT INTO dbo.dim_cluster (
    cluster_key,
    cluster_id,
    cluster_name,
    cluster_code,
    cluster_description,
    is_active,
    is_current,
    dw_created_date,
    dw_updated_date
)
VALUES (
    0,                          -- cluster_key
    -1,                         -- cluster_id (natural key = -1 for Unknown)
    'Unknown',                  -- cluster_name
    'UNK',                      -- cluster_code
    'Unknown cluster',          -- cluster_description
    0,                          -- is_active
    1,                          -- is_current
    GETDATE(),                  -- dw_created_date
    GETDATE()                   -- dw_updated_date
);

SET IDENTITY_INSERT dbo.dim_cluster OFF;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_cluster Table Created Successfully';
PRINT '============================================================================';
PRINT 'Grain:                 One row per career cluster (SCD Type 2)';
PRINT 'Clustered Index:       PK on cluster_key (IDENTITY, starts at 0)';
PRINT 'Nonclustered Indexes:  3 indexes for analytical queries';
PRINT '  - IX_dim_cluster_natural_key         (cluster_id, is_current)';
PRINT '  - IX_dim_cluster_active              (is_active filter)';
PRINT '  - IX_dim_cluster_display_order       (display_order)';
PRINT '';
PRINT 'Unknown Row Inserted:  cluster_key=0, cluster_id=-1, name=Unknown';
PRINT '';

-- Verify the table and unknown row
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_cluster'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT 'Unknown row verification:';
SELECT * FROM dbo.dim_cluster WHERE cluster_key = 0;

PRINT '';
PRINT '============================================================================';
GO
