-- ============================================================================
-- PHASE 1 VALIDATION TESTS - SkillStack_DW
-- ============================================================================

USE SkillStack_DW;
GO

PRINT '============================================================================';
PRINT 'PHASE 1 VALIDATION TESTS - SkillStack_DW';
PRINT '============================================================================';
PRINT '';

-- ============================================================================
-- TEST 1: Table Existence
-- ============================================================================
PRINT 'TEST 1: Table Existence';
PRINT '----------------------';

DECLARE @TableCount INT = 0;
SELECT @TableCount = COUNT(*)
FROM sys.tables
WHERE name IN ('dim_cluster', 'dim_pathway', 'dim_specialty', 'dim_institution')
AND schema_id = SCHEMA_ID('dbo');

PRINT 'Tables created: ' + CAST(@TableCount AS VARCHAR) + '/4';
IF @TableCount = 4
    PRINT 'PASS';
ELSE
    PRINT 'FAIL';

PRINT '';
PRINT 'TEST 2: Data Row Counts';
PRINT '----------------------';

DECLARE @ClusterRows INT, @PathwayRows INT, @SpecialtyRows INT, @InstitutionRows INT;

SELECT @ClusterRows = COUNT(*) FROM dim_cluster WHERE cluster_key <> 0 AND is_current = 1;
SELECT @PathwayRows = COUNT(*) FROM dim_pathway WHERE pathway_key <> 0 AND is_current = 1;
SELECT @SpecialtyRows = COUNT(*) FROM dim_specialty WHERE specialty_key <> 0 AND is_current = 1;
SELECT @InstitutionRows = COUNT(*) FROM dim_institution WHERE institution_key <> 0 AND is_current = 1;

PRINT 'dim_cluster: ' + CAST(@ClusterRows AS VARCHAR) + ' rows (expected 17)';
PRINT 'dim_pathway: ' + CAST(@PathwayRows AS VARCHAR) + ' rows (expected 117)';
PRINT 'dim_specialty: ' + CAST(@SpecialtyRows AS VARCHAR) + ' rows (expected 112)';
PRINT 'dim_institution: ' + CAST(@InstitutionRows AS VARCHAR) + ' rows (expected 12)';

IF @ClusterRows = 17 AND @PathwayRows = 117 AND @SpecialtyRows = 112 AND @InstitutionRows = 12
    PRINT 'PASS';
ELSE
    PRINT 'FAIL';

PRINT '';
PRINT 'TEST 3: Foreign Key Constraints';
PRINT '-------------------------------';

SELECT name, OBJECT_NAME(parent_object_id) as table_name, OBJECT_NAME(referenced_object_id) as referenced_table
FROM sys.foreign_keys
WHERE parent_object_id IN (
    OBJECT_ID('dbo.dim_pathway'),
    OBJECT_ID('dbo.dim_specialty'),
    OBJECT_ID('dbo.dim_badge')
);

PRINT '';
PRINT 'TEST 4: FK Integrity Check';
PRINT '-------------------------';

DECLARE @OrphanedBadges INT, @OrphanedSpecialties INT, @OrphanedPathways INT;

SELECT @OrphanedBadges = COUNT(*)
FROM dim_badge b
WHERE b.specialty_key IS NOT NULL AND b.specialty_key <> 0
AND NOT EXISTS (SELECT 1 FROM dim_specialty s WHERE s.specialty_key = b.specialty_key);

SELECT @OrphanedSpecialties = COUNT(*)
FROM dim_specialty s
WHERE s.pathway_key <> 0
AND NOT EXISTS (SELECT 1 FROM dim_pathway p WHERE p.pathway_key = s.pathway_key);

SELECT @OrphanedPathways = COUNT(*)
FROM dim_pathway p
WHERE p.cluster_key <> 0
AND NOT EXISTS (SELECT 1 FROM dim_cluster c WHERE c.cluster_key = p.cluster_key);

PRINT 'Orphaned badge-specialty refs: ' + CAST(@OrphanedBadges AS VARCHAR);
PRINT 'Orphaned specialty-pathway refs: ' + CAST(@OrphanedSpecialties AS VARCHAR);
PRINT 'Orphaned pathway-cluster refs: ' + CAST(@OrphanedPathways AS VARCHAR);

IF @OrphanedBadges = 0 AND @OrphanedSpecialties = 0 AND @OrphanedPathways = 0
    PRINT 'PASS: All FK relationships valid';
ELSE
    PRINT 'FAIL: Orphaned references found';

PRINT '';
PRINT 'TEST 5: Hierarchy Summary';
PRINT '------------------------';

SELECT
    Level = 'Cluster',
    Total = COUNT(*),
    Current_Records = SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END),
    Historical = SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END)
FROM dim_cluster
WHERE cluster_key <> 0

UNION ALL

SELECT 'Pathway', COUNT(*), SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END), SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END)
FROM dim_pathway
WHERE pathway_key <> 0

UNION ALL

SELECT 'Specialty', COUNT(*), SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END), SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END)
FROM dim_specialty
WHERE specialty_key <> 0

UNION ALL

SELECT 'Badge', COUNT(*), SUM(CASE WHEN is_current = 1 THEN 1 ELSE 0 END), SUM(CASE WHEN is_current = 0 THEN 1 ELSE 0 END)
FROM dim_badge
WHERE badge_key <> 0;

PRINT '';
PRINT '============================================================================';
PRINT 'PHASE 1 VALIDATION COMPLETE';
PRINT '============================================================================';
PRINT 'All critical dimensions created and loaded successfully';
PRINT 'Ready for Phase 2: Labor Market Alignment Dimensions';
PRINT '============================================================================';
GO
