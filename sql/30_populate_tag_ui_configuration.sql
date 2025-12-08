-- ============================================================================
-- File: sql/30_populate_tag_ui_configuration.sql
-- Purpose: Populate tag UI configuration with colors, categories, and icons
-- Phase: Phase 4.5 - Workflow & UI Enhancement
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

IF OBJECT_ID('dbo.sp_Populate_tag_ui_configuration', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_Populate_tag_ui_configuration;
GO

CREATE PROCEDURE dbo.sp_Populate_tag_ui_configuration
    @DebugMode BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @StartTime DATETIME2 = GETDATE();
    DECLARE @RowsInserted INT = 0;
    DECLARE @ErrorMessage NVARCHAR(4000);

    BEGIN TRY
        IF @DebugMode = 1
            PRINT 'Starting sp_Populate_tag_ui_configuration at ' + CONVERT(VARCHAR(30), @StartTime, 121);

        -- Clear existing configurations
        DELETE FROM SkillStack_Control.ctl.TagUIConfiguration
        WHERE configuration_status IN ('DEPLOYED', 'TESTING');

        -- Insert tag UI configurations with predefined colors and categories
        INSERT INTO SkillStack_Control.ctl.TagUIConfiguration (
            tag_key, tag_id, tag_category, tag_display_name, tag_description_ui,
            color_code_hex, background_color_hex, text_color_hex, icon_name, icon_set,
            is_visible_ui, ui_priority, is_filter_available, configuration_status
        )
        SELECT
            dbt.tag_key,
            dbt.tag_id,
            CASE dbt.tag_name
                WHEN 'TSA' THEN 'Assessment'
                WHEN 'PSA' THEN 'Assessment'
                WHEN 'Secondary' THEN 'Level'
                WHEN 'Postsecondary' THEN 'Level'
                WHEN 'Aligned' THEN 'Credential'
                WHEN 'Agriculture' THEN 'Industry'
                WHEN 'Business' THEN 'Industry'
                WHEN 'Engineering' THEN 'Industry'
                WHEN 'Family & Consumer Sciences' THEN 'Industry'
                WHEN 'Health Professions' THEN 'Industry'
                WHEN 'Trades' THEN 'Industry'
                WHEN 'Professional Development' THEN 'Duration'
                WHEN 'Workforce Training' THEN 'Duration'
                ELSE 'Other'
            END as tag_category,
            dbt.tag_name as tag_display_name,
            CONCAT('Badge classification: ', dbt.tag_name) as tag_description_ui,
            -- Color mapping by tag category (hex color codes)
            CASE dbt.tag_name
                WHEN 'TSA' THEN '#FF6B6B'                    -- TSA Red
                WHEN 'PSA' THEN '#4ECDC4'                    -- PSA Teal
                WHEN 'Secondary' THEN '#FFE66D'              -- Secondary Gold
                WHEN 'Postsecondary' THEN '#95E1D3'          -- Postsecondary Mint
                WHEN 'Aligned' THEN '#A8E6CF'                -- Aligned Green
                WHEN 'Agriculture' THEN '#8B7355'            -- Agriculture Brown
                WHEN 'Business' THEN '#2E86AB'               -- Business Blue
                WHEN 'Engineering' THEN '#A23B72'            -- Engineering Purple
                WHEN 'Family & Consumer Sciences' THEN '#F18F01'  -- Family Sciences Orange
                WHEN 'Health Professions' THEN '#C1121F'     -- Health Red
                WHEN 'Trades' THEN '#6A4C93'                 -- Trades Indigo
                WHEN 'Professional Development' THEN '#1D3557' -- PD Navy
                WHEN 'Workforce Training' THEN '#457B9D'     -- WT Steel Blue
                ELSE '#757575'                                -- Gray fallback
            END as color_code_hex,
            '#FFFFFF' as background_color_hex,
            CASE dbt.tag_name
                WHEN 'TSA' THEN '#FFFFFF'
                WHEN 'PSA' THEN '#FFFFFF'
                WHEN 'Secondary' THEN '#000000'
                WHEN 'Postsecondary' THEN '#000000'
                WHEN 'Aligned' THEN '#000000'
                WHEN 'Agriculture' THEN '#FFFFFF'
                WHEN 'Business' THEN '#FFFFFF'
                WHEN 'Engineering' THEN '#FFFFFF'
                WHEN 'Family & Consumer Sciences' THEN '#FFFFFF'
                WHEN 'Health Professions' THEN '#FFFFFF'
                WHEN 'Trades' THEN '#FFFFFF'
                WHEN 'Professional Development' THEN '#FFFFFF'
                WHEN 'Workforce Training' THEN '#FFFFFF'
                ELSE '#000000'
            END as text_color_hex,
            -- Icon mapping by tag name
            CASE dbt.tag_name
                WHEN 'TSA' THEN 'fa-graduation-cap'
                WHEN 'PSA' THEN 'fa-book'
                WHEN 'Secondary' THEN 'fa-child'
                WHEN 'Postsecondary' THEN 'fa-user-graduate'
                WHEN 'Aligned' THEN 'fa-check-circle'
                WHEN 'Agriculture' THEN 'fa-leaf'
                WHEN 'Business' THEN 'fa-briefcase'
                WHEN 'Engineering' THEN 'fa-cog'
                WHEN 'Family & Consumer Sciences' THEN 'fa-home'
                WHEN 'Health Professions' THEN 'fa-heartbeat'
                WHEN 'Trades' THEN 'fa-wrench'
                WHEN 'Professional Development' THEN 'fa-star'
                WHEN 'Workforce Training' THEN 'fa-users'
                ELSE 'fa-tag'
            END as icon_name,
            'FontAwesome' as icon_set,
            1 as is_visible_ui,
            -- Priority ordering (lower = higher)
            CASE dbt.tag_name
                WHEN 'Secondary' THEN 10
                WHEN 'Postsecondary' THEN 20
                WHEN 'TSA' THEN 30
                WHEN 'PSA' THEN 40
                WHEN 'Aligned' THEN 50
                ELSE 100
            END as ui_priority,
            1 as is_filter_available,
            'DEPLOYED' as configuration_status
        FROM dbo.dim_badge_tag dbt
        WHERE dbt.is_current = 1 AND dbt.tag_key <> 0
        ORDER BY dbt.tag_key;

        SET @RowsInserted = @@ROWCOUNT;

        IF @DebugMode = 1
            PRINT 'Tag UI configurations populated: ' + CAST(@RowsInserted AS VARCHAR(10));

        -- Update dim_badge_tag with UI configuration from control table
        UPDATE dbo.dim_badge_tag
        SET
            tag_category = ISNULL(tuc.tag_category, dbt.tag_category),
            tag_color_code = ISNULL(tuc.color_code_hex, dbt.tag_color_code),
            dw_updated_date = GETDATE()
        FROM dbo.dim_badge_tag dbt
        INNER JOIN SkillStack_Control.ctl.TagUIConfiguration tuc
            ON dbt.tag_key = tuc.tag_key
        WHERE dbt.is_current = 1 AND dbt.tag_key <> 0;

        IF @DebugMode = 1
            PRINT 'dim_badge_tag updated with UI configuration';

        -- Log the operation
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Tag UI Configuration', 'sp_Populate_tag_ui_configuration', 'Success', @RowsInserted, @StartTime, GETDATE(), NULL);

        IF @DebugMode = 1
            PRINT 'Completed sp_Populate_tag_ui_configuration at ' + CONVERT(VARCHAR(30), GETDATE(), 121);

    END TRY
    BEGIN CATCH
        SELECT @ErrorMessage = ERROR_MESSAGE();
        INSERT INTO dbo.job_execution_log (job_name, step_name, status, rows_affected, execution_start_time, execution_end_time, error_message)
        VALUES ('Tag UI Configuration', 'sp_Populate_tag_ui_configuration', 'Failed', 0, @StartTime, GETDATE(), @ErrorMessage);
        RAISERROR (@ErrorMessage, 16, 1);
    END CATCH;
END;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Stored Procedure sp_Populate_tag_ui_configuration Created Successfully';
PRINT '============================================================================';
GO
