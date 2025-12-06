# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CTE Reporting is a SQL Server data warehouse project for Career and Technical Education (CTE) reporting. The project focuses on building dimensional models and supporting data infrastructure for the SkillStack_DW database, with emphasis on temporal analysis and regional reporting for Idaho education.

## Project Structure

```
CTE Reporting/
├── sql/
│   ├── 02_create_dim_date.sql               # Time dimension (2000-2040)
│   ├── 03_create_dim_cluster.sql            # Cluster dimension (17 rows)
│   ├── 03_load_dim_cluster.sql              # Load cluster dimension
│   ├── 04_create_dim_pathway.sql            # Pathway dimension (117 rows)
│   ├── 04_load_dim_pathway.sql              # Load pathway dimension
│   ├── 05_create_dim_specialty.sql          # Specialty dimension (112 rows)
│   ├── 05_load_dim_specialty.sql            # Load specialty dimension
│   ├── 06_alter_dim_badge_add_specialty_fk.sql  # Add FK constraint
│   ├── 07_create_dim_institution.sql        # Institution dimension (12 rows)
│   ├── 07_load_dim_institution.sql          # Load institution dimension
│   ├── 08_load_dim_user.sql                 # Load user dimension with Phase 2 enhancements
│   └── phase1_validation.sql                # Phase 1 validation tests
├── scripts/                                  # Python utility scripts
│   └── populate_dim_date.py                 # Populate dim_date table
├── PHASE_2_ENHANCEMENTS.md                  # Phase 2 roadmap and implementation status
├── Regions.txt                              # Idaho regions → counties → FIPS codes mapping
├── .env                                     # Database connection config (DO NOT COMMIT)
└── .gitignore                               # Git ignore patterns
```

## Architecture

### Data Warehouse Pattern: Kimball Dimensional Model

**Time Dimension (dim_date)**
- **Purpose**: Universal time dimension for fact table joins, supporting calendar and fiscal year analysis
- **Grain**: One row per day from 2000-01-01 to 2040-12-31 (14,976 rows)
- **Key Design Decisions**:
  - Primary key: INT YYYYMMDD format (e.g., 20240115 for Jan 15, 2024) - sortable, partition-friendly, efficient for DW
  - Dual year systems: Calendar year + Fiscal year (July 1 start) for Idaho education fiscal cycles
  - Includes both calendar and ISO week numbers for reporting flexibility
  - Federal holidays (11 total) + Idaho state holidays (2 additional: Human Rights Day, Idaho Day)

**Career/Technical Education Hierarchy (Phase 1 Complete)**
- **Cluster Dimension (dim_cluster)**: 17 CTE career clusters
  - Grain: One row per cluster with SCD Type 2 tracking
  - Attributes: cluster_id, cluster_name, cluster_code (4-char abbreviation), description
  - Examples: AGRI (Agriculture), ARCH (Architecture), ARTS (Arts), etc.

- **Pathway Dimension (dim_pathway)**: 117 career pathways
  - Grain: One row per pathway with SCD Type 2 tracking
  - Foreign Keys: cluster_key (maps to dim_cluster)
  - Attributes: pathway_id, pathway_name, pathway_code (4-char), description, icon_url
  - Phase 1 Achievement: 100% cluster mapping, 100% icon URLs populated

- **Specialty Dimension (dim_specialty)**: 112 specialties
  - Grain: One row per specialty with SCD Type 2 tracking
  - Foreign Keys: pathway_key (maps to dim_pathway)
  - Phase 2 Enhancements: required_badge_count, required_skill_count
  - Attributes: specialty_id, specialty_name, pathway_key, icon_url
  - Phase 2 Achievement: 100% badge counts, 100% skill counts calculated

- **Institution Dimension (dim_institution)**: 12 educational institutions
  - Grain: One row per institution (independent)
  - Attributes: institution_id, institution_name, institution_code, website_url
  - Note: Address and region data deferred to Phase 2+ (requires external sources)

**Regional Hierarchy (Supplementary)**
- Mapped in Regions.txt: 6 Idaho regions → 44 counties → FIPS codes
- Used for geographic analysis and reporting segmentation
- Region numbering: 1=Northern Idaho, 2=North Central, 3=Southwestern Idaho, 4=Southeastern Idaho, 5=South Central Idaho, 6=Eastern Idaho

### Connection Configuration

Database connection parameters are loaded from environment variables (see .env template):
- `SQL_SERVER`: SQL Server instance IP/hostname
- `SQL_USER`: Domain-qualified username
- `SQL_PASSWORD`: User password
- `SQL_ENCRYPT`: Enable TLS encryption (always true)
- `SQL_TRUST_SERVER_CERTIFICATE`: Trust self-signed certificates

## Commands

### Populate Time Dimension

```bash
python scripts/populate_dim_date.py
```

**What it does**:
- Generates 14,976 date records (2000-2040) with comprehensive calendar/fiscal/holiday attributes
- Connects to SkillStack_DW using ODBC Driver 17 for SQL Server
- Inserts in batches of 1,000 for performance
- Validates federal and Idaho state holidays including complex rules (e.g., Presidents' Day as 3rd Monday in Feb, Thanksgiving as 4th Thursday in Nov)
- Calculates fiscal attributes based on July 1 fiscal year start

**Prerequisites**:
- Python 3.6+ with packages: `pyodbc`, `python-dateutil`
- SQL Server ODBC Driver 17 installed on client machine
- Network connectivity to SQL Server instance
- Database user with INSERT permissions on SkillStack_DW.dbo.dim_date
- `.env` file configured with valid credentials

**Performance Note**: Typical runtime ~2-5 seconds for full 14,976 row insertion

### Create Time Dimension Schema

```bash
sqlcmd -S <server> -U <user> -P <password> -d SkillStack_DW -i sql/02_create_dim_date.sql
```

Or in SQL Server Management Studio: Open and execute `sql/02_create_dim_date.sql`

**What it does**:
- Creates dbo.dim_date table with YYYYMMDD INT clustered primary key
- Creates 5 nonclustered indexes optimized for common temporal analysis patterns:
  - `IX_dim_date_date`: Direct date joins from fact tables
  - `IX_dim_date_year_month`: Calendar year/month grouping
  - `IX_dim_date_fiscal_year_quarter`: Fiscal period analysis
  - `IX_dim_date_federal_holidays` / `IX_dim_date_idaho_holidays`: Filtered indexes for holiday queries

**Prerequisites**:
- SQL Server connection with database creation permissions
- SkillStack_DW database must exist

## Key Implementation Details

### Holiday Calculation Logic

**Federal Holidays** (11 total):
- Fixed dates: New Year's (1/1), Independence Day (7/4), Veterans Day (11/11), Christmas (12/25)
- Floating dates: MLK Day (3rd Mon Jan), Presidents' Day (3rd Mon Feb), Memorial Day (last Mon May), Labor Day (1st Mon Sep), Columbus Day (2nd Mon Oct), Thanksgiving (4th Thu Nov)
- Special: Juneteenth (6/19) only recognized from 2021 onward

**Idaho State Holidays** (2 additional):
- Human Rights Day: 3rd Monday in January (same date as MLK Day, but separate flag)
- Idaho Day: March 4 (or Friday 3/3 if Saturday, or Monday 3/5 if Sunday)

### Fiscal Calendar System

- **Fiscal Year**: Runs July 1 - June 30 (e.g., FY 2024 = Jul 1, 2023 to Jun 30, 2024)
- **Fiscal Quarter**: Q1 (Jul-Sep), Q2 (Oct-Dec), Q3 (Jan-Mar), Q4 (Apr-Jun)
- **Fiscal Month**: 1=July through 12=June (not calendar-aligned)
- **Fiscal Week**: Week number within fiscal year (1-53)

### Date Key Design

The YYYYMMDD integer format (e.g., 20240115):
- **Sortable**: Lexicographic sort matches chronological order
- **Partition-friendly**: Easy to partition by year/month using ranges
- **Human-readable**: Can be interpreted directly without decoding
- **Storage-efficient**: 4-byte INT vs 8-byte DATETIME for DW scale
- **Query-friendly**: No type conversion overhead when filtering by date

## Phase 2 Enhancements (Complete)

### Data Quality Metrics
- **dim_specialty.required_badge_count**: Counts distinct badges per specialty (100% coverage, range 0-56)
- **dim_specialty.required_skill_count**: Counts distinct skills per specialty (100% coverage, range 0-50)

### User Demographic Classification
- **dim_user.user_type**: Derived from IsHighSchool flag (100% coverage: 99.8% High School, 0.2% Post-Secondary)

### Dimension Codes
- **dim_cluster.cluster_code**: 4-character abbreviations (100% coverage: AGRI, ARCH, ARTS, BUSI, EDUC, etc.)
- **dim_pathway.pathway_code**: 4-character codes (100% coverage: FOOD, ANIM, CONS, TELE, TEAC, etc.)

See [PHASE_2_ENHANCEMENTS.md](PHASE_2_ENHANCEMENTS.md) for complete roadmap and priority matrix.

## Dimensional Model Design Patterns

### SCD Type 2 Implementation
All dimensions follow Slowly Changing Dimension Type 2:
- **Surrogate Keys**: IDENTITY(0,1) starting at 0
- **Unknown Row**: Every dimension has a key=0 row for NULL/unmapped values
- **Natural Keys**: Business identifiers (cluster_id, pathway_id, etc.)
- **Change Tracking**: is_current flag (1=current, 0=historical)
- **Effective Dating**: effective_date, expiration_date columns
- **Audit Fields**: dw_created_date, dw_updated_date

### MERGE-Based Loading
All load procedures use MERGE statement pattern:
- **Deduplication**: ROW_NUMBER() OVER (PARTITION BY natural_key ORDER BY ModifiedDate DESC)
- **Change Detection**: Comprehensive OR conditions on all attributes
- **Three Actions**:
  - INSERT: New records from staging
  - UPDATE: Changed records (marks old as is_current=0)
  - MARK DELETED: Inactive records
- **Error Handling**: Try/catch with job_execution_log insertion
- **Debug Mode**: @DebugMode parameter for PRINT statements

### Indexing Strategy
- **Clustered**: Primary key on surrogate key
- **Unique Nonclustered**: Natural key + is_current filter for SCD lookups
- **Foreign Key Indexes**: Nonclustered on FK columns
- **Filter Indexes**: WHERE is_current = 1 for common queries

## Development Notes

- **Database connection**: Uses ODBC Driver 17 for SQL Server (industry standard for cross-platform support)
- **Batch processing**: Python script inserts in 1,000-row batches to balance memory and round-trip efficiency
- **Error handling**: Script exits with code 1 on failure, code 0 on success (for scheduled task integration)
- **Idempotent schema**: SQL scripts drop and recreate objects, allowing safe re-execution during development
- **Idempotent loading**: MERGE procedures safe to run multiple times without creating duplicates
- **Environment-based config**: Never hardcode credentials; always use .env variables
- **.env is in .gitignore**: Credentials are never committed to repository
- **Testing**: Phase 1 validation suite includes table existence, row count, FK integrity, and hierarchy checks
