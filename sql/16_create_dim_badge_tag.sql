-- ============================================================================
-- File: sql/16_create_dim_badge_tag.sql
-- Purpose: Create dim_badge_tag dimension for badge classification and discovery
-- Phase: Phase 4 - Classification & Workflow Dimensions
-- Grain: One row per badge tag (SCD Type 2)
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- ============================================================================
-- DROP EXISTING TABLE (allows re-creation during development)
-- ============================================================================
IF OBJECT_ID('dbo.dim_badge_tag', 'U') IS NOT NULL
    DROP TABLE dbo.dim_badge_tag;
GO

-- ============================================================================
-- CREATE TABLE: dim_badge_tag
-- ============================================================================
CREATE TABLE dbo.dim_badge_tag (
    -- ========================================================================
    -- PRIMARY KEY: Surrogate key for dimensional analysis
    -- ========================================================================
    tag_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- NATURAL KEY: Business identifier from source system
    -- ========================================================================
    tag_id INT NOT NULL,

    -- ========================================================================
    -- DESCRIPTIVE ATTRIBUTES: Tag characteristics for classification
    -- ========================================================================
    tag_name NVARCHAR(256) NOT NULL,
    tag_description NVARCHAR(MAX) NULL,

    -- UI/Display attributes for flexible categorization
    tag_category NVARCHAR(100) NULL,           -- e.g., "Assessment", "Duration", "Level"
    tag_color_code VARCHAR(7) NULL,            -- Hex color code for UI display
    display_order INT NULL,                    -- Sort order for UI presentation

    -- ========================================================================
    -- STATUS COLUMNS
    -- ========================================================================
    is_active BIT NOT NULL DEFAULT 1,          -- Current active status

    -- ========================================================================
    -- SLOWLY CHANGING DIMENSION TYPE 2: Track historical changes
    -- ========================================================================
    is_current BIT NOT NULL DEFAULT 1,         -- 1 = current version, 0 = historical
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),  -- When record became effective
    expiration_date DATETIME2 NULL,            -- When record expired (NULL = still current)

    -- ========================================================================
    -- AUDIT COLUMNS: Data warehouse tracking
    -- ========================================================================
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- ========================================================================
    -- CONSTRAINTS: Data integrity and uniqueness
    -- ========================================================================
    CONSTRAINT UQ_tag_natural_key UNIQUE NONCLUSTERED (tag_id, is_current)
);
GO

-- ============================================================================
-- INDEXES: Optimized for analytical query patterns
-- ============================================================================

-- Index 1: Natural key lookup (essential for SCD Type 2 joins)
CREATE UNIQUE NONCLUSTERED INDEX IX_dim_badge_tag_natural_key
    ON dbo.dim_badge_tag(tag_id, is_current)
    INCLUDE (tag_key, tag_name);
GO

-- Index 2: Active tag filtering (common report query)
CREATE NONCLUSTERED INDEX IX_dim_badge_tag_active
    ON dbo.dim_badge_tag(is_active, is_current)
    INCLUDE (tag_key, tag_name)
    WHERE is_active = 1 AND is_current = 1;
GO

-- Index 3: Display order for UI sorting
CREATE NONCLUSTERED INDEX IX_dim_badge_tag_display_order
    ON dbo.dim_badge_tag(display_order, tag_key)
    INCLUDE (tag_name);
GO

-- ============================================================================
-- INSERT UNKNOWN ROW: Required for all dimensions (SCD Type 2)
-- ============================================================================
-- Unknown row represents NULL/unmapped tag values in bridge tables
-- Key: 0 (surrogate), ID: -1 (natural key), Name: 'Unknown'
SET IDENTITY_INSERT dbo.dim_badge_tag ON;
INSERT INTO dbo.dim_badge_tag (
    tag_key, tag_id, tag_name, tag_description, tag_category, tag_color_code,
    display_order, is_active, is_current, effective_date, expiration_date,
    dw_created_date, dw_updated_date
)
VALUES (
    0, -1, 'Unknown', 'Unknown tag', NULL, NULL,
    NULL, 0, 1, GETDATE(), NULL,
    GETDATE(), GETDATE()
);
SET IDENTITY_INSERT dbo.dim_badge_tag OFF;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_badge_tag Table Created Successfully';
PRINT '============================================================================';
PRINT 'Table: dbo.dim_badge_tag';
PRINT 'Purpose: Badge classification and discovery tags';
PRINT '';
PRINT 'Schema:';
PRINT '  - tag_key: PK surrogate key (IDENTITY 0,1)';
PRINT '  - tag_id: Natural key from source BDG_Tags';
PRINT '  - tag_name: Tag name for classification (NOT NULL)';
PRINT '  - tag_description: Tag description (nullable)';
PRINT '  - tag_category: UI category placeholder (nullable)';
PRINT '  - tag_color_code: Hex color for UI display (nullable)';
PRINT '  - display_order: Sort order for display (nullable)';
PRINT '  - is_active: Active status (BIT)';
PRINT '  - is_current: SCD Type 2 current flag (BIT)';
PRINT '  - effective_date: SCD Type 2 effective date (DATETIME2)';
PRINT '  - expiration_date: SCD Type 2 expiration date (nullable)';
PRINT '  - dw_created_date: DW audit timestamp';
PRINT '  - dw_updated_date: DW audit timestamp';
PRINT '';
PRINT 'Indexes:';
PRINT '  - PK Clustered: tag_key';
PRINT '  - IX_dim_badge_tag_natural_key: (tag_id, is_current) unique';
PRINT '  - IX_dim_badge_tag_active: (is_active, is_current) filtered WHERE is_current=1';
PRINT '  - IX_dim_badge_tag_display_order: (display_order) for UI sorting';
PRINT '';
PRINT 'Initial Data:';
PRINT '  - 1 Unknown row (tag_key=0, tag_id=-1)';
PRINT '';
PRINT '============================================================================';
GO
