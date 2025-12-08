-- ============================================================================
-- File: sql/19_create_badge_tag_bridge.sql
-- Purpose: Create dim_badge_tag_bridge many-to-many relationship table
-- Phase: Phase 4 - Classification & Workflow Dimensions
-- Grain: One row per badge-tag relationship
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.dim_badge_tag_bridge', 'U') IS NOT NULL
    DROP TABLE dbo.dim_badge_tag_bridge;
GO

CREATE TABLE dbo.dim_badge_tag_bridge (
    badge_tag_bridge_key INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    badge_key INT NOT NULL,
    tag_key INT NOT NULL,
    is_active BIT DEFAULT 1,
    sequence_order INT NULL,
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_bridge_badge_tag_badge FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_bridge_badge_tag_tag FOREIGN KEY (tag_key)
        REFERENCES dbo.dim_badge_tag(tag_key),
    CONSTRAINT UQ_badge_tag_pair UNIQUE (badge_key, tag_key)
);
GO

CREATE NONCLUSTERED INDEX IX_badge_tag_bridge_badge
    ON dbo.dim_badge_tag_bridge(badge_key)
    INCLUDE (tag_key, is_active);
GO

CREATE NONCLUSTERED INDEX IX_badge_tag_bridge_tag
    ON dbo.dim_badge_tag_bridge(tag_key)
    INCLUDE (badge_key, is_active);
GO

PRINT '';
PRINT '============================================================================';
PRINT 'dim_badge_tag_bridge Table Created Successfully';
PRINT '============================================================================';
PRINT 'Grain: One row per badge-tag relationship';
PRINT 'Indexes: Badge lookup, tag lookup';
PRINT '============================================================================';
GO
