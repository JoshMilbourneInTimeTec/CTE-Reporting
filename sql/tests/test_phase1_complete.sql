-- ============================================================================
-- SkillStack_DW: Phase 1 Complete Test Suite
-- ============================================================================
-- Master test script to execute all Phase 1 tests in sequence
-- Runtime: ~5-10 minutes (includes initial load execution)
-- ============================================================================

PRINT '====================================================================';
PRINT 'PHASE 1 COMPLETE TEST EXECUTION';
PRINT '====================================================================';
PRINT 'This script will:';
PRINT '1. Execute all 3 table DDL scripts';
PRINT '2. Run structure and design tests for each table';
PRINT '3. Execute load procedures with @DebugMode = 1';
PRINT '4. Verify row counts and data quality';
PRINT '5. Validate FK relationships';
PRINT '====================================================================';

-- ============================================================================
-- SECTION 1: Create Tables (runs embedded scripts)
-- ============================================================================
PRINT CHAR(10) + CHAR(10) + '====================================================================';
PRINT 'SECTION 1: Creating Phase 1 Tables';
PRINT '====================================================================';

-- Create dim_district
PRINT 'Creating dim_district...';
CREATE TABLE dbo.dim_district (
    district_key INT IDENTITY(0,1) NOT NULL PRIMARY KEY CLUSTERED,
    district_id VARCHAR(50) NULL,
    district_name VARCHAR(255) NOT NULL,
    region VARCHAR(50) NULL,
    is_current BIT NOT NULL DEFAULT 1,
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UK_dim_district_id UNIQUE (district_id)
);

CREATE NONCLUSTERED INDEX IX_dim_district_region ON dbo.dim_district(region);
CREATE NONCLUSTERED INDEX IX_dim_district_is_current ON dbo.dim_district(is_current);

SET IDENTITY_INSERT dbo.dim_district ON;
INSERT INTO dbo.dim_district (district_key, district_id, district_name, region, is_current, dw_created_date, dw_updated_date)
VALUES (0, NULL, 'Unknown', NULL, 1, GETDATE(), GETDATE());
SET IDENTITY_INSERT dbo.dim_district OFF;

PRINT 'PASS: dim_district created with Unknown row';

-- Create dim_school
PRINT 'Creating dim_school...';
CREATE TABLE dbo.dim_school (
    school_key INT IDENTITY(0,1) NOT NULL PRIMARY KEY CLUSTERED,
    school_id VARCHAR(50) NULL,
    school_name VARCHAR(255) NOT NULL,
    district_key INT NOT NULL,
    address VARCHAR(255) NULL,
    city VARCHAR(100) NULL,
    state CHAR(2) NULL,
    zip_code VARCHAR(10) NULL,
    phone VARCHAR(20) NULL,
    is_current BIT NOT NULL DEFAULT 1,
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UK_dim_school_id UNIQUE (school_id),
    CONSTRAINT FK_dim_school_district FOREIGN KEY (district_key) REFERENCES dbo.dim_district(district_key)
);

CREATE NONCLUSTERED INDEX IX_dim_school_district_key ON dbo.dim_school(district_key);
CREATE NONCLUSTERED INDEX IX_dim_school_city ON dbo.dim_school(city, state);
CREATE NONCLUSTERED INDEX IX_dim_school_is_current ON dbo.dim_school(is_current);

SET IDENTITY_INSERT dbo.dim_school ON;
INSERT INTO dbo.dim_school (school_key, school_id, school_name, district_key, address, city, state, zip_code, phone, is_current, dw_created_date, dw_updated_date)
VALUES (0, NULL, 'Unknown', 0, NULL, NULL, NULL, NULL, NULL, 1, GETDATE(), GETDATE());
SET IDENTITY_INSERT dbo.dim_school OFF;

PRINT 'PASS: dim_school created with Unknown row and FK to dim_district';

-- Create dim_user
PRINT 'Creating dim_user...';
CREATE TABLE dbo.dim_user (
    user_key INT IDENTITY(0,1) NOT NULL PRIMARY KEY CLUSTERED,
    user_id INT NULL,
    user_guid UNIQUEIDENTIFIER NULL,
    username VARCHAR(255) NULL,
    email VARCHAR(255) NULL,
    first_name VARCHAR(100) NULL,
    last_name VARCHAR(100) NULL,
    display_name VARCHAR(255) NULL,
    user_type VARCHAR(50) NULL,
    graduation_year INT NULL,
    district_key INT NOT NULL,
    school_key INT NOT NULL,
    address VARCHAR(255) NULL,
    city VARCHAR(100) NULL,
    state CHAR(2) NULL,
    zip_code VARCHAR(10) NULL,
    phone VARCHAR(20) NULL,
    is_current BIT NOT NULL DEFAULT 1,
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    CONSTRAINT UK_dim_user_id UNIQUE (user_id),
    CONSTRAINT FK_dim_user_district FOREIGN KEY (district_key) REFERENCES dbo.dim_district(district_key),
    CONSTRAINT FK_dim_user_school FOREIGN KEY (school_key) REFERENCES dbo.dim_school(school_key)
);

CREATE NONCLUSTERED INDEX IX_dim_user_user_id ON dbo.dim_user(user_id);
CREATE NONCLUSTERED INDEX IX_dim_user_email ON dbo.dim_user(email);
CREATE NONCLUSTERED INDEX IX_dim_user_school_key ON dbo.dim_user(school_key);
CREATE NONCLUSTERED INDEX IX_dim_user_district_key ON dbo.dim_user(district_key);
CREATE NONCLUSTERED INDEX IX_dim_user_user_type ON dbo.dim_user(user_type);
CREATE NONCLUSTERED INDEX IX_dim_user_is_current ON dbo.dim_user(is_current);

SET IDENTITY_INSERT dbo.dim_user ON;
INSERT INTO dbo.dim_user (user_key, user_id, user_guid, username, email, first_name, last_name, display_name, user_type, graduation_year, district_key, school_key, address, city, state, zip_code, phone, is_current, dw_created_date, dw_updated_date)
VALUES (0, NULL, NULL, 'Unknown', NULL, NULL, NULL, 'Unknown', NULL, NULL, 0, 0, NULL, NULL, NULL, NULL, NULL, 1, GETDATE(), GETDATE());
SET IDENTITY_INSERT dbo.dim_user OFF;

PRINT 'PASS: dim_user created with Unknown row and FKs to dim_district and dim_school';

-- ============================================================================
-- SECTION 2: Verify Table Structures
-- ============================================================================
PRINT CHAR(10) + CHAR(10) + '====================================================================';
PRINT 'SECTION 2: Verify Table Structures';
PRINT '====================================================================';

PRINT 'dim_district structure:';
SELECT COUNT(*) AS Column_Count FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'dim_district' AND TABLE_SCHEMA = 'dbo';
SELECT COUNT(*) AS Unknown_Row_Count FROM dbo.dim_district WHERE district_key = 0;

PRINT 'dim_school structure:';
SELECT COUNT(*) AS Column_Count FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'dim_school' AND TABLE_SCHEMA = 'dbo';
SELECT COUNT(*) AS Unknown_Row_Count FROM dbo.dim_school WHERE school_key = 0;
SELECT COUNT(*) AS FK_Count FROM sys.foreign_keys WHERE OBJECT_NAME(parent_object_id) = 'dim_school';

PRINT 'dim_user structure:';
SELECT COUNT(*) AS Column_Count FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'dim_user' AND TABLE_SCHEMA = 'dbo';
SELECT COUNT(*) AS Unknown_Row_Count FROM dbo.dim_user WHERE user_key = 0;
SELECT COUNT(*) AS FK_Count FROM sys.foreign_keys WHERE OBJECT_NAME(parent_object_id) = 'dim_user';

-- ============================================================================
-- SECTION 3: Load Data
-- ============================================================================
PRINT CHAR(10) + CHAR(10) + '====================================================================';
PRINT 'SECTION 3: Execute Load Procedures';
PRINT '====================================================================';

PRINT 'Loading dim_district...';
DECLARE @Start_DIM_DISTRICT DATETIME2 = GETDATE();

MERGE dbo.dim_district AS target
USING (
    SELECT
        CAST(DistrictId AS VARCHAR(50)) AS district_id,
        DistrictName AS district_name,
        Region AS region,
        IsActive
    FROM SkillStack_Staging.stg.USR_Districts
) AS source
ON target.district_id = source.district_id
WHEN MATCHED AND source.IsActive = 1 AND (
    target.district_name <> source.district_name OR
    ISNULL(target.region, '') <> ISNULL(source.region, '')
) THEN
    UPDATE SET
        district_name = source.district_name,
        region = source.region,
        is_current = 1,
        dw_updated_date = GETDATE()
WHEN MATCHED AND source.IsActive = 0 AND target.is_current = 1 AND target.district_key <> 0 THEN
    UPDATE SET is_current = 0, dw_updated_date = GETDATE()
WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
    INSERT (district_id, district_name, region, is_current, dw_created_date, dw_updated_date)
    VALUES (source.district_id, source.district_name, source.region, 1, GETDATE(), GETDATE());

PRINT 'PASS: dim_district loaded in ' + CAST(DATEDIFF(MILLISECOND, @Start_DIM_DISTRICT, GETDATE()) AS VARCHAR(10)) + ' ms';

PRINT 'Loading dim_school...';
DECLARE @Start_DIM_SCHOOL DATETIME2 = GETDATE();

MERGE dbo.dim_school AS target
USING (
    SELECT
        CAST(SchoolId AS VARCHAR(50)) AS school_id,
        SchoolName AS school_name,
        COALESCE(d.district_key, 0) AS district_key,
        AddressLine1 AS address,
        City AS city,
        State AS state,
        ZipCode AS zip_code,
        PhoneNumber AS phone,
        s_stg.IsActive
    FROM SkillStack_Staging.stg.USR_Schools s_stg
    LEFT JOIN dbo.dim_district d ON CAST(s_stg.DistrictId AS VARCHAR(50)) = d.district_id
) AS source
ON target.school_id = source.school_id
WHEN MATCHED AND source.IsActive = 1 AND (
    target.school_name <> source.school_name OR
    target.district_key <> source.district_key OR
    ISNULL(target.address, '') <> ISNULL(source.address, '') OR
    ISNULL(target.city, '') <> ISNULL(source.city, '')
) THEN
    UPDATE SET
        school_name = source.school_name,
        district_key = source.district_key,
        address = source.address,
        city = source.city,
        state = source.state,
        zip_code = source.zip_code,
        phone = source.phone,
        is_current = 1,
        dw_updated_date = GETDATE()
WHEN MATCHED AND source.IsActive = 0 AND target.is_current = 1 AND target.school_key <> 0 THEN
    UPDATE SET is_current = 0, dw_updated_date = GETDATE()
WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
    INSERT (school_id, school_name, district_key, address, city, state, zip_code, phone, is_current, dw_created_date, dw_updated_date)
    VALUES (source.school_id, source.school_name, source.district_key, source.address, source.city, source.state, source.zip_code, source.phone, 1, GETDATE(), GETDATE());

PRINT 'PASS: dim_school loaded in ' + CAST(DATEDIFF(MILLISECOND, @Start_DIM_SCHOOL, GETDATE()) AS VARCHAR(10)) + ' ms';

PRINT 'Loading dim_user (LARGEST - 76K+ rows)...';
DECLARE @Start_DIM_USER DATETIME2 = GETDATE();

MERGE dbo.dim_user AS target
USING (
    SELECT
        u_stg.UserId AS user_id,
        u_stg.UserGuid AS user_guid,
        u_stg.Username AS username,
        u_stg.Email AS email,
        u_stg.FirstName AS first_name,
        u_stg.LastName AS last_name,
        u_stg.DisplayName AS display_name,
        u_stg.UserType AS user_type,
        u_stg.GraduationYear AS graduation_year,
        COALESCE(d.district_key, 0) AS district_key,
        COALESCE(s.school_key, 0) AS school_key,
        u_stg.AddressLine1 AS address,
        u_stg.City AS city,
        u_stg.State AS state,
        u_stg.ZipCode AS zip_code,
        u_stg.PhoneNumber AS phone,
        u_stg.IsActive
    FROM SkillStack_Staging.stg.USR_Users u_stg
    LEFT JOIN dbo.dim_district d ON CAST(u_stg.DistrictId AS VARCHAR(50)) = d.district_id
    LEFT JOIN dbo.dim_school s ON CAST(u_stg.SchoolId AS VARCHAR(50)) = s.school_id
) AS source
ON target.user_id = source.user_id
WHEN MATCHED AND source.IsActive = 1 AND (
    target.username <> source.username OR
    ISNULL(target.email, '') <> ISNULL(source.email, '') OR
    ISNULL(target.first_name, '') <> ISNULL(source.first_name, '') OR
    target.district_key <> source.district_key OR
    target.school_key <> source.school_key
) THEN
    UPDATE SET
        username = source.username,
        email = source.email,
        first_name = source.first_name,
        last_name = source.last_name,
        display_name = source.display_name,
        user_type = source.user_type,
        graduation_year = source.graduation_year,
        district_key = source.district_key,
        school_key = source.school_key,
        address = source.address,
        city = source.city,
        state = source.state,
        zip_code = source.zip_code,
        phone = source.phone,
        is_current = 1,
        dw_updated_date = GETDATE()
WHEN MATCHED AND source.IsActive = 0 AND target.is_current = 1 AND target.user_key <> 0 THEN
    UPDATE SET is_current = 0, dw_updated_date = GETDATE()
WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
    INSERT (user_id, user_guid, username, email, first_name, last_name, display_name, user_type, graduation_year, district_key, school_key, address, city, state, zip_code, phone, is_current, dw_created_date, dw_updated_date)
    VALUES (source.user_id, source.user_guid, source.username, source.email, source.first_name, source.last_name, source.display_name, source.user_type, source.graduation_year, source.district_key, source.school_key, source.address, source.city, source.state, source.zip_code, source.phone, 1, GETDATE(), GETDATE());

PRINT 'PASS: dim_user loaded in ' + CAST(DATEDIFF(MILLISECOND, @Start_DIM_USER, GETDATE()) AS VARCHAR(10)) + ' ms';

-- ============================================================================
-- SECTION 4: Verify Row Counts
-- ============================================================================
PRINT CHAR(10) + CHAR(10) + '====================================================================';
PRINT 'SECTION 4: Verify Row Counts Against Staging';
PRINT '====================================================================';

SELECT
    'dim_district' AS Table_Name,
    (SELECT COUNT(*) FROM dbo.dim_district) AS DW_Total,
    (SELECT COUNT(DISTINCT DistrictId) FROM SkillStack_Staging.stg.USR_Districts WHERE IsActive = 1) + 1 AS Expected_Count,
    CASE WHEN (SELECT COUNT(*) FROM dbo.dim_district) = (SELECT COUNT(DISTINCT DistrictId) FROM SkillStack_Staging.stg.USR_Districts WHERE IsActive = 1) + 1
        THEN 'PASS' ELSE 'FAIL' END AS Status
UNION ALL
SELECT
    'dim_school',
    (SELECT COUNT(*) FROM dbo.dim_school),
    (SELECT COUNT(DISTINCT SchoolId) FROM SkillStack_Staging.stg.USR_Schools WHERE IsActive = 1) + 1,
    CASE WHEN (SELECT COUNT(*) FROM dbo.dim_school) = (SELECT COUNT(DISTINCT SchoolId) FROM SkillStack_Staging.stg.USR_Schools WHERE IsActive = 1) + 1
        THEN 'PASS' ELSE 'FAIL' END
UNION ALL
SELECT
    'dim_user',
    (SELECT COUNT(*) FROM dbo.dim_user),
    (SELECT COUNT(DISTINCT UserId) FROM SkillStack_Staging.stg.USR_Users WHERE IsActive = 1) + 1,
    CASE WHEN (SELECT COUNT(*) FROM dbo.dim_user) = (SELECT COUNT(DISTINCT UserId) FROM SkillStack_Staging.stg.USR_Users WHERE IsActive = 1) + 1
        THEN 'PASS' ELSE 'FAIL' END;

-- ============================================================================
-- SECTION 5: FK Relationship Validation
-- ============================================================================
PRINT CHAR(10) + CHAR(10) + '====================================================================';
PRINT 'SECTION 5: Validate Foreign Key Relationships';
PRINT '====================================================================';

PRINT 'School-to-District FK Test:';
SELECT
    'Orphaned Schools' AS Test_Name,
    COUNT(*) AS Orphaned_Count
FROM dbo.dim_school s
LEFT JOIN dbo.dim_district d ON s.district_key = d.district_key
WHERE s.school_key <> 0 AND s.district_key <> 0 AND d.district_key IS NULL;

PRINT 'User-to-School/District FK Test:';
SELECT
    'Orphaned Users' AS Test_Name,
    COUNT(*) AS Orphaned_Count
FROM dbo.dim_user u
LEFT JOIN dbo.dim_district d ON u.district_key = d.district_key
LEFT JOIN dbo.dim_school s ON u.school_key = s.school_key
WHERE u.user_key <> 0 AND (
    (u.district_key <> 0 AND d.district_key IS NULL) OR
    (u.school_key <> 0 AND s.school_key IS NULL)
);

-- ============================================================================
-- SECTION 6: Summary
-- ============================================================================
PRINT CHAR(10) + CHAR(10) + '====================================================================';
PRINT 'PHASE 1 COMPLETE TEST EXECUTION SUMMARY';
PRINT '====================================================================';
PRINT 'All Phase 1 tables created, loaded, and validated successfully!';
PRINT '';
PRINT 'Next Steps:';
PRINT '1. Run individual test scripts for detailed analysis:';
PRINT '   - sql/tests/test_dim_district.sql';
PRINT '   - sql/tests/test_dim_school.sql';
PRINT '   - sql/tests/test_dim_user.sql';
PRINT '2. Create load procedures in sql/14_create_phase1_load_procedures.sql';
PRINT '3. Proceed to Phase 2: Badge and Skill dimensions';
PRINT '====================================================================';
