# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CTE Reporting is a SQL Server data warehouse project for Career and Technical Education (CTE) reporting. The project focuses on building dimensional models and supporting data infrastructure for the SkillStack_DW database, with emphasis on temporal analysis and regional reporting for Idaho education.

## Project Structure

```
CTE Reporting/
├── sql/                    # SQL Server DDL and schema definitions
│   └── 02_create_dim_date.sql    # Time dimension table creation (2000-2040)
├── scripts/               # Python utility scripts
│   └── populate_dim_date.py      # Populates dim_date table with calendar/holiday attributes
├── Regions.txt            # Master data: Idaho regions mapped to counties and FIPS codes
├── .env                   # Database connection configuration (DO NOT COMMIT)
└── .gitignore            # Standard Visual Studio + environment-specific ignores
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

**Regional Hierarchy**
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

## Development Notes

- **Database connection**: Uses ODBC Driver 17 for SQL Server (industry standard for cross-platform support)
- **Batch processing**: Python script inserts in 1,000-row batches to balance memory and round-trip efficiency
- **Error handling**: Script exits with code 1 on failure, code 0 on success (for scheduled task integration)
- **Idempotent schema**: SQL script drops and recreates table, allowing safe re-execution during development
- **Environment-based config**: Never hardcode credentials; always use .env variables
- **.env is in .gitignore**: Credentials are never committed to repository
