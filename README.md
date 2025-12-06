# CTE Reporting - SkillStack Data Warehouse

A SQL Server-based dimensional data warehouse for Career and Technical Education (CTE) reporting, focusing on Idaho education analysis with emphasis on career pathways, skill development, and institutional reporting.

## 📊 Project Status

- ✅ **Phase 1**: Complete dimensional model with 5-level hierarchy (Cluster → Pathway → Specialty → Badge → Skill)
- ✅ **Phase 2**: Data quality enhancements implemented
- 🔄 **Phase 3**: Labor market alignment and bridge tables (planned)

## 🏗️ Architecture Overview

### Dimensional Model (Kimball Pattern)

```
┌─────────────────────────────────────────────────────────────┐
│                     SkillStack_DW                            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Cluster (17) ──FK──> Pathway (117) ──FK──> Specialty (112)│
│      ↓                                              ↓        │
│   Code: AGRI,          Code: FOOD,            Badge (800)   │
│   ARCH, ARTS...        ANIM, CONS...              ↓          │
│                                               Skill (5,689)  │
│                                                              │
│  User (76,823) ──> District ──> School                     │
│  Demographics                                               │
│  Type: High School                                          │
│        Post-Secondary                                       │
│                                                              │
│  Institution (12)  (Independent)                            │
│  Location, Contact                                          │
│                                                              │
│  Date (14,976 days from 2000-2040)  (Universal Time Dim)  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Key Features

**SCD Type 2 Implementation**
- ✅ Surrogate keys with IDENTITY(0,1)
- ✅ Unknown rows at key=0 for NULL mappings
- ✅ is_current flag for temporal tracking
- ✅ effective_date/expiration_date for versioning
- ✅ Audit fields (dw_created_date, dw_updated_date)

**MERGE-Based Loading**
- ✅ Deduplication via ROW_NUMBER()
- ✅ Comprehensive change detection
- ✅ Idempotent procedures (safe to run multiple times)
- ✅ Full error handling with job_execution_log
- ✅ @DebugMode for troubleshooting

## 📈 Dimensions

| Dimension | Records | Phase | Status | Key Enhancements |
|-----------|---------|-------|--------|------------------|
| **dim_cluster** | 17 | 1 | ✅ | cluster_code (4-char) |
| **dim_pathway** | 117 | 1 | ✅ | pathway_code, icon_url, FK to cluster |
| **dim_specialty** | 112 | 1 | ✅ | badge_count, skill_count (Phase 2) |
| **dim_badge** | 800 | Pre | ✅ | icon_url (98.75%), specialty_key FK |
| **dim_skill** | 5,689 | Pre | ✅ | badge_key FK, skill name |
| **dim_user** | 76,823 | Pre | ✅ | user_type (Phase 2), graduation_year |
| **dim_institution** | 12 | 1 | ✅ | institution_code, website_url |
| **dim_district** | 218 | Pre | ✅ | Regional hierarchy |
| **dim_school** | 839 | Pre | ✅ | District FK |
| **dim_date** | 14,976 | Pre | ✅ | Calendar + Fiscal year, Holidays |

## 🎯 Phase 2 Enhancements

### Data Quality Metrics
- **dim_specialty.required_badge_count**: 100% coverage (range 0-56, avg 7)
- **dim_specialty.required_skill_count**: 100% coverage (range 0-50, avg 8)

### Demographic Classification
- **dim_user.user_type**: 100% coverage
  - "High School": 76,684 users (99.8%)
  - "Post-Secondary": 139 users (0.2%)

### Dimension Codes
- **dim_cluster.cluster_code**: 100% (AGRI, ARCH, ARTS, BUSI, EDUC, FINA, GOVE, HEAL, HOSP, HUMA, INFO, LAW, MANU, MARK, SCIE, TRAN, CARE)
- **dim_pathway.pathway_code**: 100% (FOOD, ANIM, CONS, TELE, TEAC, and 112 others)

## 📂 File Structure

```
sql/
├── 02_create_dim_date.sql              # Time dimension (2000-2040)
├── 03_create_dim_cluster.sql           # Cluster dimension schema
├── 03_load_dim_cluster.sql             # Load cluster with SCD Type 2
├── 04_create_dim_pathway.sql           # Pathway dimension schema
├── 04_load_dim_pathway.sql             # Load pathway with codes & icons
├── 05_create_dim_specialty.sql         # Specialty dimension schema
├── 05_load_dim_specialty.sql           # Load specialty with metrics (Phase 2)
├── 06_alter_dim_badge_add_specialty_fk.sql  # Add specialty FK constraint
├── 07_create_dim_institution.sql       # Institution dimension schema
├── 07_load_dim_institution.sql         # Load institution data
├── 08_load_dim_user.sql                # Load user with user_type (Phase 2)
└── phase1_validation.sql               # Phase 1 validation tests

PHASE_2_ENHANCEMENTS.md                 # Complete Phase 2 roadmap
CLAUDE.md                               # Development guidance
README.md                               # This file
```

## 🚀 Quick Start

### Prerequisites
- SQL Server 2016+ (or Azure SQL Database)
- ODBC Driver 17 for SQL Server
- sqlcmd command-line tool
- SkillStack_Staging database loaded with staging tables

### Setup Steps

1. **Create SkillStack_DW database**
   ```sql
   CREATE DATABASE SkillStack_DW;
   ```

2. **Create time dimension** (if not exists)
   ```bash
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/02_create_dim_date.sql
   ```

3. **Create Phase 1 dimensions** (in order)
   ```bash
   # Cluster (no dependencies)
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/03_create_dim_cluster.sql

   # Pathway (depends on cluster)
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/04_create_dim_pathway.sql

   # Specialty (depends on pathway)
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/05_create_dim_specialty.sql

   # Institution (independent)
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/07_create_dim_institution.sql
   ```

4. **Load dimensions** (in order)
   ```bash
   # Load cluster with cluster_code generation
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/03_load_dim_cluster.sql \
     -v ON_ERROR=EXIT

   EXEC dbo.sp_Load_dim_cluster @DebugMode = 1;

   # Load pathway with pathway_code generation and cluster_key FK
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/04_load_dim_pathway.sql \
     -v ON_ERROR=EXIT

   EXEC dbo.sp_Load_dim_pathway @DebugMode = 1;

   # Load specialty with badge/skill count calculations
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/05_load_dim_specialty.sql \
     -v ON_ERROR=EXIT

   EXEC dbo.sp_Load_dim_specialty @DebugMode = 1;

   # Load institution
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/07_load_dim_institution.sql \
     -v ON_ERROR=EXIT

   EXEC dbo.sp_Load_dim_institution @DebugMode = 1;

   # Load user with user_type derivation
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/08_load_dim_user.sql \
     -v ON_ERROR=EXIT

   EXEC dbo.sp_Load_dim_user @DebugMode = 1;
   ```

5. **Validate Phase 1**
   ```bash
   sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW \
     -i sql/phase1_validation.sql
   ```

## 📊 Data Quality Validation

### Execute Validation Tests
```sql
USE SkillStack_DW;

-- Test 1: Table and row count validation
DECLARE @ClusterRows INT, @PathwayRows INT, @SpecialtyRows INT, @InstitutionRows INT;
SELECT @ClusterRows = COUNT(*) FROM dim_cluster WHERE cluster_key <> 0 AND is_current = 1;
SELECT @PathwayRows = COUNT(*) FROM dim_pathway WHERE pathway_key <> 0 AND is_current = 1;
SELECT @SpecialtyRows = COUNT(*) FROM dim_specialty WHERE specialty_key <> 0 AND is_current = 1;
SELECT @InstitutionRows = COUNT(*) FROM dim_institution WHERE institution_key <> 0 AND is_current = 1;

PRINT 'Cluster: ' + CAST(@ClusterRows AS VARCHAR) + ' (expected 17)';
PRINT 'Pathway: ' + CAST(@PathwayRows AS VARCHAR) + ' (expected 117)';
PRINT 'Specialty: ' + CAST(@SpecialtyRows AS VARCHAR) + ' (expected 112)';
PRINT 'Institution: ' + CAST(@InstitutionRows AS VARCHAR) + ' (expected 12)';

-- Test 2: Foreign key integrity
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

PRINT 'Orphaned badges: ' + CAST(@OrphanedBadges AS VARCHAR) + ' (expected 0)';
PRINT 'Orphaned specialties: ' + CAST(@OrphanedSpecialties AS VARCHAR) + ' (expected 0)';
PRINT 'Orphaned pathways: ' + CAST(@OrphanedPathways AS VARCHAR) + ' (expected 0)';

-- Test 3: Phase 2 enhancements
SELECT 'Specialties with badge_count' as Metric, COUNT(*) as Value
FROM dim_specialty
WHERE specialty_key <> 0 AND is_current = 1 AND required_badge_count IS NOT NULL
UNION ALL
SELECT 'Specialties with skill_count', COUNT(*)
FROM dim_specialty
WHERE specialty_key <> 0 AND is_current = 1 AND required_skill_count IS NOT NULL
UNION ALL
SELECT 'Users with user_type', COUNT(*)
FROM dim_user
WHERE user_key <> 0 AND is_current = 1 AND user_type IS NOT NULL
UNION ALL
SELECT 'Clusters with cluster_code', COUNT(*)
FROM dim_cluster
WHERE cluster_key <> 0 AND is_current = 1 AND cluster_code IS NOT NULL
UNION ALL
SELECT 'Pathways with pathway_code', COUNT(*)
FROM dim_pathway
WHERE pathway_key <> 0 AND is_current = 1 AND pathway_code IS NOT NULL;
```

## 📝 Documentation

- **[CLAUDE.md](CLAUDE.md)**: Development guidance, architecture patterns, and implementation details
- **[PHASE_2_ENHANCEMENTS.md](PHASE_2_ENHANCEMENTS.md)**: Complete Phase 2 roadmap with priority matrix
- **[Regions.txt](Regions.txt)**: Idaho regional hierarchy (6 regions → 44 counties → FIPS codes)

## 🔄 Loading Procedures

All dimensions use stored procedures following the MERGE pattern:

### Common Pattern
```sql
EXEC dbo.sp_Load_dim_<entity> @DebugMode = 0;
```

### Available Procedures
- `sp_Load_dim_cluster` - Load cluster dimension with code generation
- `sp_Load_dim_pathway` - Load pathway dimension with code/FK/icon generation
- `sp_Load_dim_specialty` - Load specialty with badge/skill count calculations
- `sp_Load_dim_institution` - Load institution dimension
- `sp_Load_dim_user` - Load user with type derivation

### Debug Mode
All procedures support `@DebugMode = 1` to print execution details:
```sql
EXEC dbo.sp_Load_dim_cluster @DebugMode = 1;
-- Output: Starting sp_Load_dim_cluster at 2025-12-05 17:54:36...
--         MERGE completed. Rows affected: 17
--         Completed sp_Load_dim_cluster at 2025-12-05 17:54:36...
```

## 🛠️ Troubleshooting

### Common Issues

**Issue**: `Msg 257, Syntax error... Conversion failed when converting the varchar value...`
- **Cause**: QUOTED_IDENTIFIER setting not ON at procedure creation time
- **Solution**: Ensure `SET QUOTED_IDENTIFIER ON;` is at top of script before CREATE PROCEDURE

**Issue**: Foreign key constraint violations
- **Cause**: Parent dimension not loaded before child dimension
- **Solution**: Load dimensions in order: Cluster → Pathway → Specialty

**Issue**: Duplicate records after procedure execution
- **Cause**: Procedure not idempotent
- **Solution**: Verify deduplication logic with ROW_NUMBER() in MERGE source

**Issue**: `job_execution_log` table not found
- **Cause**: Supporting infrastructure not created
- **Solution**: Ensure schema creation scripts executed first

## 📊 Common Queries

### View Hierarchy Structure
```sql
SELECT
    c.cluster_code,
    c.cluster_name,
    COUNT(DISTINCT p.pathway_key) as pathway_count,
    COUNT(DISTINCT s.specialty_key) as specialty_count,
    COUNT(DISTINCT b.badge_key) as badge_count
FROM dim_cluster c
LEFT JOIN dim_pathway p ON c.cluster_key = p.cluster_key AND p.is_current = 1
LEFT JOIN dim_specialty s ON p.pathway_key = s.pathway_key AND s.is_current = 1
LEFT JOIN dim_badge b ON s.specialty_key = b.specialty_key AND b.is_current = 1
WHERE c.cluster_key <> 0 AND c.is_current = 1
GROUP BY c.cluster_code, c.cluster_name
ORDER BY c.cluster_code;
```

### View User Demographics
```sql
SELECT
    user_type,
    COUNT(*) as user_count,
    COUNT(CASE WHEN graduation_year IS NOT NULL THEN 1 END) as with_grad_year
FROM dim_user
WHERE user_key <> 0 AND is_current = 1
GROUP BY user_type;
```

### View Specialty Metrics
```sql
SELECT TOP 20
    specialty_name,
    required_badge_count,
    required_skill_count,
    CAST(CAST(required_skill_count AS FLOAT) / CAST(required_badge_count AS FLOAT) AS NUMERIC(5,2)) as skills_per_badge
FROM dim_specialty
WHERE specialty_key <> 0 AND is_current = 1
ORDER BY required_skill_count DESC;
```

## 📞 Support

For questions or issues:
1. Check [CLAUDE.md](CLAUDE.md) for development guidance
2. Review [PHASE_2_ENHANCEMENTS.md](PHASE_2_ENHANCEMENTS.md) for enhancement details
3. Examine validation test results in `phase1_validation.sql`
4. Check `job_execution_log` table for execution errors

## 📜 License

Internal project for Idaho education CTE reporting.

## 🎉 Contributors

Created with Claude Code (claude.com/claude-code)
