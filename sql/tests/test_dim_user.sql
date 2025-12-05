-- ============================================================================
-- SkillStack_DW: Unit Tests for dim_user
-- ============================================================================
-- Test Suite: 10 comprehensive tests for data quality and structure
-- LARGEST DIMENSION: 76,823 users + 1 Unknown = ~76,824 rows
-- ============================================================================

PRINT '====================================================================';
PRINT 'UNIT TESTS: dim_user (LARGEST DIMENSION: 76K+ rows)';
PRINT '====================================================================';

-- ============================================================================
-- TEST 1: Table Structure Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 1: Table Structure Verification';
PRINT 'Expected: All columns present including PII fields';

SELECT
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'dim_user'
ORDER BY ORDINAL_POSITION;

-- ============================================================================
-- TEST 2: Primary Key Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 2: Primary Key Verification';
PRINT 'Expected: PK_dim_user exists on user_key';

SELECT
    CONSTRAINT_NAME,
    COLUMN_NAME
FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
WHERE TABLE_NAME = 'dim_user' AND CONSTRAINT_NAME LIKE 'PK_%';

-- ============================================================================
-- TEST 3: Foreign Keys Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 3: Foreign Keys Verification';
PRINT 'Expected: 2 FKs to dim_district and dim_school';

SELECT
    fk.name AS FK_Constraint,
    COL_NAME(fc.parent_object_id, fc.parent_column_id) AS Child_Column,
    OBJECT_NAME(fk.referenced_object_id) AS Parent_Table,
    COL_NAME(fc.referenced_object_id, fc.referenced_column_id) AS Parent_Column
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fc ON fk.object_id = fc.constraint_object_id
WHERE OBJECT_NAME(fk.parent_object_id) = 'dim_user'
ORDER BY fk.name;

-- ============================================================================
-- TEST 4: Unknown Row Verification
-- ============================================================================
PRINT CHAR(10) + 'TEST 4: Unknown Row Verification';
PRINT 'Expected: 1 row with user_key=0, username="Unknown", district_key=0, school_key=0';

SELECT
    user_key,
    user_id,
    username,
    email,
    district_key,
    school_key,
    is_current,
    dw_created_date,
    dw_updated_date
FROM dbo.dim_user
WHERE user_key = 0;

IF (SELECT COUNT(*) FROM dbo.dim_user WHERE user_key = 0) = 1
    PRINT 'PASS: Unknown row exists';
ELSE
    PRINT 'FAIL: Unknown row missing or duplicate';

-- ============================================================================
-- TEST 5: No NULL Business Keys (Except Unknown Row)
-- ============================================================================
PRINT CHAR(10) + 'TEST 5: No NULL Business Keys (Except Unknown Row)';
PRINT 'Expected: 0 rows with NULL user_id (excluding Unknown row)';

SELECT
    user_key,
    user_id,
    username
FROM dbo.dim_user
WHERE user_key <> 0 AND user_id IS NULL;

IF (SELECT COUNT(*) FROM dbo.dim_user WHERE user_key <> 0 AND user_id IS NULL) = 0
    PRINT 'PASS: No NULL business keys found';
ELSE
    PRINT 'FAIL: NULL business keys found';

-- ============================================================================
-- TEST 6: Dual FK Orphaned Records Test
-- ============================================================================
PRINT CHAR(10) + 'TEST 6: Dual FK Orphaned Records Test';
PRINT 'Expected: 0 rows (no users with invalid district_key or school_key)';

SELECT COUNT(*) AS Orphaned_Count
FROM dbo.dim_user u
LEFT JOIN dbo.dim_district d ON u.district_key = d.district_key
LEFT JOIN dbo.dim_school s ON u.school_key = s.school_key
WHERE u.user_key <> 0  -- Exclude Unknown
  AND (
      (u.district_key <> 0 AND d.district_key IS NULL) OR
      (u.school_key <> 0 AND s.school_key IS NULL)
  );

IF (SELECT COUNT(*) FROM dbo.dim_user u
    LEFT JOIN dbo.dim_district d ON u.district_key = d.district_key
    LEFT JOIN dbo.dim_school s ON u.school_key = s.school_key
    WHERE u.user_key <> 0 AND (
      (u.district_key <> 0 AND d.district_key IS NULL) OR
      (u.school_key <> 0 AND s.school_key IS NULL)
    )) = 0
    PRINT 'PASS: No orphaned FK records';
ELSE
    PRINT 'FAIL: Orphaned FK records found';

-- ============================================================================
-- TEST 7: User Type Distribution
-- ============================================================================
PRINT CHAR(10) + 'TEST 7: User Type Distribution';
PRINT 'Expected: Shows distribution across user types (Student, Teacher, Admin, etc.)';

SELECT
    COALESCE(user_type, 'NULL') AS User_Type,
    COUNT(*) AS User_Count,
    CAST(ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM dbo.dim_user WHERE user_key <> 0), 2) AS VARCHAR(10)) + '%' AS Percentage
FROM dbo.dim_user
WHERE user_key <> 0
GROUP BY user_type
ORDER BY User_Count DESC;

-- ============================================================================
-- TEST 8: Duplicate Business Keys
-- ============================================================================
PRINT CHAR(10) + 'TEST 8: Duplicate Business Keys';
PRINT 'Expected: 0 rows (no duplicate user_ids)';

SELECT
    user_id,
    COUNT(*) AS Duplicate_Count
FROM dbo.dim_user
WHERE user_key <> 0
GROUP BY user_id
HAVING COUNT(*) > 1;

IF (SELECT COUNT(*) FROM (
    SELECT user_id, COUNT(*) AS cnt FROM dbo.dim_user WHERE user_key <> 0 GROUP BY user_id HAVING COUNT(*) > 1
) x) = 0
    PRINT 'PASS: No duplicate business keys';
ELSE
    PRINT 'FAIL: Duplicate business keys found';

-- ============================================================================
-- TEST 9: Email Uniqueness Check
-- ============================================================================
PRINT CHAR(10) + 'TEST 9: Email Uniqueness Check';
PRINT 'Expected: Most emails should be unique (excluding NULL and Unknown)';

SELECT
    'Total Non-Unknown Users' AS Metric,
    COUNT(*) AS Count_Value
FROM dbo.dim_user
WHERE user_key <> 0
UNION ALL
SELECT 'Users with Email', COUNT(*) FROM dbo.dim_user WHERE user_key <> 0 AND email IS NOT NULL
UNION ALL
SELECT 'Users with Duplicate Email', COUNT(DISTINCT email) FROM dbo.dim_user
    WHERE user_key <> 0 AND email IS NOT NULL
    AND email IN (
        SELECT email FROM dbo.dim_user WHERE user_key <> 0 AND email IS NOT NULL
        GROUP BY email HAVING COUNT(*) > 1
    )
UNION ALL
SELECT 'Unique Email Addresses', COUNT(DISTINCT email) FROM dbo.dim_user WHERE email IS NOT NULL;

-- ============================================================================
-- TEST 10: Audit Columns and Data Completeness
-- ============================================================================
PRINT CHAR(10) + 'TEST 10: Audit Columns and Data Completeness';
PRINT 'Expected: All audit columns populated, most user fields populated';

SELECT
    'Total Users (excl. Unknown)' AS Metric,
    COUNT(*) AS Count_Value
FROM dbo.dim_user
WHERE user_key <> 0
UNION ALL
SELECT 'Rows with dw_created_date', COUNT(*) FROM dbo.dim_user WHERE dw_created_date IS NOT NULL
UNION ALL
SELECT 'Rows with dw_updated_date', COUNT(*) FROM dbo.dim_user WHERE dw_updated_date IS NOT NULL
UNION ALL
SELECT 'Rows with username', COUNT(*) FROM dbo.dim_user WHERE user_key <> 0 AND username IS NOT NULL
UNION ALL
SELECT 'Rows with email', COUNT(*) FROM dbo.dim_user WHERE user_key <> 0 AND email IS NOT NULL
UNION ALL
SELECT 'Rows with first_name', COUNT(*) FROM dbo.dim_user WHERE user_key <> 0 AND first_name IS NOT NULL
UNION ALL
SELECT 'Rows with last_name', COUNT(*) FROM dbo.dim_user WHERE user_key <> 0 AND last_name IS NOT NULL
UNION ALL
SELECT 'Rows with graduation_year', COUNT(*) FROM dbo.dim_user WHERE user_key <> 0 AND graduation_year IS NOT NULL
UNION ALL
SELECT 'is_current = 1', COUNT(*) FROM dbo.dim_user WHERE is_current = 1;

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================
PRINT CHAR(10) + '====================================================================';
PRINT 'TEST SUMMARY: Large dimension structure and FK validation complete';
PRINT '====================================================================';
PRINT 'Execute sp_Load_dim_user next to test data loading (largest procedure)';
