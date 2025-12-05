-- ============================================================================
-- SkillStack_DW: Unit Tests for dim_district
-- ============================================================================
-- Test Suite: 10 comprehensive tests for data quality and structure
-- ============================================================================

PRINT '====================================================================';
PRINT 'UNIT TESTS: dim_district';
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
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dim_district'
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- TEST 2: Primary Key Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 2: Primary Key Verification';
PRINT 'Expected: PK_dim_district exists on district_key';

SELECT
    CONSTRAINT_NAME,
    COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'dim_district' AND CONSTRAINT_NAME LIKE 'PK_%';

-- ============================================================================
-- TEST 3: Unique Constraint Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 3: Unique Constraint Verification';
PRINT 'Expected: UK_dim_district_id exists on district_id';

SELECT
    CONSTRAINT_NAME,
    COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'dim_district' AND CONSTRAINT_NAME LIKE 'UK_%';

-- ============================================================================
-- TEST 4: Unknown Row Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 4: Unknown Row Verification';
PRINT 'Expected: 1 row with district_key=0, district_name="Unknown", is_current=1';

SELECT
    district_key,
    district_id,
    district_name,
    region,
    is_current,
    dw_created_date,
    dw_updated_date
FROM dbo.dim_district
WHERE district_key = 0;

-- Verification query
IF (SELECT COUNT(*) FROM dbo.dim_district WHERE district_key = 0) = 1
    PRINT 'PASS: Unknown row exists';
ELSE
    PRINT 'FAIL: Unknown row missing or duplicate';

-- ============================================================================
-- TEST 5: No NULL Business Keys (Except Unknown Row)
-- ============================================================================
PRINT CHAR(10) + 'TEST 5: No NULL Business Keys (Except Unknown Row)';
PRINT 'Expected: 0 rows with NULL district_id (excluding Unknown row)';

SELECT
    district_key,
    district_id,
    district_name
FROM dbo.dim_district
WHERE district_key <> 0 AND district_id IS NULL;

IF (SELECT COUNT(*) FROM dbo.dim_district WHERE district_key <> 0 AND district_id IS NULL) = 0
    PRINT 'PASS: No NULL business keys found';
ELSE
    PRINT 'FAIL: NULL business keys found';

-- ============================================================================
-- TEST 6: is_current Flag Distribution
-- ============================================================================
PRINT CHAR(10) + 'TEST 6: is_current Flag Distribution';
PRINT 'Expected: All rows currently have is_current=1 (before incremental loads)';

SELECT
    is_current,
    COUNT(*) AS Row_Count,
    CAST(ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.dim_district), 2) AS VARCHAR(10)) + '%' AS Percentage
FROM dbo.dim_district
GROUP BY is_current;

-- ============================================================================
-- TEST 7: Audit Columns Population
-- ============================================================================
PRINT CHAR(10) + 'TEST 7: Audit Columns Population';
PRINT 'Expected: 0 rows with NULL dw_created_date or dw_updated_date';

SELECT
    district_key,
    district_name,
    dw_created_date,
    dw_updated_date
FROM dbo.dim_district
WHERE dw_created_date IS NULL OR dw_updated_date IS NULL;

IF (SELECT COUNT(*) FROM dbo.dim_district WHERE dw_created_date IS NULL OR dw_updated_date IS NULL) = 0
    PRINT 'PASS: All audit columns populated';
ELSE
    PRINT 'FAIL: Missing audit columns';

-- ============================================================================
-- TEST 8: Duplicate Business Keys
-- ============================================================================
PRINT CHAR(10) + 'TEST 8: Duplicate Business Keys';
PRINT 'Expected: 0 rows (no duplicates)';

SELECT
    district_id,
    COUNT(*) AS Duplicate_Count
FROM dbo.dim_district
WHERE district_key <> 0
GROUP BY district_id
HAVING COUNT(*) > 1;

IF (SELECT COUNT(*) FROM (
    SELECT district_id, COUNT(*) AS cnt FROM dbo.dim_district WHERE district_key <> 0 GROUP BY district_id HAVING COUNT(*) > 1
) x) = 0
    PRINT 'PASS: No duplicate business keys';
ELSE
    PRINT 'FAIL: Duplicate business keys found';

-- ============================================================================
-- TEST 9: Load Procedure Existence
-- ============================================================================
PRINT CHAR(10) + 'TEST 9: Load Procedure Existence';
PRINT 'Expected: sp_Load_dim_district exists';

SELECT
    ROUTINE_SCHEMA,
    ROUTINE_NAME,
    ROUTINE_TYPE,
    CREATED,
    LAST_ALTERED
FROM INFORMATION_SCHEMA.ROUTINES
WHERE ROUTINE_SCHEMA = 'dbo' AND ROUTINE_NAME = 'sp_Load_dim_district';

IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.ROUTINES WHERE ROUTINE_SCHEMA = 'dbo' AND ROUTINE_NAME = 'sp_Load_dim_district')
    PRINT 'PASS: Load procedure exists';
ELSE
    PRINT 'FAIL: Load procedure not found';

-- ============================================================================
-- TEST 10: Row Count Summary
-- ============================================================================
PRINT CHAR(10) + 'TEST 10: Row Count Summary';
PRINT 'Expected: 1 Unknown row + populated districts from staging';

SELECT
    'Total Rows' AS Metric,
    COUNT(*) AS Count_Value
FROM dbo.dim_district
UNION ALL
SELECT 'Unknown Rows', COUNT(*) FROM dbo.dim_district WHERE district_key = 0
UNION ALL
SELECT 'Current Records', COUNT(*) FROM dbo.dim_district WHERE is_current = 1
UNION ALL
SELECT 'Non-Current Records', COUNT(*) FROM dbo.dim_district WHERE is_current = 0
UNION ALL
SELECT 'Staging Districts (Active)', COUNT(DISTINCT DistrictId) FROM SkillStack_Staging.stg.USR_Districts WHERE IsActive = 1;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
PRINT CHAR(10) + '====================================================================';
PRINT 'TEST SUMMARY: All structure and design verification complete';
PRINT '====================================================================';
PRINT 'Execute sp_Load_dim_district next to test data loading';
