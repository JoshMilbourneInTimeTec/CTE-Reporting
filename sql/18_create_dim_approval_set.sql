-- ============================================================================
-- File: sql/18_create_dim_approval_set.sql
-- Purpose: Create dim_approval_set dimension for approval workflows
-- Phase: Phase 4 - Classification & Workflow Dimensions
-- Grain: One row per approval set (SCD Type 2)
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.dim_approval_set', 'U') IS NOT NULL
    DROP TABLE dbo.dim_approval_set;
GO

CREATE TABLE dbo.dim_approval_set (
    approval_set_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,
    approval_set_id INT NOT NULL,
    approval_set_name NVARCHAR(256) NOT NULL,
    approval_set_description NVARCHAR(MAX) NULL,
    approval_type NVARCHAR(50) NULL,
    required_approver_count INT NULL,
    approval_timeout_days INT NULL,
    escalation_enabled BIT DEFAULT 0,
    notification_recipients_count INT NULL,
    is_active BIT NOT NULL DEFAULT 1,
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UQ_approval_set_natural_key UNIQUE NONCLUSTERED (approval_set_id, is_current)
);
GO

CREATE UNIQUE NONCLUSTERED INDEX IX_dim_approval_set_natural_key
    ON dbo.dim_approval_set(approval_set_id, is_current)
    INCLUDE (approval_set_key, approval_set_name);
GO

CREATE NONCLUSTERED INDEX IX_dim_approval_set_active
    ON dbo.dim_approval_set(is_active, is_current)
    INCLUDE (approval_set_key, approval_set_name)
    WHERE is_active = 1 AND is_current = 1;
GO

SET IDENTITY_INSERT dbo.dim_approval_set ON;
INSERT INTO dbo.dim_approval_set (
    approval_set_key, approval_set_id, approval_set_name, approval_set_description,
    approval_type, required_approver_count, approval_timeout_days, escalation_enabled,
    notification_recipients_count, is_active, is_current, effective_date, expiration_date,
    dw_created_date, dw_updated_date
)
VALUES (
    0, -1, 'Unknown', 'Unknown approval set', NULL,
    NULL, NULL, 0, NULL, 0, 1, GETDATE(), NULL,
    GETDATE(), GETDATE()
);
SET IDENTITY_INSERT dbo.dim_approval_set OFF;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'dim_approval_set Table Created Successfully';
PRINT '============================================================================';
PRINT 'Rows: 1 Unknown (key=0, id=-1)';
PRINT 'Indexes: Natural key, active filter';
PRINT '============================================================================';
GO
