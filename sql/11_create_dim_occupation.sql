-- ============================================================================
-- File: sql/11_create_dim_occupation.sql
-- Purpose: Create dim_occupation dimension table for SkillStack_DW
-- Phase: Phase 3 - Labor Market Alignment
-- Grain: One row per occupation (SCD Type 2)
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.dim_occupation', 'U') IS NOT NULL
    DROP TABLE dbo.dim_occupation;
GO

CREATE TABLE dbo.dim_occupation (
    occupation_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,
    occupation_id INT NOT NULL,
    soc_code VARCHAR(10) NULL,
    onet_code VARCHAR(10) NULL,
    occupation_name NVARCHAR(255) NOT NULL,
    occupation_description NVARCHAR(MAX) NULL,
    education_required NVARCHAR(100) NULL,
    training_required NVARCHAR(100) NULL,
    median_annual_wage NUMERIC(12,2) NULL,
    job_growth_percentage NUMERIC(5,2) NULL,
    typical_work_hours_per_week INT NULL,
    is_high_demand BIT DEFAULT 0,
    is_stem BIT DEFAULT 0,
    is_active BIT NOT NULL DEFAULT 1,
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE()
);
GO

CREATE UNIQUE NONCLUSTERED INDEX IX_dim_occupation_natural_key
    ON dbo.dim_occupation (occupation_id, is_current)
    WHERE is_current = 1;
GO

CREATE NONCLUSTERED INDEX IX_dim_occupation_active
    ON dbo.dim_occupation (is_active)
    WHERE is_active = 1 AND is_current = 1;
GO

CREATE NONCLUSTERED INDEX IX_dim_occupation_stem
    ON dbo.dim_occupation (is_stem)
    WHERE is_stem = 1 AND is_current = 1;
GO

SET IDENTITY_INSERT dbo.dim_occupation ON;
INSERT INTO dbo.dim_occupation (occupation_key, occupation_id, occupation_name, is_active, is_current, dw_created_date, dw_updated_date)
VALUES (0, -1, 'Unknown', 0, 1, GETDATE(), GETDATE());
SET IDENTITY_INSERT dbo.dim_occupation OFF;
GO

PRINT 'dim_occupation table created successfully (148 rows + Unknown row expected)';
SELECT COUNT(*) as rows_in_table FROM dbo.dim_occupation;
GO
