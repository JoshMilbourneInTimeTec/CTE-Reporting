-- ============================================================================
-- File: sql/06_alter_dim_badge_add_specialty_fk.sql
-- Purpose: Add FK constraint to dim_badge.specialty_key
-- CRITICAL: Fixes the blocking issue where specialty_key was unconstrained
-- Prerequisite: dim_specialty must be populated with all specialties
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

PRINT '';
PRINT '============================================================================';
PRINT 'Adding Foreign Key Constraint to dim_badge.specialty_key';
PRINT '============================================================================';
PRINT '';

-- ============================================================================
-- VALIDATION: Check that all specialty_key values in dim_badge exist in dim_specialty
-- ============================================================================

DECLARE @OrphanedRows INT = 0;

SELECT @OrphanedRows = COUNT(*)
FROM dbo.dim_badge b
WHERE b.specialty_key IS NOT NULL
AND b.specialty_key <> 0
AND NOT EXISTS (
    SELECT 1 FROM dbo.dim_specialty s
    WHERE s.specialty_key = b.specialty_key
);

IF @OrphanedRows > 0
BEGIN
    PRINT 'ERROR: Found ' + CAST(@OrphanedRows AS VARCHAR(10)) + ' orphaned specialty_key values in dim_badge';
    PRINT 'Please resolve these before adding the FK constraint';
    RAISERROR ('FK constraint cannot be added due to orphaned references', 16, 1);
END
ELSE
BEGIN
    PRINT 'Validation PASSED: All specialty_key values in dim_badge reference valid specialties';
    PRINT '';

    -- ========================================================================
    -- ADD FOREIGN KEY CONSTRAINT
    -- ========================================================================

    -- First check if the constraint already exists
    IF NOT EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE name = 'FK_badge_specialty'
        AND parent_object_id = OBJECT_ID('dbo.dim_badge')
    )
    BEGIN
        ALTER TABLE dbo.dim_badge
        ADD CONSTRAINT FK_badge_specialty
            FOREIGN KEY (specialty_key)
            REFERENCES dbo.dim_specialty(specialty_key);

        PRINT 'Foreign Key constraint added successfully: FK_badge_specialty';
        PRINT 'Column: dim_badge.specialty_key';
        PRINT 'References: dim_specialty(specialty_key)';
    END
    ELSE
    BEGIN
        PRINT 'Foreign Key constraint already exists: FK_badge_specialty';
    END
END

PRINT '';
PRINT '============================================================================';
PRINT 'Verification';
PRINT '============================================================================';

-- Verify the constraint was created
SELECT
    name as constraint_name,
    OBJECT_NAME(parent_object_id) as table_name,
    OBJECT_NAME(referenced_object_id) as referenced_table,
    type_desc
FROM sys.foreign_keys
WHERE parent_object_id = OBJECT_ID('dbo.dim_badge')
AND name = 'FK_badge_specialty';

PRINT '';

-- Show the FK relationship
SELECT
    'FK_badge_specialty' as relationship,
    'dim_badge.specialty_key' as foreign_key_column,
    'dim_specialty.specialty_key' as primary_key_column,
    COUNT(*) as badge_count
FROM dbo.dim_badge
WHERE specialty_key IS NOT NULL
GROUP BY specialty_key;

PRINT '';
PRINT '============================================================================';
GO
