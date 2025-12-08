-- ============================================================================
-- File: sql/13_create_badge_career_bridge.sql
-- Purpose: Create dim_badge_career_bridge many-to-many relationship table
-- Phase: Phase 3 - Labor Market Alignment
-- Grain: One row per badge-career relationship
-- Features: Alignment strength scoring, primary pathway flagging
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop table if it exists (allows re-creation during development)
IF OBJECT_ID('dbo.dim_badge_career_bridge', 'U') IS NOT NULL
    DROP TABLE dbo.dim_badge_career_bridge;
GO

-- ============================================================================
-- CREATE TABLE: dim_badge_career_bridge
-- ============================================================================
CREATE TABLE dbo.dim_badge_career_bridge (
    -- ========================================================================
    -- PRIMARY KEY: Surrogate key (auto-incrementing)
    -- ========================================================================
    badge_career_bridge_key INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- FOREIGN KEYS: Links to dimension tables
    -- ========================================================================
    badge_key INT NOT NULL,                 -- FK to dim_badge
    career_key INT NOT NULL,                -- FK to dim_career

    -- ========================================================================
    -- RELATIONSHIP PROPERTIES
    -- ========================================================================
    alignment_strength NUMERIC(3,2) NULL,   -- 0.00-1.00 score (1.0 = perfect alignment)
    is_primary_pathway BIT DEFAULT 0,       -- 1 = strongest relationship for this badge
    sequence_order INT NULL,                -- Order for display/reporting

    -- ========================================================================
    -- AUDIT FIELDS
    -- ========================================================================
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- ========================================================================
    -- CONSTRAINTS: Foreign keys and relationships
    -- ========================================================================
    CONSTRAINT FK_bridge_badge_career_badge FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_bridge_badge_career_career FOREIGN KEY (career_key)
        REFERENCES dbo.dim_career(career_key),
    CONSTRAINT UQ_badge_career_pair UNIQUE (badge_key, career_key)
);

GO

-- ============================================================================
-- INDEXES: Optimized for analytical queries
-- ============================================================================

-- Index 1: Badge lookup (find all careers for a badge)
-- Usage: WHERE badge_key = ? ORDER BY alignment_strength DESC
CREATE NONCLUSTERED INDEX IX_badge_career_bridge_badge
    ON dbo.dim_badge_career_bridge(badge_key)
    INCLUDE (career_key, alignment_strength, is_primary_pathway);
GO

-- Index 2: Career lookup (find all badges for a career)
-- Usage: WHERE career_key = ? ORDER BY alignment_strength DESC
CREATE NONCLUSTERED INDEX IX_badge_career_bridge_career
    ON dbo.dim_badge_career_bridge(career_key)
    INCLUDE (badge_key, alignment_strength, is_primary_pathway);
GO

-- Index 3: Primary pathway filter (find primary relationships)
-- Usage: WHERE is_primary_pathway = 1 for recommended paths
CREATE NONCLUSTERED INDEX IX_badge_career_bridge_primary_pathway
    ON dbo.dim_badge_career_bridge(is_primary_pathway)
    WHERE is_primary_pathway = 1;
GO

-- Index 4: High alignment relationships
-- Usage: WHERE alignment_strength >= 0.75 for strong associations
CREATE NONCLUSTERED INDEX IX_badge_career_bridge_alignment
    ON dbo.dim_badge_career_bridge(alignment_strength)
    WHERE alignment_strength >= 0.75;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_badge_career_bridge Table Created Successfully';
PRINT '============================================================================';
PRINT 'Grain:                 One row per badge-career relationship (many-to-many)';
PRINT 'Clustered Index:       PK on badge_career_bridge_key (IDENTITY, starts at 1)';
PRINT 'Unique Constraint:     UQ_badge_career_pair (badge_key, career_key)';
PRINT 'Nonclustered Indexes:  4 indexes for analytical queries';
PRINT '  - IX_badge_career_bridge_badge           (badge_key lookup)';
PRINT '  - IX_badge_career_bridge_career          (career_key lookup)';
PRINT '  - IX_badge_career_bridge_primary_pathway (is_primary_pathway = 1)';
PRINT '  - IX_badge_career_bridge_alignment       (alignment_strength >= 0.75)';
PRINT '';
PRINT 'Foreign Keys:';
PRINT '  - FK_bridge_badge_career_badge   → dim_badge(badge_key)';
PRINT '  - FK_bridge_badge_career_career  → dim_career(career_key)';
PRINT '';
PRINT 'Key Features:';
PRINT '  - Alignment strength (0.00-1.00) for career readiness scoring';
PRINT '  - Primary pathway flagging for recommended relationships';
PRINT '  - Sequence ordering for display prioritization';
PRINT '';
PRINT '============================================================================';
GO
