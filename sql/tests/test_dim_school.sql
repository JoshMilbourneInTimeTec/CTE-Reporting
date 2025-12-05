-- ============================================================================
-- SkillStack_DW: Unit Tests for dim_school
-- ============================================================================
-- Test Suite: 10 comprehensive tests for data quality and structure
-- ============================================================================

PRINT '====================================================================';
PRINT 'UNIT TESTS: dim_school';
PRINT '====================================================================';

-- ============================================================================
-- TEST 1: Table Structure Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 1: Table Structure Verification';
PRINT 'Expected: All columns present with correct data types';

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dim_school'
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- TEST 2: Primary Key Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 2: Primary Key Verification';
PRINT 'Expected: PK_dim_school exists on school_key';

SELECT
    CONSTRAINT_NAME,
    COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'dim_school' AND CONSTRAINT_NAME LIKE 'PK_%';

-- ============================================================================
-- TEST 3: Foreign Keys Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 3: Foreign Keys Verification';
PRINT 'Expected: FK to dim_district exists';

SELECT
    fk.name AS FK_Constraint,
    COL_NAME(fc.parent_object_id, fc.parent_column_id) AS Child_Column,
    OBJECT_NAME(fk.referenced_object_id) AS Parent_Table,
    COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS Parent_Column
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fc ON fk.object_id = fc.constraint_object_id
WHERE OBJECT_NAME(fk.parent_object_id) = 'dim_school'
ORDER BY fk.name;

-- ============================================================================
-- TEST 4: Unknown Row Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 4: Unknown Row Verification';
PRINT 'Expected: 1 row with school_key=0, school_name="Unknown", district_key=0, is_current=1';

SELECT
    school_key,
    school_id,
    school_name,
    district_key,
    is_current,
    dw_created_date,
    dw_updated_date
FROM dbo.dim_school
WHERE school_key = 0;

IF (SELECT COUNT(*) FROM dbo.dim_school WHERE school_key = 0) = 1
    PRINT 'PASS: Unknown row exists';
ELSE
    PRINT 'FAIL: Unknown row missing or duplicate';

-- ============================================================================
-- TEST 5: No NULL Business Keys (Except Unknown Row)
-- ============================================================================
PRINT CHAR(10) + 'TEST 5: No NULL Business Keys (Except Unknown Row)';
PRINT 'Expected: 0 rows with NULL school_id (excluding Unknown row)';

SELECT
    school_key,
    school_id,
    school_name
FROM dbo.dim_school
WHERE school_key <> 0 AND school_id IS NULL;

IF (SELECT COUNT(*) FROM dbo.dim_school WHERE school_key <> 0 AND school_id IS NULL) = 0
    PRINT 'PASS: No NULL business keys found';
ELSE
    PRINT 'FAIL: NULL business keys found';

-- ============================================================================
-- TEST 6: FK Orphaned Records Test
-- ============================================================================
PRINT CHAR(10) + 'TEST 6: FK Orphaned Records Test';
PRINT 'Expected: 0 rows (no schools with invalid district_key)';

SELECT
    s.school_key,
    s.school_id,
    s.school_name,
    s.district_key,
    d.district_key AS parent_exists
FROM dbo.dim_school s
LEFT JOIN dbo.dim_district d ON s.district_key = d.district_key
WHERE s.school_key <> 0  -- Exclude Unknown
  AND s.district_key <> 0  -- Only check non-Unknown FKs
  AND d.district_key IS NULL;

IF (SELECT COUNT(*) FROM (
    SELECT 1 FROM dbo.dim_school s
    LEFT JOIN dbo.dim_district d ON s.district_key = d.district_key
    WHERE s.school_key <> 0 AND s.district_key <> 0 AND d.district_key IS NULL
) x) = 0
    PRINT 'PASS: No orphaned FK records';
ELSE
    PRINT 'FAIL: Orphaned FK records found';

-- ============================================================================
-- TEST 7: FK Distribution by District
-- ============================================================================
PRINT CHAR(10) + 'TEST 7: FK Distribution by District';
PRINT 'Expected: Shows schools grouped by district';

SELECT
    d.district_name,
    COUNT(s.school_key) AS School_Count,
    MIN(s.school_key) AS First_School_Key,
    MAX(s.school_key) AS Last_School_Key
FROM dbo.dim_district d
LEFT JOIN dbo.dim_school s ON d.district_key = s.district_key
WHERE d.district_key <> 0  -- Exclude Unknown
GROUP BY d.district_key, d.district_name
ORDER BY School_Count DESC;

-- ============================================================================
-- TEST 8: Duplicate Business Keys
-- ============================================================================
PRINT CHAR(10) + 'TEST 8: Duplicate Business Keys';
PRINT 'Expected: 0 rows (no duplicates)';

SELECT
    school_id,
    COUNT(*) AS Duplicate_Count
FROM dbo.dim_school
WHERE school_key <> 0
GROUP BY school_id
HAVING COUNT(*) > 1;

IF (SELECT COUNT(*) FROM (
    SELECT school_id, COUNT(*) AS cnt FROM dbo.dim_school WHERE school_key <> 0 GROUP BY school_id HAVING COUNT(*) > 1
) x) = 0
    PRINT 'PASS: No duplicate business keys';
ELSE
    PRINT 'FAIL: Duplicate business keys found';

-- ============================================================================
-- TEST 9: Audit Columns Population
-- ============================================================================
PRINT CHAR(10) + 'TEST 9: Audit Columns Population';
PRINT 'Expected: 0 rows with NULL dw_created_date or dw_updated_date';

SELECT
    school_key,
    school_name,
    dw_created_date,
    dw_updated_date
FROM dbo.dim_school
WHERE dw_created_date IS NULL OR dw_updated_date IS NULL;

IF (SELECT COUNT(*) FROM dbo.dim_school WHERE dw_created_date IS NULL OR dw_updated_date IS NULL) = 0
    PRINT 'PASS: All audit columns populated';
ELSE
    PRINT 'FAIL: Missing audit columns';

-- ============================================================================
-- TEST 10: Row Count Summary
-- ============================================================================
PRINT CHAR(10) + 'TEST 10: Row Count Summary';
PRINT 'Expected: 1 Unknown row + populated schools from staging';

SELECT
    'Total Rows' AS Metric,
    COUNT(*) AS Count_Value
FROM dbo.dim_school
UNION ALL
SELECT 'Unknown Rows', COUNT(*) FROM dbo.dim_school WHERE school_key = 0
UNION ALL
SELECT 'Current Records', COUNT(*) FROM dbo.dim_school WHERE is_current = 1
UNION ALL
SELECT 'Non-Current Records', COUNT(*) FROM dbo.dim_school WHERE is_current = 0
UNION ALL
SELECT 'Staging Schools (Active)', COUNT(DISTINCT SchoolId) FROM SkillStack_Staging.stg.USR_Schools WHERE IsActive = 1;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
PRINT CHAR(10) + '====================================================================';
PRINT 'TEST SUMMARY: All structure and FK validation complete';
PRINT '====================================================================';
PRINT 'Execute sp_Load_dim_school next to test data loading';
