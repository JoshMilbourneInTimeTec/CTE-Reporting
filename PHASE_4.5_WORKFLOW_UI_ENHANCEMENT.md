# Phase 4.5: Workflow Attributes & UI Enhancement

**Status:** Planned for implementation after Phase 4
**Duration:** 1 week
**Dependencies:** Phase 4 complete

---

## Overview

Phase 4.5 enhances Phase 4 dimensions by populating workflow attributes and implementing UI integration features. This phase enables the application layer to render rich classification and workflow management interfaces with colors, categories, hierarchies, and detailed workflow configurations.

---

## Objectives

1. **Populate Approval Workflow Attributes**
   - Approval types (Sequential, Parallel, Single)
   - Required approver counts
   - Approval timeout configurations
   - Escalation rules

2. **Implement Tag UI Attributes**
   - Tag categories (Assessment, Duration, Industry Level, etc.)
   - Color codes for visual display (hex colors)
   - Tag-to-tag relationships (related tags, tag families)

3. **Build Skill Set Hierarchy**
   - Implement parent-child skill set relationships
   - Create competency level mappings
   - Build skill set clusters

4. **Create UI-Ready Views**
   - Category-filtered tag views
   - Hierarchical skill set trees
   - Approval workflow configuration displays

---

## Implementation Plan

### Phase 4.5A: Approval Workflow Enhancement (Days 1-2)

#### Objective: Populate workflow attributes

**Tasks:**

1. **Analyze Current Approval Sets**
   - Query dim_approval_set to review all 99 workflows
   - Identify patterns in approval workflow names
   - Classify into: Sequential, Parallel, or Single approver

**File:** 26_analyze_approval_set_patterns.sql

2. **Create Workflow Configuration Control Table**
   ```sql
   CREATE TABLE ctl.ApprovalWorkflowConfiguration (
       approval_set_id INT PRIMARY KEY,
       approval_type VARCHAR(50),           -- Sequential, Parallel, Single
       required_approver_count INT,        -- 1, 2, 3, etc.
       approval_timeout_days INT,          -- 3, 5, 7, 10, 30
       escalation_enabled BIT,             -- 1 if escalation to manager
       notification_recipients_count INT,  -- How many to notify
       escalation_manager_level INT,       -- 1=direct mgr, 2=skip level
       can_auto_approve BIT,               -- Can workflow auto-complete
       requires_evidence BIT,              -- Must upload evidence
       metadata JSON,                      -- Additional config as JSON
       is_active BIT,
       effective_date DATETIME2,
       dw_created_date DATETIME2,
       dw_updated_date DATETIME2
   )
   ```

**File:** 26_create_approval_workflow_config_table.sql

3. **Populate Workflow Configuration Based on Rules**

   - Rule 1: Single Approver Workflows
     - Pattern: "course PSA" → Single approval, 1 approver, 10-day timeout
     - Example: "Intro to CAD Course PSA"
     - Count: ~40 workflows

   - Rule 2: Sequential Multi-Approver (Teacher → Department)
     - Pattern: "district level" or "regional" → Sequential, 2 approvers, 14-day timeout
     - Count: ~30 workflows

   - Rule 3: Parallel Approvals (Multiple reviewers same level)
     - Pattern: "requires review" → Parallel, 2-3 approvers, 7-day timeout
     - Count: ~20 workflows

   - Rule 4: Auto-Approve Workflows
     - Pattern: Prerequisite or foundational badges → Auto-approve, 0-day timeout
     - Count: ~9 workflows

**File:** 26_populate_approval_workflow_config.sql

4. **Update dim_approval_set with Config Data**
   ```sql
   UPDATE dim_approval_set
   SET
       approval_type = cfg.approval_type,
       required_approver_count = cfg.required_approver_count,
       approval_timeout_days = cfg.approval_timeout_days,
       escalation_enabled = cfg.escalation_enabled,
       notification_recipients_count = cfg.notification_recipients_count,
       dw_updated_date = GETDATE()
   FROM ctl.ApprovalWorkflowConfiguration cfg
   WHERE dim_approval_set.approval_set_id = cfg.approval_set_id
   ```

**File:** 26_update_dim_approval_set_attributes.sql

**Validation:**
- All 99 approval sets have approval_type populated
- required_approver_count between 1-5
- approval_timeout_days between 0-30
- escalation_enabled populated (0 or 1)
- No unexpected NULLs

---

### Phase 4.5B: Tag Category & Color Implementation (Days 3-4)

#### Objective: Add UI display attributes to tags

**Tasks:**

1. **Define Tag Categories**
   - Assessment: TSA, PSA (technical skills assessment tags)
   - Duration: For time-based tags (future)
   - Level: Secondary, Postsecondary (education level)
   - Industry: Agriculture, Business, Engineering, Health, Trades (industry sectors)
   - Status: Active, Aligned (status indicators)

2. **Define Color Palette**
   ```
   Assessment Tags:
     - TSA: #FF6B6B (Red)
     - PSA: #4ECDC4 (Teal)

   Level Tags:
     - Secondary: #95E1D3 (Mint)
     - Postsecondary: #F38181 (Coral)

   Industry Tags:
     - Agriculture: #8FD14F (Green)
     - Business: #4A90E2 (Blue)
     - Engineering: #FFB400 (Gold)
     - Health: #E85D75 (Rose)
     - Trades: #7030A0 (Purple)

   Status Tags:
     - Aligned: #5B9BD5 (Sky Blue)
   ```

**File:** 26_define_tag_categories_and_colors.sql

3. **Create Tag UI Configuration Table**
   ```sql
   CREATE TABLE ctl.TagUIConfiguration (
       tag_id INT PRIMARY KEY,
       tag_category VARCHAR(100),
       tag_color_code VARCHAR(7),          -- Hex color #RRGGBB
       icon_name VARCHAR(100),             -- Font Awesome icon name
       sort_order INT,                     -- Sort within category
       is_featured BIT,                    -- Show prominently
       description_short VARCHAR(256),     -- Short description for UI
       description_long VARCHAR(MAX),      -- Detailed description
       usage_count INT,                    -- How many badges use tag
       metadata JSON,                      -- Additional UI config
       dw_created_date DATETIME2,
       dw_updated_date DATETIME2
   )
   ```

**File:** 26_create_tag_ui_config_table.sql

4. **Populate Tag UI Configuration**
   ```sql
   INSERT INTO ctl.TagUIConfiguration
   SELECT
       tag_id,
       CASE tag_name
           WHEN 'TSA' THEN 'Assessment'
           WHEN 'PSA' THEN 'Assessment'
           WHEN 'Secondary' THEN 'Level'
           WHEN 'Postsecondary' THEN 'Level'
           WHEN 'Aligned' THEN 'Status'
           -- Industry tags
           WHEN 'Agriculture, Food & Natural Resources' THEN 'Industry'
           WHEN 'Business & Marketing Education' THEN 'Industry'
           WHEN 'Engineering & Technology Education' THEN 'Industry'
           WHEN 'Family and Consumer Sciences & Human Services' THEN 'Industry'
           WHEN 'Health Professions & Public Safety' THEN 'Industry'
           WHEN 'Trades & Industry' THEN 'Industry'
           WHEN 'Professional Development' THEN 'Industry'
           WHEN 'Workforce Training' THEN 'Industry'
       END,
       CASE tag_name
           WHEN 'TSA' THEN '#FF6B6B'
           WHEN 'PSA' THEN '#4ECDC4'
           -- ... etc
       END,
       -- Icon mappings
       CASE tag_name
           WHEN 'TSA' THEN 'fa-check-circle'
           WHEN 'PSA' THEN 'fa-trophy'
           -- ... etc
       END,
       -- ... remaining columns
   FROM (SELECT DISTINCT tag_id, tag_name FROM dim_badge_tag WHERE tag_key <> 0)
   ```

**File:** 26_populate_tag_ui_configuration.sql

5. **Update dim_badge_tag with UI Attributes**
   ```sql
   UPDATE dim_badge_tag
   SET
       tag_category = cfg.tag_category,
       tag_color_code = cfg.tag_color_code,
       display_order = cfg.sort_order,
       dw_updated_date = GETDATE()
   FROM ctl.TagUIConfiguration cfg
   WHERE dim_badge_tag.tag_id = cfg.tag_id
   ```

**File:** 26_update_dim_badge_tag_ui_attributes.sql

**Validation:**
- All 13 tags have tag_category populated
- All tags have tag_color_code in #RRGGBB format
- Colors are web-safe (valid hex values)
- display_order properly sequenced within categories

---

### Phase 4.5C: Skill Set Hierarchy Implementation (Days 5-6)

#### Objective: Build competency-based skill set hierarchy

**Tasks:**

1. **Analyze Current Skill Sets**
   - Review 12 skill sets and their RequiredNumber values
   - Identify natural groupings by competency level
   - Create hierarchy: Beginner → Intermediate → Advanced

2. **Define Skill Set Hierarchy**
   ```
   Root: "All Skills" (placeholder, skill_set_key = -1 conceptually)

   Level 1: Competency Groups
     - Beginner Skills (1-2 required skills)
     - Intermediate Skills (3-4 required skills)
     - Advanced Skills (5+ required skills)

   Level 2: Individual Skill Sets
     - Each current skill set under appropriate level
   ```

3. **Create Skill Set Hierarchy Control Table**
   ```sql
   CREATE TABLE ctl.SkillSetHierarchy (
       skill_set_id INT PRIMARY KEY,
       parent_skill_set_id INT NULL,       -- -1 for Root, or another skill_set_id
       skill_set_type VARCHAR(100),        -- 'Root', 'Level', 'Individual'
       competency_level VARCHAR(100),      -- 'Beginner', 'Intermediate', 'Advanced'
       hierarchy_level INT,                -- 0=Root, 1=Level, 2=Individual
       sort_order INT,                     -- Order within level
       is_expandable BIT,                  -- Can this node be collapsed/expanded in UI
       icon_name VARCHAR(100),             -- Font Awesome icon for UI
       description_short VARCHAR(256),
       metadata JSON,
       dw_created_date DATETIME2,
       dw_updated_date DATETIME2
   )
   ```

**File:** 27_create_skill_set_hierarchy_table.sql

4. **Populate Skill Set Hierarchy**

   Strategy: Create virtual "Competency Level" parent nodes

   ```sql
   -- Create root nodes for each competency level
   INSERT INTO ctl.SkillSetHierarchy
   VALUES
       (-1, NULL, 'Root', NULL, 0, 0, 1, 'fa-sitemap', 'All Skill Sets', NULL, GETDATE(), GETDATE()),
       (100, -1, 'Level', 'Beginner', 1, 1, 1, 'fa-star', 'Beginner Skills (1-2 required)', NULL, GETDATE(), GETDATE()),
       (101, -1, 'Level', 'Intermediate', 1, 2, 1, 'fa-star-half', 'Intermediate Skills (3-4 required)', NULL, GETDATE(), GETDATE()),
       (102, -1, 'Level', 'Advanced', 1, 3, 1, 'fa-star-full', 'Advanced Skills (5+ required)', NULL, GETDATE(), GETDATE());

   -- Map individual skill sets to competency levels
   INSERT INTO ctl.SkillSetHierarchy
   SELECT
       skill_set_id,
       CASE
           WHEN required_count <= 2 THEN 100  -- Beginner parent
           WHEN required_count <= 4 THEN 101  -- Intermediate parent
           ELSE 102                            -- Advanced parent
       END as parent_skill_set_id,
       'Individual',
       CASE
           WHEN required_count <= 2 THEN 'Beginner'
           WHEN required_count <= 4 THEN 'Intermediate'
           ELSE 'Advanced'
       END as competency_level,
       2,                                     -- hierarchy_level
       skill_set_id,                          -- sort_order
       0,                                     -- is_expandable (leaf node)
       'fa-book',                             -- icon
       -- ... other columns
   FROM dim_skill_set
   WHERE skill_set_key <> 0
   ```

**File:** 27_populate_skill_set_hierarchy.sql

5. **Update dim_skill_set with Parent References**
   ```sql
   UPDATE dim_skill_set
   SET
       parent_skill_set_key = CASE
           WHEN STRING_LIKE(competency_level, '%1%') THEN 100
           WHEN STRING_LIKE(competency_level, '%3%') THEN 101
           WHEN STRING_LIKE(competency_level, '%5%') THEN 102
           ELSE NULL
       END,
       skill_set_type = 'Badge-Specific',
       dw_updated_date = GETDATE()
   WHERE skill_set_key <> 0
   ```

**File:** 27_update_dim_skill_set_hierarchy.sql

**Validation:**
- All skill sets have parent_skill_set_key assigned or NULL (for Unknown)
- Hierarchy is acyclic (no circular references)
- All parent FKs are valid
- 3 competency levels created with correct skill mappings

---

### Phase 4.5D: Tag-to-Tag Relationships (Day 6)

#### Objective: Enable tag discovery and related tags

**Tasks:**

1. **Define Tag Relationships**
   - "Aligned" tags are related to all industry tags
   - Assessment tags (TSA/PSA) pair together conceptually
   - Education level tags (Secondary/Postsecondary) are distinct but complementary

2. **Create Tag Relationship Bridge Table**
   ```sql
   CREATE TABLE dbo.dim_tag_tag_bridge (
       tag_relationship_key INT IDENTITY(1,1) PRIMARY KEY CLUSTERED,
       source_tag_key INT NOT NULL,
       related_tag_key INT NOT NULL,
       relationship_type VARCHAR(50),      -- 'Related', 'Parent', 'Child', 'Similar'
       relevance_score NUMERIC(3,2),       -- 0.00-1.00 how related
       dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
       dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),
       CONSTRAINT FK_tag_tag_source FOREIGN KEY (source_tag_key)
           REFERENCES dim_badge_tag(tag_key),
       CONSTRAINT FK_tag_tag_related FOREIGN KEY (related_tag_key)
           REFERENCES dim_badge_tag(tag_key),
       CONSTRAINT UQ_tag_pair UNIQUE (source_tag_key, related_tag_key),
       CONSTRAINT CK_tag_not_self CHECK (source_tag_key <> related_tag_key)
   )
   ```

**File:** 27_create_dim_tag_tag_bridge.sql

3. **Populate Tag Relationships**
   ```sql
   -- Related: Assessment tags
   INSERT INTO dbo.dim_tag_tag_bridge
   VALUES (1, 2, 'Related', 0.95, GETDATE(), GETDATE())  -- TSA ↔ PSA

   -- Related: Education level tags form a pair
   INSERT INTO dbo.dim_tag_tag_bridge
   VALUES (3, 4, 'Related', 0.85, GETDATE(), GETDATE())  -- Secondary ↔ Postsecondary

   -- Related: All industry tags to Aligned tag
   INSERT INTO dbo.dim_tag_tag_bridge
   VALUES (5, 6, 'Related', 0.75, GETDATE(), GETDATE())  -- Aligned ↔ Agriculture
   -- ... repeat for all industry tags
   ```

**File:** 27_populate_dim_tag_tag_bridge.sql

**Validation:**
- Tag relationships created without errors
- No circular relationships
- All FKs valid
- Relevance scores between 0-1

---

### Phase 4.5E: Create UI-Ready Views (Day 7)

#### Objective: Build views for application rendering

**Tasks:**

1. **Create Tag Display View**
   ```sql
   CREATE VIEW v_badge_tags_with_ui AS
   SELECT
       db.badge_key,
       db.badge_name,
       dbt.tag_key,
       dbt.tag_name,
       dbt.tag_category,
       dbt.tag_color_code,
       dbt.display_order,
       cfg.icon_name,
       cfg.description_short,
       dbtb.related_tag_key,
       COUNT(*) OVER (PARTITION BY db.badge_key) as tag_count
   FROM dim_badge db
   LEFT JOIN dim_badge_tag_bridge dbtb ON db.badge_key = dbtb.badge_key
   LEFT JOIN dim_badge_tag dbt ON dbtb.tag_key = dbt.tag_key
   LEFT JOIN ctl.TagUIConfiguration cfg ON dbt.tag_id = cfg.tag_id
   WHERE db.is_current = 1 AND dbt.is_current = 1
   ```

**File:** 28_create_ui_badge_tag_view.sql

2. **Create Approval Workflow Display View**
   ```sql
   CREATE VIEW v_approval_workflows_with_config AS
   SELECT
       das.approval_set_key,
       das.approval_set_name,
       das.approval_set_description,
       das.approval_type,
       das.required_approver_count,
       das.approval_timeout_days,
       das.escalation_enabled,
       das.notification_recipients_count,
       CASE
           WHEN das.approval_type = 'Sequential' THEN 'Sequential workflow - one approver at a time'
           WHEN das.approval_type = 'Parallel' THEN 'Parallel workflow - multiple simultaneous approvers'
           WHEN das.approval_type = 'Single' THEN 'Single approval - one approver needed'
       END as workflow_description,
       das.is_active
   FROM dim_approval_set das
   WHERE das.is_current = 1
   ```

**File:** 28_create_ui_approval_view.sql

3. **Create Skill Set Hierarchy View**
   ```sql
   CREATE VIEW v_skill_set_hierarchy AS
   WITH RECURSIVE skill_hierarchy AS (
       SELECT
           skill_set_key,
           parent_skill_set_key,
           skill_set_name,
           competency_level,
           0 as hierarchy_depth
       FROM dim_skill_set
       WHERE parent_skill_set_key IS NULL AND skill_set_key = 0

       UNION ALL

       SELECT
           dss.skill_set_key,
           dss.parent_skill_set_key,
           dss.skill_set_name,
           dss.competency_level,
           sh.hierarchy_depth + 1
       FROM dim_skill_set dss
       INNER JOIN skill_hierarchy sh ON dss.parent_skill_set_key = sh.skill_set_key
   )
   SELECT * FROM skill_hierarchy
   WHERE skill_set_key <> 0
   ```

**File:** 28_create_skill_set_hierarchy_view.sql

4. **Create Category-Filtered Tag View**
   ```sql
   CREATE VIEW v_tags_by_category AS
   SELECT
       tag_category,
       tag_key,
       tag_name,
       tag_color_code,
       display_order,
       COUNT(*) OVER (PARTITION BY tag_category) as category_count
   FROM dim_badge_tag
   WHERE is_current = 1 AND tag_key <> 0
   ORDER BY tag_category, display_order
   ```

**File:** 28_create_tags_by_category_view.sql

**Validation:**
- All views return data without errors
- Views join correctly with no unexpected NULLs
- Recursive view properly expands hierarchy
- Query performance < 100ms

---

## Validation & Testing

### Data Validation Tests

1. **Approval Set Attributes**
   - All approval_type in ('Sequential', 'Parallel', 'Single')
   - required_approver_count between 1-5
   - approval_timeout_days between 0-30
   - No unexpected NULLs

2. **Tag UI Configuration**
   - All tags have category
   - All colors in valid hex format
   - display_order unique within category
   - No orphaned references

3. **Skill Set Hierarchy**
   - No circular parent references
   - All parent FKs valid or NULL
   - Competency levels match hierarchy depth

4. **Tag Relationships**
   - No self-references
   - All FKs valid
   - Relevance scores 0.00-1.00

### Query Performance Testing

1. Badge tag display (should < 50ms)
2. Approval workflow lookup (should < 25ms)
3. Skill set hierarchy traversal (should < 100ms)
4. Category tag filtering (should < 25ms)

### UI Preview Testing

1. Render tag display with colors
2. Show approval workflow configuration
3. Display skill set hierarchy tree
4. Show related tags suggestions

---

## Files to Create (13 total)

### Approval Workflow (4 files)
- 26_analyze_approval_set_patterns.sql
- 26_create_approval_workflow_config_table.sql
- 26_populate_approval_workflow_config.sql
- 26_update_dim_approval_set_attributes.sql

### Tag UI (3 files)
- 26_define_tag_categories_and_colors.sql
- 26_create_tag_ui_config_table.sql
- 26_populate_tag_ui_configuration.sql
- 26_update_dim_badge_tag_ui_attributes.sql

### Skill Set Hierarchy (3 files)
- 27_create_skill_set_hierarchy_table.sql
- 27_populate_skill_set_hierarchy.sql
- 27_update_dim_skill_set_hierarchy.sql

### Tag Relationships (2 files)
- 27_create_dim_tag_tag_bridge.sql
- 27_populate_dim_tag_tag_bridge.sql

### UI Views (3 files)
- 28_create_ui_badge_tag_view.sql
- 28_create_ui_approval_view.sql
- 28_create_skill_set_hierarchy_view.sql
- 28_create_tags_by_category_view.sql

---

## Deliverables

### SQL Scripts (13+ files, 1,500+ lines)
- Workflow configuration tables and procedures
- Tag UI attribute population
- Skill set hierarchy implementation
- Tag relationship bridges
- Application-ready views

### Documentation
- Phase 4.5 Completion Report
- UI Configuration Documentation
- Tag Category & Color Palette Reference
- Skill Set Hierarchy Guide
- Query Performance Benchmarks

### Configuration Tables
- ctl.ApprovalWorkflowConfiguration (exported)
- ctl.TagUIConfiguration (exported)
- ctl.SkillSetHierarchy (exported)

---

## Timeline

| Task | Duration | Days | Completion Date |
|------|----------|------|-----------------|
| Approval Workflow Enhancement | 2 days | 1-2 | TBD + 2 |
| Tag Category & Color Implementation | 2 days | 3-4 | TBD + 4 |
| Skill Set Hierarchy Implementation | 1 day | 5 | TBD + 5 |
| Tag-to-Tag Relationships | 1 day | 6 | TBD + 6 |
| UI-Ready Views | 1 day | 7 | TBD + 7 |
| **Total** | **7 days** | | |

---

## Success Criteria

✅ **Data Population**
- All 99 approval sets have attributes
- All 13 tags have UI configuration
- All 12 skill sets in hierarchy
- Tag relationships created

✅ **UI Readiness**
- Views return data for UI rendering
- Colors display properly (hex validation)
- Hierarchies render correctly
- All relationships accessible

✅ **Performance**
- All views < 100ms query time
- No N+1 query problems
- Indexes supporting view joins

✅ **Documentation**
- All configuration documented
- Color palette reference available
- Hierarchy rules explained
- Query examples provided

---

**Phase 4.5 Status:** Ready for implementation
**Estimated Start:** After Phase 4 completion
**Estimated Duration:** 1 week (7 working days)
