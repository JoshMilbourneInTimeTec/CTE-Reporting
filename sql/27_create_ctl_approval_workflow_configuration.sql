-- ============================================================================
-- File: sql/27_create_ctl_approval_workflow_configuration.sql
-- Purpose: Create control table for approval workflow configuration
-- Phase: Phase 4.5 - Workflow & UI Enhancement
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop if exists
IF OBJECT_ID('SkillStack_Control.ctl.ApprovalWorkflowConfiguration', 'U') IS NOT NULL
    DROP TABLE SkillStack_Control.ctl.ApprovalWorkflowConfiguration;
GO

-- Create control table for approval workflow configuration
CREATE TABLE SkillStack_Control.ctl.ApprovalWorkflowConfiguration (
    -- Identification
    config_id INT IDENTITY(1,1) PRIMARY KEY,
    approval_set_key INT NOT NULL,                         -- FK to dim_approval_set
    approval_set_id INT NOT NULL,                          -- Natural key

    -- Workflow type and structure
    approval_type NVARCHAR(50) NOT NULL,                   -- 'Sequential', 'Parallel', 'Hierarchical', 'Custom'
    required_approver_count INT DEFAULT 1 NOT NULL,        -- Number of approvers required
    approval_sequencing_order INT NULL,                    -- Order if sequential (1, 2, 3...)

    -- Timing and SLAs
    approval_timeout_days INT DEFAULT 5 NOT NULL,          -- Days before approval times out
    escalation_after_days INT DEFAULT 3 NOT NULL,          -- Days before escalation triggered
    escalation_enabled BIT DEFAULT 1 NOT NULL,             -- Enable escalation

    -- Escalation configuration
    escalation_chain_depth INT DEFAULT 1 NOT NULL,         -- How many levels to escalate
    escalation_notify_manager BIT DEFAULT 1 NOT NULL,      -- Notify user manager
    escalation_notify_exec BIT DEFAULT 0 NOT NULL,         -- Notify executive
    escalation_note NVARCHAR(MAX) NULL,                    -- Escalation instructions

    -- Notification settings
    notification_recipients_count INT DEFAULT 0 NOT NULL,  -- Number of notified recipients
    notify_submitter BIT DEFAULT 1 NOT NULL,               -- Notify badge submitter
    notify_manager BIT DEFAULT 1 NOT NULL,                 -- Notify line manager
    notify_additional_stakeholders BIT DEFAULT 0 NOT NULL, -- Notify other stakeholders

    -- Approval requirements
    can_reject BIT DEFAULT 1 NOT NULL,                     -- Allow rejection
    can_return_for_revision BIT DEFAULT 1 NOT NULL,        -- Allow return for revision
    require_comments BIT DEFAULT 0 NOT NULL,               -- Require approval comments
    allow_bulk_approval BIT DEFAULT 0 NOT NULL,            -- Allow approving multiple at once

    -- Criteria and conditions
    approval_criteria NVARCHAR(MAX) NULL,                  -- Business logic criteria
    conditional_logic NVARCHAR(MAX) NULL,                  -- Conditional approval rules
    auto_approve_if_criteria_met BIT DEFAULT 0 NOT NULL,   -- Auto-approve when criteria met

    -- Status and configuration
    is_active BIT DEFAULT 1 NOT NULL,                      -- Configuration is active
    approval_status NVARCHAR(20) DEFAULT 'CONFIGURED' NOT NULL,  -- 'CONFIGURED', 'ACTIVE', 'ARCHIVED'

    -- Audit and history
    created_by NVARCHAR(100) DEFAULT USER_NAME() NOT NULL,
    created_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    updated_by NVARCHAR(100) DEFAULT USER_NAME() NOT NULL,
    updated_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    config_notes NVARCHAR(MAX) NULL,

    -- Constraints
    CONSTRAINT UC_approval_config UNIQUE (approval_set_key, approval_set_id)
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_ctl_approval_set_key ON SkillStack_Control.ctl.ApprovalWorkflowConfiguration (approval_set_key)
    INCLUDE (approval_type, is_active, approval_timeout_days);
GO

CREATE NONCLUSTERED INDEX IX_ctl_approval_type ON SkillStack_Control.ctl.ApprovalWorkflowConfiguration (approval_type)
    INCLUDE (required_approver_count, approval_timeout_days);
GO

CREATE NONCLUSTERED INDEX IX_ctl_active_workflows ON SkillStack_Control.ctl.ApprovalWorkflowConfiguration (is_active, approval_status)
    WHERE is_active = 1;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Control Table ctl.ApprovalWorkflowConfiguration Created Successfully';
PRINT '============================================================================';
GO
