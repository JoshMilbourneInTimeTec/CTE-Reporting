# Phase 4 Implementation Plan
## Classification & Workflow Dimensions

**Plan Date:** December 8, 2025
**Status:** READY FOR EXECUTION
**Estimated Duration:** 1-2 weeks (4 working days)

---

## Overview

Phase 4 adds flexible classification and workflow tracking capabilities to the data warehouse by implementing 3 dimensions and 2 bridge tables for tag-based badge classification and approval workflow management.

**Key Dependencies:**
- Phase 1 complete (dim_badge exists)
- Phase 3 complete (all labor market dimensions complete)
- Staging tables verified (BDG_Tags, BDG_SkillSets, BDG_ApprovalSets, BDG_BadgeTags, BDG_ApprovalSetSkills)

---

## Source Data Analysis

### BDG_Tags (13 rows)
- **Purpose:** Badge classification tags for discovery and reporting
- **Columns:** TagId (PK), Name, Description, Sort, PublicFilter, IsActive
- **Characteristics:**
  - All 13 rows have IsActive=1
  - Sort order provided (1-13)
  - Simple name-based tags (TSA, PSA, Secondary, etc.)
- **Schema Mapping:**
  - TagId → tag_id (natural key)
  - Name → tag_name
  - Sort → display_order
  - No category or color codes in source (will use defaults)

### BDG_SkillSets (12 rows)
- **Purpose:** Groupings of related skills with badge-set relationships
- **Columns:** SkillSetId (PK), BadgeId (FK), RequiredNumber, IsActive
- **Characteristics:**
  - Complex relationship: 12 skill sets across multiple badges
  - RequiredNumber indicates how many skills required from set
  - Maps badges to skill requirements
- **Schema Mapping:**
  - SkillSetId → skill_set_id (natural key)
  - Name: NOT IN SOURCE (will populate from badge names or create placeholders)
  - BadgeId → implies parent-badge relationship
  - RequiredNumber → competency_level value

### BDG_ApprovalSets (145 rows)
- **Purpose:** Approval workflow definitions for badge completion
- **Columns:** ApprovalSetId (PK), Name, Description, DateCreated, DateModified, DateDisabled, IsActive
- **Characteristics:**
  - 145 approval workflows
  - Most have descriptions (detailed names like "Residential Construction - Safe and Savvy Tools of the Trade Course")
  - DateDisabled indicates disabled workflows
  - Full audit trail available
- **Schema Mapping:**
  - ApprovalSetId → approval_set_id (natural key)
  - Name → approval_set_name
  - Description → approval_set_description
  - DateDisabled → expiration_date logic

### BDG_BadgeTags (1,028 rows)
- **Purpose:** Many-to-many bridge between badges and tags
- **Columns:** BadgeId (FK), TagId (FK), IsActive
- **Characteristics:**
  - 1,028 badge-tag relationships
  - Sparse matrix (800 badges × 13 tags = possible 10,400 combinations, only 1,028 populated)
  - All IsActive=1 in sample
- **Load Strategy:** Direct insert with FK integrity checks

### BDG_ApprovalSetSkills (250 rows)
- **Note:** Will explore after initial dimensions are planned

---

## Implementation Strategy

### Phase 4 Work Order

**Week 1: Dimensions (3 SQL files per dimension)**

1. **dim_badge_tag**
   - CREATE script: Define tag dimension with natural key, display attributes
   - LOAD script: MERGE from BDG_Tags with SCD Type 2 tracking
   - Files: 16_create_dim_badge_tag.sql, 16_load_dim_badge_tag.sql
   - Expected rows: 13 + 1 Unknown = 14

2. **dim_skill_set**
   - CREATE script: Define skill set dimension with badge relationship
   - LOAD script: MERGE from BDG_SkillSets
   - Challenge: BDG_SkillSets lacks standalone names; strategy is:
     * Join to dim_badge to get badge_name as skill_set_name default
     * Populate skill_set_description from badge requirements context
   - Files: 17_create_dim_skill_set.sql, 17_load_dim_skill_set.sql
   - Expected rows: 12 + 1 Unknown = 13

3. **dim_approval_set**
   - CREATE script: Define approval workflow dimension
   - LOAD script: MERGE from BDG_ApprovalSets with full SCD Type 2
   - Files: 18_create_dim_approval_set.sql, 18_load_dim_approval_set.sql
   - Expected rows: 145 + 1 Unknown = 146

**Week 1: Bridge Tables (2 SQL files per bridge)**

4. **dim_badge_tag_bridge**
   - CREATE script: Many-to-many relationship table
   - LOAD script: Direct insert from BDG_BadgeTags
   - Files: 19_create_badge_tag_bridge.sql, 19_load_badge_tag_bridge.sql
   - Expected rows: 1,028 relationships

5. **dim_approval_set_skill_bridge** (if needed)
   - Defer analysis until BDG_ApprovalSetSkills is examined
   - May skip if not essential to Phase 4 core

---

## Design Decisions

### 1. dim_badge_tag Dimension

**Rationale for Design:**
- Simple classification dimension (SCD Type 2 per standard)
- No hierarchy (unlike dim_skill_set)
- Direct staging table mapping available
- Limited to 13 values, simple MERGE logic

**Columns:**
```
tag_key (PK, IDENTITY 0,1)
tag_id (NK)
tag_name (NOT NULL)
tag_description (NULL, from source)
tag_category (NULL by design, placeholder for future UI categorization)
tag_color_code (NULL by design, placeholder for UI color coding)
display_order (from Sort column)
is_active (BIT)
is_current (SCD Type 2)
effective_date (SCD Type 2)
expiration_date (SCD Type 2)
dw_created_date (audit)
dw_updated_date (audit)
```

**Load Strategy:**
- Simple MERGE on tag_id with change detection on name, display_order
- All 13 tags are active, so straightforward insert
- Deduplication by ROW_NUMBER() OVER (PARTITION BY TagId ORDER BY ModifiedDate DESC)

**Indexes:**
- Clustered: tag_key (PK)
- Unique nonclustered: (tag_id, is_current)
- Nonclustered: (is_active, is_current) filtered WHERE is_current = 1
- Nonclustered: (display_order) for UI sorting

### 2. dim_skill_set Dimension

**Challenge:** BDG_SkillSets schema lacks independent skill set definitions; it's actually a junction table showing badge-to-skill-requirement mappings.

**Design Decision:**
Rather than treating this as a pure dimension, recognize it as:
- 12 skill set definitions (one per unique SkillSetId)
- Each SkillSetId represents a grouping for a specific badge
- RequiredNumber tells us how many skills from that set are needed

**Columns:**
```
skill_set_key (PK, IDENTITY 0,1)
skill_set_id (NK)
skill_set_name (derived from badge name or placeholder)
skill_set_description (from badge context or placeholder)
skill_set_type (NULL, placeholder for categorization)
competency_level (derived from RequiredNumber or NULL)
parent_skill_set_key (NULL, no hierarchy in source)
display_order (NULL, no ordering in source)
is_active (BIT)
is_current (SCD Type 2)
effective_date (SCD Type 2)
expiration_date (SCD Type 2)
dw_created_date (audit)
dw_updated_date (audit)
```

**Load Strategy:**
```sql
SELECT DISTINCT
    SkillSetId as skill_set_id,
    CONCAT('Skill Set for Badge ', bsk.BadgeId) as skill_set_name,  -- Placeholder
    NULL as skill_set_description,
    'Badge-Specific' as skill_set_type,
    CONCAT('Requires ', MIN(bsk.RequiredNumber), ' skills') as competency_level,
    NULL as parent_skill_set_key,
    ROW_NUMBER() OVER (ORDER BY SkillSetId) as display_order,
    IsActive
FROM SkillStack_Staging.stg.BDG_SkillSets bsk
```

**Indexes:**
- Clustered: skill_set_key
- Unique nonclustered: (skill_set_id, is_current)
- Nonclustered: (is_active, is_current) filtered
- Nonclustered: (parent_skill_set_key) for hierarchy traversal

### 3. dim_approval_set Dimension

**Rationale for Design:**
- Straightforward dimension with clear natural key
- 145 approval workflows, all with clear names and descriptions
- Active/inactive tracking via DateDisabled column
- SCD Type 2 standard application

**Columns:**
```
approval_set_key (PK, IDENTITY 0,1)
approval_set_id (NK)
approval_set_name (NOT NULL)
approval_set_description (from source, may be NULL)
approval_type (NULL, placeholder for Sequential/Parallel/Single)
required_approver_count (NULL, placeholder for workflow complexity)
approval_timeout_days (NULL, placeholder for SLA tracking)
escalation_enabled (BIT, default 0 for all)
notification_recipients_count (INT, NULL placeholder)
is_active (BIT)
is_current (SCD Type 2)
effective_date (SCD Type 2)
expiration_date (SCD Type 2)
dw_created_date (audit)
dw_updated_date (audit)
```

**Load Strategy:**
- MERGE on approval_set_id
- Detect changes on name, description
- Handle DateDisabled → expiration_date logic
- Set is_active = 0 when DateDisabled IS NOT NULL
- Deduplication via ROW_NUMBER() by ModifiedDate DESC

**Indexes:**
- Clustered: approval_set_key
- Unique nonclustered: (approval_set_id, is_current)
- Nonclustered: (is_active, is_current) filtered WHERE is_current = 1

### 4. dim_badge_tag_bridge

**Purpose:** Many-to-many badge-tag relationships

**Design:**
```
badge_tag_bridge_key (PK, IDENTITY 1,1)
badge_key (FK → dim_badge)
tag_key (FK → dim_badge_tag)
is_active (BIT, from source)
sequence_order (INT, from row number)
dw_created_date (audit)
dw_updated_date (audit)
UNIQUE (badge_key, tag_key)
```

**Load Strategy:**
- Simple DELETE/INSERT (not MERGE - junction table is transactional)
- Direct mapping: BadgeId → badge_key, TagId → tag_key
- Filter where badge and tag are both is_current=1

**Indexes:**
- Clustered: badge_tag_bridge_key
- Nonclustered: (badge_key) with INCLUDE (tag_key)
- Nonclustered: (tag_key) with INCLUDE (badge_key)

---

## File Naming Convention

Following Phase 3 pattern:
- Files 16-17: Dimensions
- File 18: Additional dimension
- File 19: Bridge tables

**Sequence:**
1. 16_create_dim_badge_tag.sql
2. 16_load_dim_badge_tag.sql
3. 17_create_dim_skill_set.sql
4. 17_load_dim_skill_set.sql
5. 18_create_dim_approval_set.sql
6. 18_load_dim_approval_set.sql
7. 19_create_badge_tag_bridge.sql
8. 19_load_badge_tag_bridge.sql

---

## Validation & Testing Plan

### Test 1: Row Count Validation
- dim_badge_tag: 14 rows (13 + Unknown)
- dim_skill_set: 13 rows (12 + Unknown)
- dim_approval_set: 146 rows (145 + Unknown)
- dim_badge_tag_bridge: 1,028 relationships

### Test 2: Unknown Row Verification
- All 3 dimensions have key=0, id=-1, name='Unknown'

### Test 3: Foreign Key Integrity
- dim_badge_tag_bridge.badge_key → dim_badge: 0 orphans
- dim_badge_tag_bridge.tag_key → dim_badge_tag: 0 orphans

### Test 4: SCD Type 2 Compliance
- All dimensions: is_current=1 for active records
- All dimensions: effective_date populated
- All dimensions: no updated_date < created_date anomalies

### Test 5: Natural Key Uniqueness
- All dimensions: 0 duplicate IDs with is_current=1

### Test 6: Audit Field Completeness
- All tables: dw_created_date and dw_updated_date populated
- All tables: proper temporal ordering

### Test 7: Sample Data Verification
- Spot-check badge-tag relationships
- Verify tag names match source
- Verify approval set names match source

---

## Risk Assessment & Mitigations

### Risk 1: dim_skill_set Naming
**Issue:** BDG_SkillSets lacks standalone names; must derive from badge relationship
**Mitigation:** Use CONCAT placeholder names; document as phase for refinement
**Severity:** LOW - Doesn't affect data integrity, only display names

### Risk 2: Approval Set Attributes
**Issue:** Source lacks workflow configuration details (approver count, timeout, etc.)
**Mitigation:** Leave columns NULL; document as Phase 4.5 enhancement
**Severity:** LOW - Columns are optional, design allows for future population

### Risk 3: Bridge Table Cardinality
**Issue:** 1,028 badge-tag relationships across 800 badges × 13 tags
**Verification:** Confirm no unexpected NULL values or missing FKs
**Severity:** LOW - Will validate post-load

---

## Success Criteria

✅ Phase 4 complete when:
1. All 3 dimensions created and populated correctly
2. All 2 bridge tables created and loaded
3. All 7 validation tests PASS
4. 0 errors in load procedures
5. All commits pushed to feature/joshmilbourne
6. Documentation complete (completion report + verification report)

---

## Implementation Order

**Do NOT deviate from this sequence** (as per CLAUDE.md: work on one table at a time):

1. ✋ Create dim_badge_tag → Verify all columns populate → Test
2. ✋ Create dim_skill_set → Verify all columns populate → Test
3. ✋ Create dim_approval_set → Verify all columns populate → Test
4. ✋ Create dim_badge_tag_bridge → Verify all columns populate → Test
5. ✋ Comprehensive validation & testing
6. ✋ Documentation & commit

---

## Estimated Effort

| Task | Effort | Notes |
|------|--------|-------|
| dim_badge_tag | 30 min | Simple, straightforward mapping |
| dim_skill_set | 45 min | Requires badge join context |
| dim_approval_set | 45 min | Standard SCD Type 2 |
| dim_badge_tag_bridge | 30 min | Junction table, simple load |
| Testing & Validation | 60 min | Comprehensive 7-test suite |
| Documentation | 45 min | Completion report + verification |
| **Total** | **~4 hours** | Can complete in 1 day |

---

## Sign-Off

This plan is ready for implementation. All source data has been analyzed, staging tables are verified, and design patterns are established based on Phase 3 success.

**Plan Status:** ✅ READY TO EXECUTE

**Next Step:** Proceed with dimension creation starting with dim_badge_tag.
