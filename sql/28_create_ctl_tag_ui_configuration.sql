-- ============================================================================
-- File: sql/28_create_ctl_tag_ui_configuration.sql
-- Purpose: Create control table for tag UI properties (colors, categories, icons)
-- Phase: Phase 4.5 - Workflow & UI Enhancement
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop if exists
IF OBJECT_ID('SkillStack_Control.ctl.TagUIConfiguration', 'U') IS NOT NULL
    DROP TABLE SkillStack_Control.ctl.TagUIConfiguration;
GO

-- Create control table for tag UI configuration
CREATE TABLE SkillStack_Control.ctl.TagUIConfiguration (
    -- Identification
    tag_ui_config_id INT IDENTITY(1,1) PRIMARY KEY,
    tag_key INT NOT NULL,                                  -- FK to dim_badge_tag
    tag_id INT NOT NULL,                                   -- Natural key

    -- UI Display Properties
    tag_category NVARCHAR(100) NOT NULL,                   -- 'Assessment', 'Duration', 'Level', 'Industry', 'Pathway', 'Credential'
    tag_display_name NVARCHAR(256) NOT NULL,               -- Display-friendly tag name
    tag_description_ui NVARCHAR(MAX) NULL,                 -- UI-specific description

    -- Color Configuration
    color_code_hex NCHAR(7) NOT NULL,                      -- Hex color code (e.g., '#FF6B6B')
    background_color_hex NCHAR(7) DEFAULT '#FFFFFF' NOT NULL,  -- Background color
    text_color_hex NCHAR(7) DEFAULT '#000000' NOT NULL,    -- Text color for contrast
    hover_color_hex NCHAR(7) NULL,                         -- Hover state color
    border_color_hex NCHAR(7) NULL,                        -- Border color

    -- Icon and Visual Configuration
    icon_name NVARCHAR(100) NULL,                          -- Icon name (e.g., 'fa-graduation-cap', 'mdi-clock')
    icon_set NVARCHAR(50) DEFAULT 'FontAwesome' NOT NULL,  -- Icon library (FontAwesome, Material, etc.)
    icon_size NVARCHAR(20) DEFAULT 'md' NOT NULL,          -- Icon size (sm, md, lg)
    display_badge_shape NVARCHAR(50) DEFAULT 'rounded' NOT NULL,  -- 'rounded', 'pill', 'square', 'diamond'

    -- UI Behavior
    is_visible_ui BIT DEFAULT 1 NOT NULL,                  -- Show in UI
    ui_priority INT DEFAULT 100 NOT NULL,                  -- Display priority (lower = higher priority)
    is_filter_available BIT DEFAULT 1 NOT NULL,            -- Allow as filter criterion
    is_searchable BIT DEFAULT 1 NOT NULL,                  -- Include in search

    -- Accessibility
    aria_label NVARCHAR(256) NULL,                         -- Accessibility label
    alt_text NVARCHAR(256) NULL,                           -- Alternative text for screen readers
    keyboard_shortcut NCHAR(1) NULL,                       -- Optional single-key shortcut

    -- Integration
    analytics_tracking_id NVARCHAR(100) NULL,              -- For tracking clicks/impressions
    integration_api_endpoint NVARCHAR(500) NULL,           -- External API endpoint if needed

    -- Configuration Status
    is_active BIT DEFAULT 1 NOT NULL,                      -- Configuration active
    configuration_status NVARCHAR(20) DEFAULT 'DEPLOYED' NOT NULL,  -- 'DRAFT', 'TESTING', 'DEPLOYED', 'ARCHIVED'

    -- Audit
    created_by NVARCHAR(100) DEFAULT USER_NAME() NOT NULL,
    created_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    updated_by NVARCHAR(100) DEFAULT USER_NAME() NOT NULL,
    updated_date DATETIME2 DEFAULT GETDATE() NOT NULL,
    design_notes NVARCHAR(MAX) NULL,

    -- Constraints
    CONSTRAINT UC_tag_ui_config UNIQUE (tag_key, tag_id),
    CONSTRAINT CK_hex_color CHECK (color_code_hex LIKE '#[0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F][0-9A-F]')
);
GO

-- Create indexes
CREATE NONCLUSTERED INDEX IX_ctl_tag_key ON SkillStack_Control.ctl.TagUIConfiguration (tag_key)
    INCLUDE (tag_category, is_visible_ui, ui_priority);
GO

CREATE NONCLUSTERED INDEX IX_ctl_tag_category ON SkillStack_Control.ctl.TagUIConfiguration (tag_category)
    INCLUDE (tag_key, color_code_hex, ui_priority);
GO

CREATE NONCLUSTERED INDEX IX_ctl_visible_tags ON SkillStack_Control.ctl.TagUIConfiguration (is_visible_ui, is_active, ui_priority)
    WHERE is_visible_ui = 1;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Control Table ctl.TagUIConfiguration Created Successfully';
PRINT '============================================================================';
GO
