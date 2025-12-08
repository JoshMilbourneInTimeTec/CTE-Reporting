-- ============================================================================
-- File: sql/31_create_application_ready_ui_views.sql
-- Purpose: Create application-ready views for UI rendering and display
-- Phase: Phase 4.5 - Workflow & UI Enhancement
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- View 1: Badge with Tags and UI Configuration for Display
IF OBJECT_ID('dbo.vw_badge_with_tags_ui', 'V') IS NOT NULL
    DROP VIEW dbo.vw_badge_with_tags_ui;
GO

CREATE VIEW dbo.vw_badge_with_tags_ui
AS
SELECT
    db.badge_key,
    db.badge_name,
    db.badge_id,
    db.badge_description,
    db.required_hours_to_complete,
    STRING_AGG(
        CONCAT(
            dbt.tag_name, '|',
            ISNULL(tuc.tag_category, 'Other'), '|',
            ISNULL(tuc.color_code_hex, '#757575'), '|',
            ISNULL(tuc.icon_name, 'fa-tag'), '|',
            ISNULL(tuc.ui_priority, 100)
        ), ';'
    ) WITHIN GROUP (ORDER BY ISNULL(tuc.ui_priority, 100)) as tags_ui_data,
    COUNT(DISTINCT dbtb.tag_key) as tag_count,
    db.dw_created_date,
    db.dw_updated_date
FROM dbo.dim_badge db
LEFT JOIN dbo.dim_badge_tag_bridge dbtb ON db.badge_key = dbtb.badge_key AND dbtb.tag_key <> 0
LEFT JOIN dbo.dim_badge_tag dbt ON dbtb.tag_key = dbt.tag_key AND dbt.is_current = 1
LEFT JOIN SkillStack_Control.ctl.TagUIConfiguration tuc ON dbt.tag_key = tuc.tag_key AND tuc.is_active = 1
WHERE db.is_current = 1 AND db.badge_key <> 0
GROUP BY db.badge_key, db.badge_name, db.badge_id, db.badge_description,
         db.required_hours_to_complete, db.dw_created_date, db.dw_updated_date;
GO

-- View 2: Approval Workflow Display with Configuration
IF OBJECT_ID('dbo.vw_approval_workflow_display', 'V') IS NOT NULL
    DROP VIEW dbo.vw_approval_workflow_display;
GO

CREATE VIEW dbo.vw_approval_workflow_display
AS
SELECT
    das.approval_set_key,
    das.approval_set_id,
    das.approval_set_name,
    das.approval_set_description,
    ISNULL(awc.approval_type, 'Sequential') as approval_type,
    ISNULL(awc.required_approver_count, 1) as required_approver_count,
    ISNULL(awc.approval_timeout_days, 5) as approval_timeout_days,
    ISNULL(awc.escalation_enabled, 1) as escalation_enabled,
    ISNULL(awc.escalation_after_days, 3) as escalation_after_days,
    ISNULL(awc.notification_recipients_count, 0) as notification_recipients_count,
    ISNULL(awc.require_comments, 0) as require_comments,
    ISNULL(awc.allow_bulk_approval, 0) as allow_bulk_approval,
    ISNULL(awc.is_active, 1) as is_active,
    awc.created_by,
    awc.created_date,
    awc.config_notes
FROM dbo.dim_approval_set das
LEFT JOIN SkillStack_Control.ctl.ApprovalWorkflowConfiguration awc
    ON das.approval_set_key = awc.approval_set_key AND awc.is_active = 1
WHERE das.is_current = 1 AND das.approval_set_key <> 0;
GO

-- View 3: Tag Master with UI Styling for Filter/Display
IF OBJECT_ID('dbo.vw_badge_tag_ui_master', 'V') IS NOT NULL
    DROP VIEW dbo.vw_badge_tag_ui_master;
GO

CREATE VIEW dbo.vw_badge_tag_ui_master
AS
SELECT
    dbt.tag_key,
    dbt.tag_id,
    dbt.tag_name,
    dbt.tag_description,
    ISNULL(tuc.tag_category, 'Other') as tag_category,
    ISNULL(tuc.color_code_hex, '#757575') as color_code,
    ISNULL(tuc.text_color_hex, '#000000') as text_color,
    ISNULL(tuc.background_color_hex, '#FFFFFF') as background_color,
    ISNULL(tuc.icon_name, 'fa-tag') as icon_name,
    ISNULL(tuc.icon_set, 'FontAwesome') as icon_set,
    ISNULL(tuc.ui_priority, 100) as ui_priority,
    ISNULL(tuc.is_visible_ui, 1) as is_visible_ui,
    ISNULL(tuc.is_filter_available, 1) as is_filter_available,
    ISNULL(tuc.keyboard_shortcut, '') as keyboard_shortcut,
    COUNT(DISTINCT dbtb.badge_key) as badge_count_using_tag,
    tuc.aria_label,
    tuc.alt_text
FROM dbo.dim_badge_tag dbt
LEFT JOIN SkillStack_Control.ctl.TagUIConfiguration tuc ON dbt.tag_key = tuc.tag_key AND tuc.is_active = 1
LEFT JOIN dbo.dim_badge_tag_bridge dbtb ON dbt.tag_key = dbtb.tag_key AND dbtb.tag_key <> 0
WHERE dbt.is_current = 1 AND dbt.tag_key <> 0
GROUP BY dbt.tag_key, dbt.tag_id, dbt.tag_name, dbt.tag_description,
         tuc.tag_category, tuc.color_code_hex, tuc.text_color_hex, tuc.background_color_hex,
         tuc.icon_name, tuc.icon_set, tuc.ui_priority, tuc.is_visible_ui, tuc.is_filter_available,
         tuc.keyboard_shortcut, tuc.aria_label, tuc.alt_text;
GO

-- View 4: Skill Set Hierarchy for UI Tree Display
IF OBJECT_ID('dbo.vw_skill_set_hierarchy_ui', 'V') IS NOT NULL
    DROP VIEW dbo.vw_skill_set_hierarchy_ui;
GO

CREATE VIEW dbo.vw_skill_set_hierarchy_ui
AS
SELECT
    dss.skill_set_key,
    dss.skill_set_id,
    dss.skill_set_name,
    dss.skill_set_description,
    dss.competency_level,
    ISNULL(ssh.parent_skill_set_key, 0) as parent_skill_set_key,
    ISNULL(parent_ss.skill_set_name, 'Root') as parent_skill_set_name,
    ISNULL(ssh.hierarchy_depth, 1) as hierarchy_depth,
    ISNULL(ssh.progression_order, 1) as progression_order,
    ISNULL(ssh.difficulty_level, 1) as difficulty_level,
    ISNULL(ssh.estimated_hours_to_mastery, 0) as estimated_hours_to_mastery,
    ISNULL(ssh.requires_assessment, 0) as requires_assessment,
    ISNULL(ssh.assessment_method, 'Practical') as assessment_method,
    ISNULL(ssh.passing_score_percentage, 70) as passing_score_percentage,
    ISNULL(ssh.is_core_skill_set, 0) as is_core_skill_set,
    COUNT(DISTINCT child_ssh.skill_set_key) as child_skill_set_count,
    ISNULL(ssh.is_active, 1) as is_active,
    ssh.hierarchy_notes
FROM dbo.dim_skill_set dss
LEFT JOIN SkillStack_Control.ctl.SkillSetHierarchy ssh ON dss.skill_set_key = ssh.skill_set_key AND ssh.is_active = 1
LEFT JOIN dbo.dim_skill_set parent_ss ON ssh.parent_skill_set_key = parent_ss.skill_set_key
LEFT JOIN SkillStack_Control.ctl.SkillSetHierarchy child_ssh
    ON dss.skill_set_key = child_ssh.parent_skill_set_key AND child_ssh.is_active = 1
WHERE dss.is_current = 1 AND dss.skill_set_key <> 0
GROUP BY dss.skill_set_key, dss.skill_set_id, dss.skill_set_name, dss.skill_set_description,
         dss.competency_level, ssh.parent_skill_set_key, parent_ss.skill_set_name,
         ssh.hierarchy_depth, ssh.progression_order, ssh.difficulty_level,
         ssh.estimated_hours_to_mastery, ssh.requires_assessment, ssh.assessment_method,
         ssh.passing_score_percentage, ssh.is_core_skill_set, ssh.is_active, ssh.hierarchy_notes;
GO

-- View 5: Badge Classification Summary for Dashboard
IF OBJECT_ID('dbo.vw_badge_classification_summary', 'V') IS NOT NULL
    DROP VIEW dbo.vw_badge_classification_summary;
GO

CREATE VIEW dbo.vw_badge_classification_summary
AS
SELECT
    CASE WHEN dbtb.tag_key = 0 THEN 'Unclassified' ELSE dbt.tag_name END as tag_name,
    ISNULL(tuc.tag_category, 'Other') as tag_category,
    ISNULL(tuc.color_code_hex, '#757575') as color_code,
    COUNT(DISTINCT dbtb.badge_key) as badge_count,
    COUNT(DISTINCT db.badge_key) FILTER (WHERE db.is_current = 1) as active_badge_count,
    COUNT(DISTINCT dc.career_key) as associated_career_count,
    AVG(CAST(dbc.alignment_strength AS NUMERIC(5,2))) as avg_career_alignment,
    MAX(dc.job_growth_percentage) as max_job_growth_rate,
    MAX(dc.median_annual_wage) as max_median_wage
FROM dbo.dim_badge_tag_bridge dbtb
FULL OUTER JOIN dbo.dim_badge db ON dbtb.badge_key = db.badge_key AND db.is_current = 1 AND db.badge_key <> 0
LEFT JOIN dbo.dim_badge_tag dbt ON dbtb.tag_key = dbt.tag_key AND dbt.is_current = 1
LEFT JOIN SkillStack_Control.ctl.TagUIConfiguration tuc ON dbt.tag_key = tuc.tag_key AND tuc.is_active = 1
LEFT JOIN dbo.dim_badge_career_bridge dbc ON db.badge_key = dbc.badge_key
LEFT JOIN dbo.dim_career dc ON dbc.career_key = dc.career_key AND dc.is_current = 1
WHERE db.badge_key IS NOT NULL
GROUP BY dbtb.tag_key, dbt.tag_name, tuc.tag_category, tuc.color_code_hex;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Application-Ready UI Views Created Successfully';
PRINT '============================================================================';
PRINT '  - vw_badge_with_tags_ui';
PRINT '  - vw_approval_workflow_display';
PRINT '  - vw_badge_tag_ui_master';
PRINT '  - vw_skill_set_hierarchy_ui';
PRINT '  - vw_badge_classification_summary';
PRINT '============================================================================';
GO
