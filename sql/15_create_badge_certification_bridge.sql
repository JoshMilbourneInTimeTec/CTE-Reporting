-- ============================================================================
-- File: sql/15_create_badge_certification_bridge.sql
-- Purpose: Create dim_badge_certification_bridge many-to-many relationship
-- Phase: Phase 3 - Labor Market Alignment
-- Grain: One row per badge-certification relationship
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.dim_badge_certification_bridge', 'U') IS NOT NULL
    DROP TABLE dbo.dim_badge_certification_bridge;
GO

CREATE TABLE dbo.dim_badge_certification_bridge (
    badge_certification_bridge_key INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
    badge_key INT NOT NULL,
    certification_key INT NOT NULL,
    certification_covers_percentage NUMERIC(5,2) NULL,
    is_prerequisite BIT DEFAULT 0,
    is_recommended BIT DEFAULT 1,
    sequence_order INT NULL,
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT FK_bridge_badge_certification_badge FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_bridge_badge_certification_cert FOREIGN KEY (certification_key)
        REFERENCES dbo.dim_certification(certification_key),
    CONSTRAINT UQ_badge_certification_pair UNIQUE (badge_key, certification_key)
);
GO

CREATE NONCLUSTERED INDEX IX_badge_certification_bridge_badge
    ON dbo.dim_badge_certification_bridge(badge_key)
    INCLUDE (certification_key, is_recommended, is_prerequisite);
GO

CREATE NONCLUSTERED INDEX IX_badge_certification_bridge_cert
    ON dbo.dim_badge_certification_bridge(certification_key)
    INCLUDE (badge_key, is_recommended);
GO

CREATE NONCLUSTERED INDEX IX_badge_certification_bridge_recommended
    ON dbo.dim_badge_certification_bridge(is_recommended)
    WHERE is_recommended = 1;
GO

PRINT 'dim_badge_certification_bridge table created successfully';
GO
