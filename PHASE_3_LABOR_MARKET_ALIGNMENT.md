# Phase 3: Labor Market Alignment & Bridge Tables

## Overview

Phase 3 implements labor market alignment dimensions and many-to-many relationship bridge tables. This phase connects career badges to real-world occupations, careers, and industry certifications, enabling workforce readiness and labor market analysis reporting.

**Dependencies:** Phase 1 (dim_badge, dim_skill) and Phase 2 must be complete
**Timeline:** Estimated 2-3 weeks
**Priority:** HIGH - Essential for career outcome reporting

---

## Implementation Roadmap

### 1. dim_career Dimension

**Purpose:** Represent career definitions, career groups, and labor market alignment

**Grain:** One row per career (SCD Type 2)

**Source Data:**
- `stg.CL_Careers` (24 rows) - Career definitions
- `stg.CL_CareerGroups` (18 rows) - Career groupings

**Schema Design:**

```sql
CREATE TABLE dbo.dim_career (
    -- Primary Key
    career_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- Natural Key & Business Identifiers
    career_id INT NOT NULL,
    career_guid UNIQUEIDENTIFIER,

    -- Descriptive Attributes
    career_name NVARCHAR(255) NOT NULL,
    career_description NVARCHAR(MAX),
    career_group_key INT NULL,  -- FK to dim_career_group
    career_group_name NVARCHAR(255),

    -- Labor Market Data
    median_salary NUMERIC(12,2),
    job_outlook_percentage NUMERIC(5,2),
    typical_education_level NVARCHAR(100),

    -- Additional Attributes
    is_high_demand BIT DEFAULT 0,
    priority_ordering INT,

    -- SCD Type 2
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Constraints
    CONSTRAINT FK_career_career_group FOREIGN KEY (career_group_key)
        REFERENCES dbo.dim_career_group(career_group_key)
);
```

**Load Procedure:** `sp_Load_dim_career`
- MERGE pattern from staging
- Deduplication by career_id
- SCD Type 2 tracking
- Change detection on all attributes

**Validation:**
- Row count: 24 current careers
- Foreign key integrity to dim_career_group
- No duplicate natural keys

---

### 2. dim_career_group Dimension

**Purpose:** Career groupings for hierarchical reporting

**Grain:** One row per career group (SCD Type 2)

**Source Data:**
- `stg.CL_CareerGroups` (18 rows)

**Schema Design:**

```sql
CREATE TABLE dbo.dim_career_group (
    -- Primary Key
    career_group_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- Natural Key
    career_group_id INT NOT NULL,

    -- Descriptive Attributes
    career_group_name NVARCHAR(255) NOT NULL,
    career_group_description NVARCHAR(MAX),
    display_order INT,

    -- SCD Type 2
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE()
);
```

**Load Procedure:** `sp_Load_dim_career_group`

**Validation:**
- Row count: 18 current career groups

---

### 3. dim_occupation Dimension

**Purpose:** SOC/O*NET occupations for workforce alignment

**Grain:** One row per occupation (SCD Type 2)

**Source Data:**
- `stg.CL_Occupations` (148 rows)
- `stg.EXT_CISOccupations` (593 rows) - O*NET alignment

**Schema Design:**

```sql
CREATE TABLE dbo.dim_occupation (
    -- Primary Key
    occupation_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- Natural Keys & Business Identifiers
    occupation_id INT NOT NULL,
    soc_code VARCHAR(10),           -- U.S. Bureau of Labor Statistics Standard Occupational Classification
    onet_code VARCHAR(10),          -- O*NET (Occupational Information Network) code

    -- Descriptive Attributes
    occupation_name NVARCHAR(255) NOT NULL,
    occupation_description NVARCHAR(MAX),
    education_required NVARCHAR(100),
    training_required NVARCHAR(100),

    -- Labor Market Data
    median_annual_wage NUMERIC(12,2),
    job_growth_percentage NUMERIC(5,2),
    typical_work_hours_per_week INT,

    -- Classification
    is_high_demand BIT DEFAULT 0,
    is_stem BIT DEFAULT 0,

    -- SCD Type 2
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE()
);
```

**Load Procedure:** `sp_Load_dim_occupation`

**Validation:**
- Row count: 148 current occupations (plus external O*NET data)
- SOC and O*NET code uniqueness

---

### 4. dim_certification Dimension

**Purpose:** Industry certifications and credentials

**Grain:** One row per certification (SCD Type 2)

**Source Data:**
- `stg.CL_Certifications` (142 rows)

**Schema Design:**

```sql
CREATE TABLE dbo.dim_certification (
    -- Primary Key
    certification_key INT IDENTITY(0,1) PRIMARY KEY CLUSTERED,

    -- Natural Key
    certification_id INT NOT NULL,

    -- Descriptive Attributes
    certification_name NVARCHAR(255) NOT NULL,
    certification_description NVARCHAR(MAX),
    issuing_organization NVARCHAR(255),
    certification_code VARCHAR(50),

    -- Validity & Requirements
    renewal_period_months INT,
    cost_usd NUMERIC(8,2),
    typical_preparation_hours INT,

    -- Classification
    is_industry_recognized BIT DEFAULT 1,
    is_stackable BIT DEFAULT 0,  -- Can be stacked toward degree
    priority_level INT,

    -- SCD Type 2
    is_current BIT NOT NULL DEFAULT 1,
    effective_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    expiration_date DATETIME2 NULL,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE()
);
```

**Load Procedure:** `sp_Load_dim_certification`

**Validation:**
- Row count: 142 current certifications
- Natural key uniqueness

---

### 5. Bridge Tables (Many-to-Many Relationships)

#### 5.1 dim_badge_career_bridge

**Purpose:** Many-to-many relationship between badges and careers

**Grain:** One row per badge-career relationship

**Source Data:**
- Join logic: Badges → Skills → Occupations → Careers

**Schema Design:**

```sql
CREATE TABLE dbo.dim_badge_career_bridge (
    badge_career_bridge_key INT IDENTITY(1,1) PRIMARY KEY,

    -- Foreign Keys
    badge_key INT NOT NULL,
    career_key INT NOT NULL,

    -- Relationship Properties
    alignment_strength NUMERIC(3,2),  -- 0.00-1.00 (1.0 = perfect alignment)
    is_primary_pathway BIT DEFAULT 0,
    sequence_order INT,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Constraints
    CONSTRAINT FK_bridge_badge FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_bridge_career FOREIGN KEY (career_key)
        REFERENCES dbo.dim_career(career_key),
    CONSTRAINT UQ_badge_career_pair UNIQUE (badge_key, career_key)
);

-- Indexes
CREATE NONCLUSTERED INDEX IX_badge_career_bridge_badge
    ON dbo.dim_badge_career_bridge(badge_key);
CREATE NONCLUSTERED INDEX IX_badge_career_bridge_career
    ON dbo.dim_badge_career_bridge(career_key);
```

**Load Procedure:** `sp_Load_dim_badge_career_bridge`

**Logic:**
- Link badges to skills to occupations to careers
- Calculate alignment strength based on keyword matching
- Mark primary pathway (highest alignment)

---

#### 5.2 dim_badge_occupation_bridge

**Purpose:** Many-to-many relationship between badges and occupations

**Schema Design:**

```sql
CREATE TABLE dbo.dim_badge_occupation_bridge (
    badge_occupation_bridge_key INT IDENTITY(1,1) PRIMARY KEY,

    -- Foreign Keys
    badge_key INT NOT NULL,
    occupation_key INT NOT NULL,

    -- Relationship Properties
    alignment_strength NUMERIC(3,2),
    is_primary_pathway BIT DEFAULT 0,
    sequence_order INT,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Constraints
    CONSTRAINT FK_bridge_badge_occ FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_bridge_occupation FOREIGN KEY (occupation_key)
        REFERENCES dbo.dim_occupation(occupation_key),
    CONSTRAINT UQ_badge_occupation_pair UNIQUE (badge_key, occupation_key)
);
```

---

#### 5.3 dim_badge_certification_bridge

**Purpose:** Many-to-many relationship between badges and certifications

**Schema Design:**

```sql
CREATE TABLE dbo.dim_badge_certification_bridge (
    badge_certification_bridge_key INT IDENTITY(1,1) PRIMARY KEY,

    -- Foreign Keys
    badge_key INT NOT NULL,
    certification_key INT NOT NULL,

    -- Relationship Properties
    certification_covers_percentage NUMERIC(5,2),  -- % of cert covered by badge
    is_prerequisite BIT DEFAULT 0,
    is_recommended BIT DEFAULT 0,
    sequence_order INT,

    -- Audit
    dw_created_date DATETIME2 NOT NULL DEFAULT GETDATE(),
    dw_updated_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    -- Constraints
    CONSTRAINT FK_bridge_badge_cert FOREIGN KEY (badge_key)
        REFERENCES dbo.dim_badge(badge_key),
    CONSTRAINT FK_bridge_certification FOREIGN KEY (certification_key)
        REFERENCES dbo.dim_certification(certification_key),
    CONSTRAINT UQ_badge_certification_pair UNIQUE (badge_key, certification_key)
);
```

---

## Implementation Order

1. **Week 1:**
   - Create dim_career_group table + load procedure
   - Create dim_career table + load procedure
   - Validate row counts and FK integrity

2. **Week 2:**
   - Create dim_occupation table + load procedure
   - Create dim_certification table + load procedure
   - Validate data quality

3. **Week 3:**
   - Create bridge tables: dim_badge_career_bridge
   - Create bridge tables: dim_badge_occupation_bridge
   - Create bridge tables: dim_badge_certification_bridge
   - Implement alignment strength calculation logic
   - Load and validate all bridge tables

---

## Key Design Decisions

### Alignment Strength Calculation

Bridge tables include `alignment_strength` (0.00-1.00) calculated based on:

```
alignment_strength = (keyword_matches / total_keywords) + skill_coverage_factor

- keyword_matches: Count of matching skill keywords
- total_keywords: Total keywords in both badge and career/occupation definitions
- skill_coverage_factor: % of required skills in occupation covered by badge skills
```

### Primary Pathway Flagging

`is_primary_pathway` flag marks the strongest relationship:

```sql
WITH RankedAlignments AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY badge_key ORDER BY alignment_strength DESC) as rn
    FROM calculated_alignments
)
SELECT *, CASE WHEN rn = 1 THEN 1 ELSE 0 END AS is_primary_pathway
FROM RankedAlignments
```

---

## Reporting Queries (Examples)

### Career Pathways for a Badge

```sql
SELECT TOP 10
    dc.career_name,
    dc.career_group_name,
    dbc.alignment_strength,
    dbc.is_primary_pathway
FROM dbo.dim_badge_career_bridge dbc
INNER JOIN dbo.dim_career dc ON dbc.career_key = dc.career_key
WHERE dbc.badge_key = ?
AND dbc.alignment_strength > 0.5
ORDER BY dbc.alignment_strength DESC
```

### Badge Preparation for Occupation

```sql
SELECT TOP 20
    db.badge_name,
    db.required_hours_to_complete,
    docc.occupation_name,
    docc.median_annual_wage,
    dob.alignment_strength
FROM dbo.dim_badge_occupation_bridge dob
INNER JOIN dbo.dim_badge db ON dob.badge_key = db.badge_key
INNER JOIN dbo.dim_occupation docc ON dob.occupation_key = docc.occupation_key
WHERE occ.soc_code = '15-1111'  -- Software Developers
AND dob.is_primary_pathway = 1
ORDER BY dob.alignment_strength DESC
```

### Certifications Covered by Badge

```sql
SELECT
    dc.certification_name,
    dc.issuing_organization,
    dbc.certification_covers_percentage,
    CASE WHEN dbc.is_prerequisite = 1 THEN 'Yes' ELSE 'No' END as is_prerequisite
FROM dbo.dim_badge_certification_bridge dbc
INNER JOIN dbo.dim_certification dc ON dbc.certification_key = dc.certification_key
WHERE dbc.badge_key = ?
AND dbc.is_recommended = 1
ORDER BY dbc.certification_covers_percentage DESC
```

---

## Testing & Validation

### Data Quality Checks

```sql
-- Check for orphaned badge records
SELECT COUNT(*) as orphaned_badge_records
FROM dbo.dim_badge_career_bridge
WHERE badge_key NOT IN (SELECT badge_key FROM dbo.dim_badge WHERE is_current = 1);

-- Check for orphaned career records
SELECT COUNT(*) as orphaned_career_records
FROM dbo.dim_badge_career_bridge
WHERE career_key NOT IN (SELECT career_key FROM dbo.dim_career WHERE is_current = 1);

-- Check alignment strength validity
SELECT COUNT(*) as invalid_alignment_strength
FROM dbo.dim_badge_career_bridge
WHERE alignment_strength < 0 OR alignment_strength > 1;

-- Check for multiple primary pathways per badge
SELECT badge_key, COUNT(*) as primary_count
FROM dbo.dim_badge_career_bridge
WHERE is_primary_pathway = 1
GROUP BY badge_key
HAVING COUNT(*) > 1;
```

---

## Dependencies & Blockers

- **External Data Required:** SOC codes, O*NET data (available from U.S. Bureau of Labor Statistics)
- **Source Data Gaps:** Career group names may need cleansing/standardization
- **Testing Data:** Sample badge-career-occupation alignment rules need to be defined

---

## Files to Create

```
sql/
├── 09_create_dim_career_group.sql
├── 09_load_dim_career_group.sql
├── 10_create_dim_career.sql
├── 10_load_dim_career.sql
├── 11_create_dim_occupation.sql
├── 11_load_dim_occupation.sql
├── 12_create_dim_certification.sql
├── 12_load_dim_certification.sql
├── 13_create_badge_career_bridge.sql
├── 13_load_badge_career_bridge.sql
├── 14_create_badge_occupation_bridge.sql
├── 14_load_badge_occupation_bridge.sql
├── 15_create_badge_certification_bridge.sql
├── 15_load_badge_certification_bridge.sql
└── tests/
    ├── test_dim_career.sql
    ├── test_dim_occupation.sql
    ├── test_dim_certification.sql
    ├── test_bridge_tables.sql
    └── test_labor_market_data_quality.sql
```

