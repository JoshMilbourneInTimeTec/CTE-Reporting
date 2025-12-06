# Phase 4: Classification & Workflow Dimensions

## Overview

Phase 4 implements flexible classification systems and workflow tracking dimensions. This phase enables flexible tagging, skill set grouping, and approval workflow analysis.

**Dependencies:** Phase 1 (dim_badge, dim_skill) and Phase 3 must be complete
**Timeline:** Estimated 1-2 weeks
**Priority:** MEDIUM - Enables workflow insights and flexible reporting

---

## Implementation Roadmap

### 1. dim_badge_tag Dimension

**Purpose:** Flexible badge classification and discovery tags

**Grain:** One row per badge tag (SCD Type 2)

**Source Data:**
- `stg.BDG_Tags` (13 rows) - Tag definitions

**Schema Design:**

```sql
CREATE TABLE dbo.dim_badge_tag (
    -- Primary Key
    tag_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- Natural Key
    tag_id INT NOT NULL,

    -- Descriptive Attributes
    tag_name NVARCHAR(100) NOT NULL,
    tag_description NVARCHAR(500),
    tag_category NVARCHAR(50),  -- e.g., "Industry", "Skill Level", "Duration"
    tag_color_code VARCHAR(7),   -- Hex color for UI display
    display_order INT,

    -- Status
    is_active BIT NOT NULL DEFAULT 1,

    -- SCD Type 2
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE()
);
```

**Load Procedure:** `sp_Load_dim_badge_tag`

**Validation:**
- Row count: 13 current tags
- Category distribution
- Unique tag names

---

### 2. dim_skill_set Dimension

**Purpose:** Groupings of related skills for competency-based reporting

**Grain:** One row per skill set (SCD Type 2)

**Source Data:**
- `stg.BDG_SkillSets` (12 rows)

**Schema Design:**

```sql
CREATE TABLE dbo.dim_skill_set (
    -- Primary Key
    skill_set_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- Natural Key
    skill_set_id INT NOT NULL,

    -- Descriptive Attributes
    skill_set_name NVARCHAR(255) NOT NULL,
    skill_set_description NVARCHAR(MAX),
    skill_set_type NVARCHAR(100),  -- e.g., "Technical", "Soft Skills", "Leadership"
    competency_level NVARCHAR(50),  -- e.g., "Beginner", "Intermediate", "Advanced"

    -- Organizational
    parent_skill_set_key INT NULL,  -- Self-referencing FK for hierarchy
    display_order INT,

    -- Status
    is_active BIT NOT NULL DEFAULT 1,

    -- SCD Type 2
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Constraints
    CONSTRAINT FK_skill_set_parent FOREIGN KEY (parent_skill_set_key)
        REFERENCES dbo.dim_skill_set(skill_set_key)
);
```

**Load Procedure:** `sp_Load_dim_skill_set`

**Validation:**
- Row count: 12 current skill sets
- Hierarchy integrity (no circular references)
- Parent-child relationships valid

---

### 3. dim_approval_set Dimension

**Purpose:** Approval workflows and configurations

**Grain:** One row per approval set (SCD Type 2)

**Source Data:**
- `stg.BDG_ApprovalSets` (145 rows)

**Schema Design:**

```sql
CREATE TABLE dbo.dim_approval_set (
    -- Primary Key
    approval_set_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- Natural Key
    approval_set_id INT NOT NULL,

    -- Descriptive Attributes
    approval_set_name NVARCHAR(255) NOT NULL,
    approval_set_description NVARCHAR(MAX),

    -- Workflow Configuration
    approval_type NVARCHAR(50),  -- e.g., "Sequential", "Parallel", "Single"
    required_approver_count INT,
    approval_timeout_days INT,
    escalation_enabled BIT DEFAULT 0,

    -- Notification & Tracking
    notification_recipients_count INT,
    audit_enabled BIT DEFAULT 1,

    -- Status
    is_active BIT NOT NULL DEFAULT 1,

    -- SCD Type 2
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE()
);
```

**Load Procedure:** `sp_Load_dim_approval_set`

**Validation:**
- Row count: 145 current approval sets
- Approval type values standardized
- Required approver count > 0

---

### 4. Bridge Tables for Classifications

#### 4.1 dim_badge_tag_bridge

**Purpose:** Many-to-many relationship between badges and tags

**Grain:** One row per badge-tag relationship

**Schema Design:**

```sql
CREATE TABLE dbo.dim_badge_tag_bridge (
    badge_tag_bridge_key INT IDENTITY(1,1) PRIMARY KEY,

    -- Foreign Keys
    badge_key INT NOT NULL,
    tag_key INT NOT NULL,

    -- Relationship Properties
    is_primary_tag BIT DEFAULT 0,
    tag_assignment_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    tag_relevance_score NUMERIC(3,2),  -- 0.00-1.00

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Constraints
    CONSTRAINT FK_bridge_badge_tag FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_bridge_tag FOREIGN KEY (tag_key)
        REFERENCES dbo.dim_badge_tag(tag_key),
    CONSTRAINT UQ_badge_tag_pair UNIQUE (badge_key, tag_key)
);

-- Indexes
CREATE NONCLUSTERED INDEX IX_badge_tag_bridge_badge
    ON dbo.dim_badge_tag_bridge(badge_key);
CREATE NONCLUSTERED INDEX IX_badge_tag_bridge_tag
    ON dbo.dim_badge_tag_bridge(tag_key);
```

**Load Procedure:** `sp_Load_dim_badge_tag_bridge`

**Logic:**
- Join badges to tags from source system
- Calculate tag relevance score based on tag usage frequency
- Mark primary tag for UI display

---

#### 4.2 dim_skill_set_skill_bridge

**Purpose:** Many-to-many relationship between skill sets and skills

**Grain:** One row per skill-set membership

**Schema Design:**

```sql
CREATE TABLE dbo.dim_skill_set_skill_bridge (
    skill_set_skill_bridge_key INT IDENTITY(1,1) PRIMARY KEY,

    -- Foreign Keys
    skill_set_key INT NOT NULL,
    skill_key INT NOT NULL,

    -- Relationship Properties
    proficiency_level NVARCHAR(50),  -- e.g., "Required", "Recommended", "Optional"
    sequence_order INT,
    importance_rating NUMERIC(3,2),  -- 0.00-1.00

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Constraints
    CONSTRAINT FK_bridge_skill_set FOREIGN KEY (skill_set_key)
        REFERENCES dbo.dim_skill_set(skill_set_key),
    CONSTRAINT FK_bridge_skill FOREIGN KEY (skill_key)
        REFERENCES dbo.dim_skill(skill_key),
    CONSTRAINT UQ_skill_set_skill_pair UNIQUE (skill_set_key, skill_key)
);

-- Indexes
CREATE NONCLUSTERED INDEX IX_skill_set_skill_bridge_skill_set
    ON dbo.dim_skill_set_skill_bridge(skill_set_key);
CREATE NONCLUSTERED INDEX IX_skill_set_skill_bridge_skill
    ON dbo.dim_skill_set_skill_bridge(skill_key);
```

**Load Procedure:** `sp_Load_dim_skill_set_skill_bridge`

**Logic:**
- Join skills to skill sets from source system
- Maintain proficiency level and importance ratings
- Ensure all required skills for skill set are mapped

---

#### 4.3 dim_badge_approval_set_bridge

**Purpose:** Link badges to their approval workflows

**Schema Design:**

```sql
CREATE TABLE dbo.dim_badge_approval_set_bridge (
    badge_approval_set_bridge_key INT IDENTITY(1,1) PRIMARY KEY,

    -- Foreign Keys
    badge_key INT NOT NULL,
    approval_set_key INT NOT NULL,

    -- Relationship Properties
    sequence_order INT,
    is_current_workflow BIT DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Constraints
    CONSTRAINT FK_bridge_badge_approval FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_bridge_approval_set FOREIGN KEY (approval_set_key)
        REFERENCES dbo.dim_approval_set(approval_set_key),
    CONSTRAINT UQ_badge_approval_pair UNIQUE (badge_key, approval_set_key)
);
```

---

## Fact Tables (Phase 4 Option)

### fact_badge_approval_events

Track approval workflow progression for analysis:

```sql
CREATE TABLE dbo.fact_badge_approval_events (
    badge_approval_event_key INT IDENTITY(1,1) PRIMARY KEY,

    -- Dimension Foreign Keys
    badge_key INT NOT NULL,
    user_key INT NOT NULL,  -- User requesting/creating badge
    approver_user_key INT,  -- User performing approval
    date_key INT NOT NULL,  -- Date of event
    approval_set_key INT NOT NULL,

    -- Event Details
    event_type VARCHAR(50),  -- "Submitted", "Approved", "Rejected", "Escalated"
    approval_step INT,
    comments NVARCHAR(MAX),

    -- Metrics
    days_in_approval INT,
    hours_in_approval INT,

    -- Status
    is_final_approval BIT DEFAULT 0,
    approval_status VARCHAR(50),  -- "Pending", "Approved", "Rejected"

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Constraints
    CONSTRAINT FK_fact_badge_approval_badge FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_fact_badge_approval_user FOREIGN KEY (user_key)
        REFERENCES dbo.dim_user(user_key),
    CONSTRAINT FK_fact_badge_approval_approver FOREIGN KEY (approver_user_key)
        REFERENCES dbo.dim_user(user_key),
    CONSTRAINT FK_fact_badge_approval_date FOREIGN KEY (date_key)
        REFERENCES dbo.dim_date(date_key),
    CONSTRAINT FK_fact_badge_approval_set FOREIGN KEY (approval_set_key)
        REFERENCES dbo.dim_approval_set(approval_set_key)
);

-- Indexes for analysis
CREATE NONCLUSTERED INDEX IX_fact_approval_badge
    ON dbo.fact_badge_approval_events(badge_key);
CREATE NONCLUSTERED INDEX IX_fact_approval_approver
    ON dbo.fact_badge_approval_events(approver_user_key);
CREATE NONCLUSTERED INDEX IX_fact_approval_date
    ON dbo.fact_badge_approval_events(date_key);
```

---

## Implementation Order

1. **Week 1:**
   - Create dim_badge_tag table + load procedure
   - Create dim_skill_set table + load procedure
   - Create dim_approval_set table + load procedure
   - Validate row counts

2. **Week 2:**
   - Create dim_badge_tag_bridge + load procedure
   - Create dim_skill_set_skill_bridge + load procedure
   - Create dim_badge_approval_set_bridge + load procedure
   - Validate all bridge table data

3. **Optional Week 3:**
   - Create fact_badge_approval_events table
   - Implement approval event logging from application
   - Build workflow metrics queries

---

## Reporting Queries (Examples)

### Badges by Tag

```sql
SELECT
    dbt.tag_name,
    dbt.tag_category,
    COUNT(DISTINCT dbtb.badge_key) as badge_count,
    AVG(dbtb.tag_relevance_score) as avg_relevance
FROM dbo.dim_badge_tag_bridge dbtb
INNER JOIN dbo.dim_badge_tag dbt ON dbtb.tag_key = dbt.tag_key
WHERE dbt.is_active = 1
AND dbt.is_current = 1
GROUP BY dbt.tag_name, dbt.tag_category
ORDER BY badge_count DESC
```

### Skill Set Completeness

```sql
SELECT TOP 20
    dss.skill_set_name,
    COUNT(DISTINCT dssb.skill_key) as skills_in_set,
    SUM(CASE WHEN dssb.proficiency_level = 'Required' THEN 1 ELSE 0 END) as required_skills,
    AVG(dssb.importance_rating) as avg_importance
FROM dbo.dim_skill_set_skill_bridge dssb
INNER JOIN dbo.dim_skill_set dss ON dssb.skill_set_key = dss.skill_set_key
WHERE dss.is_active = 1
AND dss.is_current = 1
GROUP BY dss.skill_set_name
ORDER BY skills_in_set DESC
```

### Badge Approval Workflow Analysis

```sql
SELECT
    das.approval_set_name,
    COUNT(DISTINCT dbasb.badge_key) as badges_with_workflow,
    das.required_approver_count,
    das.approval_timeout_days
FROM dbo.dim_badge_approval_set_bridge dbasb
INNER JOIN dbo.dim_approval_set das ON dbasb.approval_set_key = das.approval_set_key
WHERE das.is_active = 1
AND das.is_current = 1
GROUP BY das.approval_set_name, das.required_approver_count, das.approval_timeout_days
ORDER BY badges_with_workflow DESC
```

### Average Approval Time (if fact table implemented)

```sql
SELECT
    das.approval_set_name,
    COUNT(*) as approval_events,
    AVG(CAST(fbae.hours_in_approval AS FLOAT)) as avg_hours_to_approve,
    MAX(fbae.hours_in_approval) as max_hours_to_approve,
    MIN(fbae.hours_in_approval) as min_hours_to_approve
FROM dbo.fact_badge_approval_events fbae
INNER JOIN dbo.dim_approval_set das ON fbae.approval_set_key = das.approval_set_key
WHERE fbae.approval_status = 'Approved'
AND YEAR(dd.calendar_date) = YEAR(GETDATE())
GROUP BY das.approval_set_name
ORDER BY avg_hours_to_approve DESC
```

---

## Testing & Validation

### Data Quality Checks

```sql
-- Check bridge table orphans
SELECT COUNT(*) as orphaned_badge_tags
FROM dbo.dim_badge_tag_bridge
WHERE badge_key NOT IN (SELECT badge_key FROM dbo.dim_badge WHERE is_current = 1)
   OR tag_key NOT IN (SELECT tag_key FROM dbo.dim_badge_tag WHERE is_current = 1);

-- Check for multiple primary tags per badge
SELECT badge_key, COUNT(*) as primary_count
FROM dbo.dim_badge_tag_bridge
WHERE is_primary_tag = 1
GROUP BY badge_key
HAVING COUNT(*) > 1;

-- Validate skill set hierarchy (no circular references)
WITH RECURSIVE skill_set_hierarchy AS (
    SELECT skill_set_key, parent_skill_set_key, 0 as depth
    FROM dbo.dim_skill_set
    WHERE parent_skill_set_key IS NULL

    UNION ALL

    SELECT dss.skill_set_key, dss.parent_skill_set_key, sh.depth + 1
    FROM dbo.dim_skill_set dss
    INNER JOIN skill_set_hierarchy sh ON dss.parent_skill_set_key = sh.skill_set_key
    WHERE sh.depth < 10  -- Prevent infinite loops
)
SELECT * FROM skill_set_hierarchy WHERE depth >= 10;

-- Check proficiency level standardization
SELECT DISTINCT proficiency_level
FROM dbo.dim_skill_set_skill_bridge
WHERE proficiency_level NOT IN ('Required', 'Recommended', 'Optional')
```

---

## Files to Create

```
sql/
├── 16_create_dim_badge_tag.sql
├── 16_load_dim_badge_tag.sql
├── 17_create_dim_skill_set.sql
├── 17_load_dim_skill_set.sql
├── 18_create_dim_approval_set.sql
├── 18_load_dim_approval_set.sql
├── 19_create_badge_tag_bridge.sql
├── 19_load_badge_tag_bridge.sql
├── 20_create_skill_set_skill_bridge.sql
├── 20_load_skill_set_skill_bridge.sql
├── 21_create_badge_approval_set_bridge.sql
├── 21_load_badge_approval_set_bridge.sql
├── 22_create_fact_badge_approval_events.sql (optional)
└── tests/
    ├── test_dim_badge_tag.sql
    ├── test_dim_skill_set.sql
    ├── test_dim_approval_set.sql
    ├── test_classification_bridges.sql
    ├── test_workflow_hierarchy.sql
    └── test_classification_data_quality.sql
```

---

## Success Criteria

- ✅ All 3 classification dimensions created with SCD Type 2 tracking
- ✅ All 3 bridge tables created with proper FK constraints
- ✅ 100% data coverage validation for all tables
- ✅ No orphaned records in bridge tables
- ✅ Hierarchy integrity for skill sets (no circular references)
- ✅ Primary relationship flagging validated (e.g., primary_tag per badge)
- ✅ Reporting queries produce meaningful results
- ✅ Approval event tracking (if fact table implemented)

---

## Future Enhancements

- **Phase 5:** User competency tracking (fact table with user-skill mappings)
- **Phase 6:** Learning pathway recommendations using bridge table relationships
- **Phase 7:** Badge issuance analytics (fact tables combining all dimensions)

