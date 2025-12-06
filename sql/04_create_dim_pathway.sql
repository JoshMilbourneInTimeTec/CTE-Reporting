-- ============================================================================
-- File: sql/04_create_dim_pathway.sql
-- Purpose: Create the dim_pathway dimension table for SkillStack_DW
-- Grain: One row per career pathway (second level of hierarchy)
-- SCD Type 2: Tracks historical changes with is_current flag
-- Foreign Key: pathway_key references dim_cluster
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop table if it exists (allows re-creation during development)
IF OBJECT_ID('dbo.dim_pathway', 'U') IS NOT NULL
    DROP TABLE dbo.dim_pathway;
GO

-- ============================================================================
-- CREATE TABLE: dim_pathway
-- ============================================================================
CREATE TABLE dbo.dim_pathway (
    -- ========================================================================
    -- PRIMARY KEY: Surrogate key (auto-incrementing)
    -- Starts at 0 for 'Unknown' record
    -- ========================================================================
    pathway_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- NATURAL KEY: Business key from source system
    -- ========================================================================
    pathway_id INT NOT NULL,

    -- ========================================================================
    -- FOREIGN KEY: Parent hierarchy relationship
    -- References dim_cluster for pathway grouping
    -- ========================================================================
    cluster_key INT NOT NULL,

    -- ========================================================================
    -- DESCRIPTIVE ATTRIBUTES
    -- ========================================================================
    pathway_name NVARCHAR(200) NOT NULL,
    pathway_code NVARCHAR(50) NULL,
    pathway_description NVARCHAR(MAX) NULL,
    pathway_icon_url NVARCHAR(500) NULL,
    display_order INT NULL,

    -- ========================================================================
    -- CAREER ALIGNMENT
    -- CIP = Classification of Instructional Programs (U.S. standard)
    -- ========================================================================
    cip_code NVARCHAR(20) NULL,

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
    CONSTRAINT FK_pathway_cluster FOREIGN KEY (cluster_key)
        REFERENCES dbo.dim_cluster(cluster_key)
);

GO

-- ============================================================================
-- INDEXES: Optimized for common analytical patterns
-- ============================================================================

-- Index 1: Unique on natural key + is_current for SCD Type 2 lookups
-- Usage: MERGE operations to find current version of pathway_id
CREATE UNIQUE NONCLUSTERED INDEX IX_dim_pathway_natural_key
    ON dbo.dim_pathway (pathway_id, is_current)
    WHERE is_current = 1;
GO

-- Index 2: Foreign key to cluster for joins
-- Usage: SELECT * FROM dim_pathway WHERE cluster_key = ?
CREATE NONCLUSTERED INDEX IX_dim_pathway_cluster_key
    ON dbo.dim_pathway (cluster_key)
    WHERE is_current = 1;
GO

-- Index 3: Filter index for active pathways
-- Usage: WHERE is_active = 1 queries for current operational pathways
CREATE NONCLUSTERED INDEX IX_dim_pathway_active
    ON dbo.dim_pathway (is_active)
    WHERE is_active = 1 AND is_current = 1;
GO

-- Index 4: Display order for UI sorting
-- Usage: ORDER BY display_order for portal navigation
CREATE NONCLUSTERED INDEX IX_dim_pathway_display_order
    ON dbo.dim_pathway (display_order)
    WHERE is_current = 1;
GO

-- ============================================================================
-- INSERT UNKNOWN ROW
-- Every dimension must have an Unknown row at key=0 to handle NULL/unmapped values
-- ============================================================================
SET IDENTITY_INSERT dbo.dim_pathway ON;

INSERT INTO dbo.dim_pathway (
    pathway_key,
    pathway_id,
    cluster_key,
    pathway_name,
    pathway_code,
    pathway_description,
    is_active,
    is_current,
    dw_created_date,
    dw_updated_date
)
VALUES (
    0,                          -- pathway_key
    -1,                         -- pathway_id (natural key = -1 for Unknown)
    0,                          -- cluster_key (Unknown cluster)
    'Unknown',                  -- pathway_name
    'UNK',                      -- pathway_code
    'Unknown pathway',          -- pathway_description
    0,                          -- is_active
    1,                          -- is_current
    GETDATE(),                  -- dw_created_date
    GETDATE()                   -- dw_updated_date
);

SET IDENTITY_INSERT dbo.dim_pathway OFF;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_pathway Table Created Successfully';
PRINT '============================================================================';
PRINT 'Grain:                 One row per career pathway (SCD Type 2)';
PRINT 'Clustered Index:       PK on pathway_key (IDENTITY, starts at 0)';
PRINT 'Nonclustered Indexes:  4 indexes for analytical queries';
PRINT '  - IX_dim_pathway_natural_key         (pathway_id, is_current)';
PRINT '  - IX_dim_pathway_cluster_key         (cluster_key FK)';
PRINT '  - IX_dim_pathway_active              (is_active filter)';
PRINT '  - IX_dim_pathway_display_order       (display_order)';
PRINT '';
PRINT 'Foreign Key:           FK_pathway_cluster -> dim_cluster(cluster_key)';
PRINT 'Unknown Row Inserted:  pathway_key=0, pathway_id=-1, cluster_key=0, name=Unknown';
PRINT '';

-- Verify the table and unknown row
SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_pathway'
ORDER BY ORDINAL_POSITION;

PRINT '';
PRINT 'Unknown row verification:';
SELECT * FROM dbo.dim_pathway WHERE pathway_key = 0;

PRINT '';
PRINT 'Foreign key verification:';
SELECT
    CONSTRAINT_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    REFERENCED_TABLE_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'dim_pathway';

PRINT '';
PRINT '============================================================================';
GO
