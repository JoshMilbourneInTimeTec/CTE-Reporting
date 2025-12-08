-- ============================================================================
-- File: sql/14_create_badge_occupation_bridge.sql
-- Purpose: Create dim_badge_occupation_bridge many-to-many relationship table
-- Phase: Phase 3 - Labor Market Alignment
-- Grain: One row per badge-occupation relationship
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.dim_badge_occupation_bridge', 'U') IS NOT NULL
    DROP TABLE dbo.dim_badge_occupation_bridge;
GO

CREATE TABLE dbo.dim_badge_occupation_bridge (
    badge_occupation_bridge_key INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    badge_key INT NOT NULL,
    occupation_key INT NOT NULL,
    alignment_strength NUMERIC(3,2) NULL,
    is_primary_pathway BIT DEFAULT 0,
    sequence_order INT NULL,
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_bridge_badge_occupation_badge FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_bridge_badge_occupation_occupation FOREIGN KEY (occupation_key)
        REFERENCES dbo.dim_occupation(occupation_key),
    CONSTRAINT UQ_badge_occupation_pair UNIQUE (badge_key, occupation_key)
);
GO

CREATE NONCLUSTERED INDEX IX_badge_occupation_bridge_badge
    ON dbo.dim_badge_occupation_bridge(badge_key)
    INCLUDE (occupation_key, alignment_strength, is_primary_pathway);
GO

CREATE NONCLUSTERED INDEX IX_badge_occupation_bridge_occupation
    ON dbo.dim_badge_occupation_bridge(occupation_key)
    INCLUDE (badge_key, alignment_strength, is_primary_pathway);
GO

CREATE NONCLUSTERED INDEX IX_badge_occupation_bridge_primary_pathway
    ON dbo.dim_badge_occupation_bridge(is_primary_pathway)
    WHERE is_primary_pathway = 1;
GO

PRINT 'dim_badge_occupation_bridge table created successfully';
GO
