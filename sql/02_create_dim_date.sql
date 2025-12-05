-- ============================================================================
-- File: sql/02_create_dim_date.sql
-- Purpose: Create the dim_date time dimension table for SkillStack_DW
-- Date Range: 2000-01-01 to 2040-12-31 (14,976 rows)
-- Features: Calendar attributes, fiscal year (July 1 start), federal/Idaho holidays
-- Design: INT YYYYMMDD primary key (industry standard for data warehouses)
-- ============================================================================

SET QUOTED_IDENTIFIER ON;
GO

USE SkillStack_DW;
GO

-- Drop table if it exists (allows re-creation during development)
IF OBJECT_ID('dbo.dim_date', 'U') IS NOT NULL
    DROP TABLE dbo.dim_date;
GO

-- ============================================================================
-- CREATE TABLE: dim_date
-- ============================================================================
CREATE TABLE dbo.dim_date (
    -- ========================================================================
    -- PRIMARY KEY: YYYYMMDD format (industry standard for DW)
    -- Example: 20240115 = January 15, 2024
    -- Benefits: Sortable, partition-friendly, human-readable, INT for efficiency
    -- ========================================================================
    date_key INT NOT NULL PRIMARY KEY CLUSTERED,

    -- ========================================================================
    -- DATE VALUE: Actual date for direct joins from fact tables
    -- ========================================================================
    date_value DATE NOT NULL UNIQUE,

    -- ========================================================================
    -- CALENDAR YEAR ATTRIBUTES
    -- ========================================================================
    year INT NOT NULL,
    quarter TINYINT NOT NULL,              -- 1-4
    month TINYINT NOT NULL,                -- 1-12
    month_name VARCHAR(20) NOT NULL,       -- 'January', 'February', etc.
    month_name_short CHAR(3) NOT NULL,     -- 'Jan', 'Feb', etc.
    day_of_month TINYINT NOT NULL,         -- 1-31
    day_of_year SMALLINT NOT NULL,         -- 1-366

    -- ========================================================================
    -- WEEK ATTRIBUTES
    -- Week_of_year: US standard (Sunday = first day of week)
    -- iso_week: ISO 8601 standard (Monday = first day of week)
    -- ========================================================================
    week_of_year TINYINT NOT NULL,         -- 1-53 (US standard, starts Sunday)
    iso_week TINYINT NOT NULL,             -- 1-53 (ISO 8601 standard, starts Monday)

    -- ========================================================================
    -- DAY ATTRIBUTES
    -- day_of_week: 1=Sunday, 2=Monday, ..., 7=Saturday (matches DATEPART(dw, date))
    -- ========================================================================
    day_of_week TINYINT NOT NULL,          -- 1=Sunday, 2=Monday, ..., 7=Saturday
    day_name VARCHAR(20) NOT NULL,         -- 'Sunday', 'Monday', etc.
    day_name_short CHAR(3) NOT NULL,       -- 'Sun', 'Mon', etc.

    -- ========================================================================
    -- WEEKEND/WEEKDAY FLAGS
    -- ========================================================================
    is_weekend BIT NOT NULL DEFAULT 0,     -- 1 if Saturday or Sunday
    is_weekday BIT NOT NULL DEFAULT 1,     -- 1 if Monday-Friday

    -- ========================================================================
    -- FISCAL YEAR ATTRIBUTES
    -- Fiscal year starts July 1
    -- Example: July 1, 2023 to June 30, 2024 = FY 2024
    -- Fiscal Quarter: Q1 (Jul-Sep), Q2 (Oct-Dec), Q3 (Jan-Mar), Q4 (Apr-Jun)
    -- Fiscal Month: 1=July, 2=August, ..., 12=June
    -- ========================================================================
    fiscal_year INT NOT NULL,              -- FY year
    fiscal_quarter TINYINT NOT NULL,       -- 1-4 (Q1: Jul-Sep, Q2: Oct-Dec, Q3: Jan-Mar, Q4: Apr-Jun)
    fiscal_month TINYINT NOT NULL,         -- 1-12 (1=July, 2=August, ..., 12=June)
    fiscal_week TINYINT NOT NULL,          -- 1-53 (week number within fiscal year)

    -- ========================================================================
    -- HOLIDAY FLAGS
    -- ========================================================================
    is_federal_holiday BIT NOT NULL DEFAULT 0,
    is_idaho_state_holiday BIT NOT NULL DEFAULT 0,
    holiday_name VARCHAR(100) NULL,        -- Name of holiday if applicable

    -- ========================================================================
    -- PERIOD END FLAGS (useful for period-end reporting)
    -- ========================================================================
    is_last_day_of_month BIT NOT NULL DEFAULT 0,
    is_last_day_of_quarter BIT NOT NULL DEFAULT 0,  -- Calendar quarter end
    is_last_day_of_year BIT NOT NULL DEFAULT 0,

    -- ========================================================================
    -- AUDIT FIELDS
    -- ========================================================================
    created_date DATETIME NOT NULL DEFAULT GETDATE(),
    modified_date DATETIME NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================================
-- INDEXES: Optimized for common temporal analysis patterns
-- ============================================================================

-- Index 2: Direct date joins from fact tables
-- Usage: fact_table JOIN dim_date ON fact_table.date_column = dim_date.date_value
CREATE UNIQUE NONCLUSTERED INDEX IX_dim_date_date
    ON dbo.dim_date(date_value);
GO

-- Index 3: Calendar year analysis and aggregations
-- Usage: GROUP BY year, quarter, month
CREATE NONCLUSTERED INDEX IX_dim_date_year_month
    ON dbo.dim_date(year, month)
    INCLUDE (quarter, month_name);
GO

-- Index 4: Fiscal year analysis and aggregations
-- Usage: GROUP BY fiscal_year, fiscal_quarter
CREATE NONCLUSTERED INDEX IX_dim_date_fiscal_year_quarter
    ON dbo.dim_date(fiscal_year, fiscal_quarter)
    INCLUDE (fiscal_month);
GO

-- Index 5: Filtered index for federal holiday analysis
-- Usage: WHERE is_federal_holiday = 1
-- This filtered index is small and improves holiday-specific queries
CREATE NONCLUSTERED INDEX IX_dim_date_federal_holidays
    ON dbo.dim_date(is_federal_holiday)
    WHERE is_federal_holiday = 1;
GO

-- Index 6: Filtered index for Idaho state holiday analysis
-- Usage: WHERE is_idaho_state_holiday = 1
CREATE NONCLUSTERED INDEX IX_dim_date_idaho_holidays
    ON dbo.dim_date(is_idaho_state_holiday)
    WHERE is_idaho_state_holiday = 1;
GO

-- ============================================================================
-- VERIFICATION
-- ============================================================================
PRINT '';
PRINT '============================================================================';
PRINT 'dim_date Table Created Successfully';
PRINT '============================================================================';
PRINT 'Clustered Index:       PK on date_key (YYYYMMDD format)';
PRINT 'Nonclustered Indexes:  5 indexes for temporal analysis';
PRINT '  - IX_dim_date_date                    (direct date joins)';
PRINT '  - IX_dim_date_year_month              (calendar year analysis)';
PRINT '  - IX_dim_date_fiscal_year_quarter     (fiscal year analysis)';
PRINT '  - IX_dim_date_federal_holidays        (federal holiday analysis)';
PRINT '  - IX_dim_date_idaho_holidays          (Idaho holiday analysis)';
PRINT '';
PRINT 'Table ready for population with 14,976 rows (2000-2040).';
PRINT '============================================================================';
PRINT '';
GO
