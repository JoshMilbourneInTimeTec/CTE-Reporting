# Next Week Startup Guide - Phase 3 Implementation

## Session Completion Summary

**Current Date:** Friday, December 5, 2024
**Phase Status:** Phase 2 ✅ Complete | Phase 3 📋 Ready to Start
**Repository:** All code committed and pushed to `main` branch

---

## What Was Completed This Week

### Documentation Updates
- ✅ Updated CLAUDE.md with Phase 2 summary and design patterns
- ✅ Created comprehensive README.md (500+ lines)
- ✅ Created PHASE_3_LABOR_MARKET_ALIGNMENT.md (labor market dimensions)
- ✅ Created PHASE_4_CLASSIFICATION_AND_WORKFLOW.md (classification dimensions)
- ✅ Created IMPLEMENTATION_ROADMAP.md (complete 8-week schedule)

### Phase 2 Data Quality Enhancements (Previously Completed)
- ✅ dim_specialty.required_badge_count (100% coverage)
- ✅ dim_specialty.required_skill_count (100% coverage)
- ✅ dim_cluster.cluster_code (100% coverage)
- ✅ dim_pathway.pathway_code (100% coverage)
- ✅ dim_user.user_type (100% coverage)

### All Code Committed & Pushed
- ✅ 4 commits total in December session
- ✅ All files committed to main branch
- ✅ Repository ready for next week's work

---

## Phase 3: Labor Market Alignment - Your Next Task

### What is Phase 3?

Phase 3 connects badges to real-world careers, occupations, and industry certifications. This enables workforce readiness reporting and labor market analysis.

**Estimated Duration:** 2-3 weeks
**Priority:** HIGH
**Complexity:** MEDIUM (introduces bridge tables, alignment scoring)

### Components to Implement

#### New Dimensions (4 tables)

| Table | Source | Rows | Files |
|-------|--------|------|-------|
| dim_career_group | stg.CL_CareerGroups | 18 | 2 (create + load) |
| dim_career | stg.CL_Careers | 24 | 2 (create + load) |
| dim_occupation | stg.CL_Occupations | 148 | 2 (create + load) |
| dim_certification | stg.CL_Certifications | 142 | 2 (create + load) |

#### Bridge Tables (3 tables)

| Bridge Table | Relationship | Files |
|--------------|--------------|-------|
| dim_badge_career_bridge | Badges ↔ Careers (many-to-many) | 2 (create + load) |
| dim_badge_occupation_bridge | Badges ↔ Occupations (many-to-many) | 2 (create + load) |
| dim_badge_certification_bridge | Badges ↔ Certifications (many-to-many) | 2 (create + load) |

**Total Files to Create:** 14 SQL scripts

### Key Features of Phase 3

1. **Alignment Strength Scoring**
   - 0.00-1.00 scale indicating how well badge prepares for career/occupation
   - Calculated using keyword matching and skill coverage
   - Pre-calculated for each badge-career-occupation combination

2. **Primary Pathway Flagging**
   - Each badge-career pair can have a "primary" relationship
   - Used for UI display and career recommendation
   - One primary per badge-career pair

3. **Labor Market Data**
   - Median salary
   - Job growth percentage
   - Education requirements
   - STEM classification

### Implementation Order (Week-by-Week)

**Week 1 (Next Week - December 9-13):**
- Mon-Tue: Create dim_career_group + dim_career tables and load procedures
- Wed-Thu: Create dim_occupation + dim_certification tables and load procedures
- Fri: Validate all dimension data, verify row counts, test FK integrity

**Week 2 (December 16-20):**
- Mon-Wed: Create 3 bridge tables (DDL)
- Thu-Fri: Create bridge table load procedures with alignment strength calculation

**Week 3 (December 23-27):**
- Load and validate all bridge tables
- Run comprehensive data quality tests
- Document any data issues or edge cases

### Starting Monday - First Steps

1. **Review Documentation**
   - Read [PHASE_3_LABOR_MARKET_ALIGNMENT.md](PHASE_3_LABOR_MARKET_ALIGNMENT.md) thoroughly
   - Understand schema design patterns
   - Review SQL code examples

2. **Verify Staging Data**
   ```sql
   -- Run these to confirm data availability
   SELECT COUNT(*) FROM SkillStack_Staging.stg.CL_CareerGroups;  -- Should be 18
   SELECT COUNT(*) FROM SkillStack_Staging.stg.CL_Careers;       -- Should be 24
   SELECT COUNT(*) FROM SkillStack_Staging.stg.CL_Occupations;  -- Should be 148
   SELECT COUNT(*) FROM SkillStack_Staging.stg.CL_Certifications; -- Should be 142
   ```

3. **Create First File**
   - Start with `sql/09_create_dim_career_group.sql`
   - Follow Phase 1 dimension patterns from existing files
   - Use the schema provided in PHASE_3 documentation

4. **Follow Established Patterns**
   - Copy structure from `sql/03_create_dim_cluster.sql` as template
   - Maintain consistent naming conventions
   - Include all SCD Type 2 attributes
   - Add comprehensive verification at end of script

---

## Key Files to Reference

### Documentation
- **[PHASE_3_LABOR_MARKET_ALIGNMENT.md](PHASE_3_LABOR_MARKET_ALIGNMENT.md)** - Complete Phase 3 specification
- **[IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)** - 8-week schedule and dependencies
- **[CLAUDE.md](CLAUDE.md)** - Design patterns and architecture
- **[README.md](README.md)** - Quick reference and validation queries

### Code Templates
- **`sql/03_create_dim_cluster.sql`** - Template for dimension table creation
- **`sql/03_load_dim_cluster.sql`** - Template for MERGE-based load procedure
- **`sql/04_create_dim_pathway.sql`** - Template with FK relationships
- **`sql/05_load_dim_specialty.sql`** - Template with calculated fields

### Validation
- **`sql/phase1_validation.sql`** - Data quality validation patterns
- **`sql/tests/`** - Unit test examples (if any exist)

---

## Development Checklist for Monday

- [ ] Read PHASE_3_LABOR_MARKET_ALIGNMENT.md completely
- [ ] Verify staging data exists (run COUNT queries above)
- [ ] Review sql/03_create_dim_cluster.sql as template
- [ ] Review sql/03_load_dim_cluster.sql for MERGE pattern
- [ ] Check IMPLEMENTATION_ROADMAP.md for this week's specific tasks
- [ ] Create sql/09_create_dim_career_group.sql (first file)
- [ ] Execute script and verify table creation
- [ ] Add unknown row (key=0) to table
- [ ] Create indexes
- [ ] Test: SELECT * FROM dim_career_group WHERE career_group_key = 0;

---

## Key Design Patterns to Remember

### SCD Type 2 Attributes (Include in Every Dimension)

```sql
is_current BIT NOT NULL DEFAULT 1,
effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
expiration_date DATETIME2 NULL,
dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),
```

### Unknown Row Insertion

```sql
SET IDENTITY_INSERT dbo.dim_[entity] ON;
INSERT INTO dbo.dim_[entity] (
    [entity]_key,
    [entity]_id,
    [entity]_name,
    is_current,
    dw_created_date,
    dw_updated_date
)
VALUES (
    0,          -- Always key=0 for Unknown
    -1,         -- Always -1 for Unknown
    'Unknown',  -- Always 'Unknown'
    1,          -- is_current=1
    GETDATE(),
    GETDATE()
);
SET IDENTITY_INSERT dbo.dim_[entity] OFF;
```

### Index Strategy

1. **Clustered Index:** Primary key (surrogate key)
2. **Unique Nonclustered:** Natural key + is_current=1
3. **Nonclustered:** Foreign keys
4. **Filter Index:** WHERE is_current = 1

### MERGE Pattern Structure

```sql
MERGE dbo.dim_[entity] AS target
USING (
    SELECT [source columns with deduplication]
    FROM staging tables
    WHERE [filter for latest/active records]
) AS source
ON target.natural_key = source.natural_key
   AND target.is_current = 1

-- UPDATE when attributes changed
WHEN MATCHED AND (
    target.column1 <> source.column1 OR ...
) THEN UPDATE SET ...

-- INSERT new records
WHEN NOT MATCHED BY TARGET AND source.IsActive = 1 THEN
    INSERT (...) VALUES (...)
```

---

## Common Commands You'll Use

### Test Staging Data

```sql
USE SkillStack_Staging;
SELECT TOP 10 * FROM stg.CL_CareerGroups;
SELECT TOP 10 * FROM stg.CL_Careers;
```

### Check Dimension After Load

```sql
USE SkillStack_DW;
SELECT COUNT(*) FROM dim_career_group WHERE career_group_key <> 0;
SELECT COUNT(*) FROM dim_career_group WHERE is_current = 1;
SELECT * FROM dim_career_group WHERE career_group_key = 0;  -- Unknown row
```

### Run Stored Procedure with Debug

```sql
EXEC dbo.sp_Load_dim_career_group @DebugMode = 1;
```

### Check for Errors

```sql
SELECT TOP 10 * FROM dbo.job_execution_log
WHERE step_name LIKE '%career%'
ORDER BY execution_end_time DESC;
```

---

## Common Pitfalls to Avoid

1. ❌ **Forgetting SET QUOTED_IDENTIFIER ON** at top of file
   - ✅ Always put it before CREATE PROCEDURE
   - This causes "MERGE failed" errors

2. ❌ **Using INT for CAST of IDs**
   - ✅ Use VARCHAR(50) for DistrictId, SchoolId, etc.
   - Some IDs contain text prefixes

3. ❌ **Forgetting Unknown row (key=0)**
   - ✅ Every dimension must have this
   - Required for NULL/unmapped value handling

4. ❌ **Missing change detection conditions**
   - ✅ Include all attributes in WHEN MATCHED AND (...)
   - Prevents duplicate records on re-runs

5. ❌ **Not using LEFT JOIN to parents**
   - ✅ Always use LEFT JOIN for FKs
   - Maps to Unknown (key=0) for missing parents

---

## Success Metrics for Phase 3

By end of Phase 3, you should have:

✅ 4 new dimensions (career_group, career, occupation, certification)
✅ 3 bridge tables (badge-career, badge-occupation, badge-certification)
✅ All tables load successfully with MERGE procedures
✅ Row counts match expected:
  - dim_career_group: 18 current
  - dim_career: 24 current
  - dim_occupation: 148 current
  - dim_certification: 142 current
✅ FK integrity validated (no orphaned records)
✅ Alignment strength calculated (0.00-1.00 range)
✅ Primary pathway flagging works (max 1 per badge)
✅ All procedures idempotent (safe to run multiple times)
✅ All code committed and pushed
✅ Comprehensive test coverage

---

## Questions to Answer Before Starting

1. **Do the staging tables exist?**
   - Run: `SELECT TOP 1 * FROM SkillStack_Staging.stg.CL_CareerGroups;`
   - Expected: Row appears with no errors

2. **Are all Phase 1 dimensions populated?**
   - Run: `SELECT COUNT(*) FROM dbo.dim_cluster WHERE is_current = 1;`
   - Expected: 17 (or close to it)

3. **Can you connect to the database?**
   - Try executing a simple query in SSMS
   - Verify credentials in .env file

4. **Are the Phase 1 procedures working?**
   - Run: `EXEC dbo.sp_Load_dim_cluster @DebugMode = 1;`
   - Should complete successfully

If any of these fail, contact team lead before starting Phase 3.

---

## Quick Reference: Phase 3 File Numbering

Files to create are numbered starting at 09:

```
09_create_dim_career_group.sql          ← Start here (Monday AM)
09_load_dim_career_group.sql
10_create_dim_career.sql                ← Monday-Tuesday
10_load_dim_career.sql
11_create_dim_occupation.sql            ← Wednesday
11_load_dim_occupation.sql
12_create_dim_certification.sql         ← Wednesday
12_load_dim_certification.sql
13_create_badge_career_bridge.sql       ← Next week
13_load_badge_career_bridge.sql
14_create_badge_occupation_bridge.sql
14_load_badge_occupation_bridge.sql
15_create_badge_certification_bridge.sql
15_load_badge_certification_bridge.sql
```

---

## Git Workflow for Phase 3

```bash
# Create feature branch
git checkout -b feature/phase-3-labor-market

# After implementing dimensions (end of Friday)
git add sql/09_*.sql sql/10_*.sql sql/11_*.sql sql/12_*.sql
git commit -m "Phase 3: Add career, occupation, and certification dimensions"
git push origin feature/phase-3-labor-market

# After implementing bridges (following week)
git add sql/13_*.sql sql/14_*.sql sql/15_*.sql
git commit -m "Phase 3: Add badge-career/occupation/certification bridges"
git push origin feature/phase-3-labor-market

# After testing/validation
gh pr create --title "Phase 3: Labor Market Alignment" \
  --body "Implements labor market dimensions and bridges for career alignment"

# After review/approval
git checkout main
git merge feature/phase-3-labor-market
git push origin main
```

---

## Weekend Prep (Optional)

If you want to get a head start:

1. Read PHASE_3_LABOR_MARKET_ALIGNMENT.md
2. Review the 4 staging tables structure
3. Familiarize yourself with the schema designs provided
4. Check that you can connect to the database
5. Review MERGE pattern from Phase 1 load procedures

**No code required** - Just preparation and understanding.

---

## Contact & Support Resources

- **Documentation:** Check [PHASE_3_LABOR_MARKET_ALIGNMENT.md](PHASE_3_LABOR_MARKET_ALIGNMENT.md)
- **Architecture:** Check [CLAUDE.md](CLAUDE.md)
- **Design Patterns:** Check `sql/03_create_dim_cluster.sql` (template)
- **Schedule:** Check [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)
- **Validation:** Check `sql/phase1_validation.sql` (examples)

---

## Session Complete! 🎉

**Status:** Phase 2 ✅ Complete | Phase 3 📋 Fully Documented & Ready
**Next Action:** Monday - Start Phase 3 labor market alignment
**Repository:** All changes committed and pushed to main

Good luck next week! Phase 3 is well-documented and ready to implement.

