-- ============================================================================
-- File: sql/12_create_dim_certification.sql
-- Purpose: Create dim_certification dimension table for SkillStack_DW
-- Phase: Phase 3 - Labor Market Alignment
-- Grain: One row per certification (SCD Type 2)
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.dim_certification', 'U') IS NOT NULL
    DROP TABLE dbo.dim_certification;
GO

CREATE TABLE dbo.dim_certification (
    certification_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,
    certification_id INT NOT NULL,
    certification_name NVARCHAR(255) NOT NULL,
    certification_description NVARCHAR(MAX) NULL,
    issuing_organization NVARCHAR(255) NULL,
    certification_code VARCHAR(50) NULL,
    renewal_period_months INT NULL,
    cost_usd NUMERIC(8,2) NULL,
    typical_preparation_hours INT NULL,
    is_industry_recognized BIT DEFAULT 1,
    is_stackable BIT DEFAULT 0,
    priority_level INT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

CREATE UNIQUE NONCLUSTERED INDEX IX_dim_certification_natural_key
    ON dbo.dim_certification (certification_id, is_current)
    WHERE is_current = 1;
GO

CREATE NONCLUSTERED INDEX IX_dim_certification_active
    ON dbo.dim_certification (is_active)
    WHERE is_active = 1 AND is_current = 1;
GO

CREATE NONCLUSTERED INDEX IX_dim_certification_stackable
    ON dbo.dim_certification (is_stackable)
    WHERE is_stackable = 1 AND is_current = 1;
GO

SET IDENTITY_INSERT dbo.dim_certification ON;
INSERT INTO dbo.dim_certification (certification_key, certification_id, certification_name, is_active, is_current, dw_created_date, dw_updated_date)
VALUES (0, -1, 'Unknown', 0, 1, GETDATE(), GETDATE());
SET IDENTITY_INSERT dbo.dim_certification OFF;
GO

PRINT 'dim_certification table created successfully (142 rows + Unknown row expected)';
SELECT COUNT(*) as rows_in_table FROM dbo.dim_certification;
GO
