# Phase 3.5: Labor Market Data Integration

**Status:** Planned for implementation after Phase 4
**Duration:** 1-2 weeks
**Dependencies:** Phase 3 complete, external data sources available

---

## Overview

Phase 3.5 addresses the known limitations from Phase 3 by integrating external labor market data sources. This phase enhances the labor market dimensions with real-world occupational and economic data, enabling advanced career pathway analysis and labor market alignment scoring.

---

## Objectives

1. **Populate Missing Occupational Data**
   - SOC (Standard Occupational Classification) codes
   - O*NET (Occupational Information Network) codes
   - Complete occupational taxonomy

2. **Integrate Economic Data**
   - Median annual wages (by occupation)
   - Job growth projections (5-year and 10-year)
   - Employment demand levels

3. **Implement Career Grouping Logic**
   - Map careers to career groups using business rules
   - Validate career-group relationships
   - Document mapping methodology

4. **Enhance Alignment Scoring**
   - Develop nuanced alignment algorithms
   - Move from binary (0/1) to continuous (0.00-1.00) scoring
   - Implement skill-gap analysis

---

## Data Sources & Integration

### 1. Bureau of Labor Statistics (BLS) Data

**Source:** BLS API or exported datasets
- SOC codes and descriptions
- Occupational employment statistics
- Wage data (O*NET Compensation)
- Job outlook projections

**Integration Method:**
- Create staging tables: stg.BLS_SOCData, stg.BLS_WageData, stg.BLS_OutlookData
- Load via SSIS package or Python ETL script
- Validate data quality and completeness

**Expected Data:**
- 900+ SOC codes
- Wage ranges (25th, 50th, 75th percentile)
- Growth rates (% change over 5/10 years)

### 2. O*NET Database

**Source:** O*NET Center (onetcenter.org) or API
- O*NET codes (6-digit standard)
- Task descriptions
- Knowledge requirements
- Skills and abilities matrices

**Integration Method:**
- Download O*NET-SOC crosswalk file
- Create staging table: stg.ONET_Crosswalk
- Load and validate mappings

**Expected Data:**
- SOC ↔ O*NET mappings
- 1,000+ occupations with detailed attributes

### 3. Career Mapping Logic

**Source:** Business rules + data analysis
- Career-to-Career Group mappings
- Career-to-Occupation alignments
- Certification industry classifications

**Integration Method:**
- Develop mapping logic based on:
  - Career name similarity analysis
  - O*NET skill matching
  - Industry classification review
- Create control table: ctl.CareerGroupMapping
- Manual validation/override capability

**Expected Mappings:**
- All 24 careers mapped to 18 career groups
- All 148 occupations classified by industry/sector
- 142 certifications linked to occupation requirements

---

## Implementation Plan

### Step 1: Data Acquisition & Staging (Days 1-2)

**Tasks:**
1. Download BLS SOC data and wage files
2. Download O*NET crosswalk file
3. Create staging tables:
   - stg.BLS_SOCCodes (SOC code, description, parent SOC)
   - stg.BLS_WageData (SOC code, median wage, 25th/75th percentile)
   - stg.BLS_OutlookData (SOC code, growth rate, employment change)
   - stg.ONET_Crosswalk (SOC code, O*NET code, match type)

**Files to Create:**
- 20_create_staging_bls_tables.sql
- 20_create_staging_onet_tables.sql
- 20_load_staging_bls_data.sql (manual load or SSIS)
- 20_load_staging_onet_data.sql (manual load or SSIS)

**Validation:**
- Row counts match source files
- SOC codes are valid format
- Wage data within expected ranges (> $0)
- O*NET crosswalk completeness

### Step 2: Populate Dimension Tables (Days 3-4)

**Tasks:**
1. Update dim_occupation with BLS data:
   - Populate soc_code from stg.BLS_SOCCodes
   - Populate onet_code from stg.ONET_Crosswalk
   - Populate median_annual_wage from stg.BLS_WageData
   - Populate job_growth_percentage from stg.BLS_OutlookData
   - Flag is_high_demand based on growth thresholds
   - Flag is_stem based on SOC code patterns

2. Update dim_career with career-group mappings:
   - Create mapping table: ctl.CareerCareerGroupMapping
   - Populate dim_career.career_group_key via lookup
   - Validate referential integrity

3. Update dim_certification with industry data:
   - Link certifications to relevant occupations
   - Populate certification_description with O*NET data
   - Link to issuing organizations

**Files to Create:**
- 21_update_dim_occupation_with_bls_data.sql
- 21_update_dim_career_with_group_mappings.sql
- 21_create_career_group_mapping_control.sql
- 21_create_occupation_bls_mapping_view.sql

**Validation Tests:**
- All dim_occupation.soc_code populated (148 rows)
- All dim_occupation.onet_code populated (148 rows)
- All dim_occupation.median_annual_wage > 0
- All dim_career.career_group_key populated (24 rows)
- FK integrity maintained (0 orphans)

### Step 3: Implement Career-Group Mapping (Days 5)

**Tasks:**
1. Analyze career-to-occupation relationships in staging
2. Create mapping rules:
   - Rule 1: Career name substring match to occupation SOC group
   - Rule 2: Skill overlap analysis (badge skills → occupation skills)
   - Rule 3: Manual mapping table (business logic)
3. Populate ctl.CareerCareerGroupMapping
4. Apply mappings to dim_career
5. Document mapping methodology

**Files to Create:**
- 22_analyze_career_occupation_alignment.sql
- 22_create_career_group_mapping_logic.sql
- 22_populate_career_group_mappings.sql

**Validation Tests:**
- All careers have a career group mapping
- No career maps to multiple groups (1:1 requirement)
- Career group FK references are valid
- Mapping logic is documented and auditable

### Step 4: Enhance Alignment Scoring (Days 6-7)

**Tasks:**
1. Develop nuanced alignment algorithm:
   - Factor 1: Badge skill count (0-1 scale)
   - Factor 2: Skill-occupation match percentage (0-1 scale)
   - Factor 3: Certification requirements (0-1 scale)
   - Combined score = (Factor1 * 0.5) + (Factor2 * 0.3) + (Factor3 * 0.2)

2. Create alignment scoring procedure:
   - sp_Calculate_Badge_Career_Alignment_Score
   - sp_Calculate_Badge_Occupation_Alignment_Score
   - sp_Calculate_Badge_Certification_Alignment_Score

3. Update bridge tables with new scores:
   - Recalculate dim_badge_career_bridge.alignment_strength
   - Recalculate dim_badge_occupation_bridge.alignment_strength
   - Recalculate dim_badge_certification_bridge.alignment_strength

4. Validate score distributions and ranges

**Files to Create:**
- 23_create_alignment_scoring_procedures.sql
- 23_calculate_badge_career_alignment_scores.sql
- 23_calculate_badge_occupation_alignment_scores.sql
- 23_calculate_badge_certification_alignment_scores.sql
- 23_validate_alignment_scores.sql

**Validation Tests:**
- All alignment scores in valid range (0.00-1.00)
- Score distribution analysis (mean, std dev, min, max)
- Comparison with Phase 3 binary scores (increase in granularity)
- Top 10/bottom 10 alignments validation (business sense check)

### Step 5: Create Analytical Views (Days 8)

**Tasks:**
1. Create reporting views:
   - v_Career_Occupation_Alignment (career → occupation mapping with scores)
   - v_Badge_Labor_Market_Alignment (badge → all labor market dimensions)
   - v_Occupation_Career_Crosswalk (SOC → career crosswalk)
   - v_Certification_Occupation_Requirements (cert requirements by occupation)

2. Create aggregate tables:
   - agg_Occupation_Employment_Stats (employment by occupation, wage, growth)
   - agg_Career_Alignment_Summary (badge count, avg alignment by career)

**Files to Create:**
- 24_create_labor_market_alignment_views.sql
- 24_create_occupation_employment_aggregate.sql
- 24_create_career_alignment_summary_aggregate.sql

**Validation Tests:**
- Views return data without errors
- Aggregates calculate correctly
- Join logic produces no unexpected nulls

### Step 6: Testing & Validation (Days 9-10)

**Tasks:**
1. Run comprehensive validation suite:
   - Data completeness (NULL checks)
   - Data accuracy (range checks, sample verification)
   - FK integrity (0 orphans)
   - Alignment score distribution

2. Query performance testing:
   - Badge-to-career alignment query
   - Occupation employment statistics query
   - Career group summary report
   - All queries should run < 100ms on sample data

3. Business validation:
   - Executive review of career-group mappings
   - Sample alignment scores (spot check validity)
   - Wage data sanity check (matches BLS publicly available data)

**Files to Create:**
- 25_phase_3.5_validation_test_suite.sql
- 25_phase_3.5_performance_benchmarks.sql
- 25_phase_3.5_business_validation_checklist.md

---

## Database Schema Changes

### New Columns in Existing Tables

**dim_occupation (updates):**
```sql
ALTER TABLE dim_occupation ADD
    soc_code VARCHAR(10) NULL,          -- NOW POPULATED
    onet_code VARCHAR(10) NULL,         -- NOW POPULATED
    median_annual_wage DECIMAL(12,2) NULL,  -- NOW POPULATED
    job_growth_percentage DECIMAL(5,2) NULL,-- NOW POPULATED
    is_high_demand BIT NULL,            -- NOW POPULATED (based on growth threshold > 8%)
    is_stem BIT NULL                    -- NOW POPULATED (based on SOC code patterns)
```

**dim_career (updates):**
```sql
ALTER TABLE dim_career ADD
    career_group_key INT NULL           -- NOW POPULATED via ctl.CareerCareerGroupMapping
    CONSTRAINT FK_career_career_group FOREIGN KEY REFERENCES dim_career_group(career_group_key)
```

**dim_badge_career_bridge (updates):**
```sql
ALTER TABLE dim_badge_career_bridge ADD
    alignment_strength NUMERIC(5,4) NULL  -- NOW REFINED (0.0000-1.0000 continuous scale)
```

### New Staging Tables

```sql
CREATE TABLE stg.BLS_SOCCodes (...)
CREATE TABLE stg.BLS_WageData (...)
CREATE TABLE stg.BLS_OutlookData (...)
CREATE TABLE stg.ONET_Crosswalk (...)
```

### New Control Tables

```sql
CREATE TABLE ctl.CareerCareerGroupMapping (...)  -- Career-to-group mappings with audit trail
```

### New Views

```sql
CREATE VIEW v_Career_Occupation_Alignment (...)
CREATE VIEW v_Badge_Labor_Market_Alignment (...)
CREATE VIEW v_Occupation_Career_Crosswalk (...)
CREATE VIEW v_Certification_Occupation_Requirements (...)
```

---

## Success Criteria

✅ **Data Completeness**
- All 148 occupations have SOC codes
- All 148 occupations have O*NET codes
- All 148 occupations have median wage
- All 148 occupations have job growth %
- All 24 careers have career_group_key assigned

✅ **Data Quality**
- 0 orphaned FK references
- Wage data > $0 and < $500K
- Growth percentage between -50% and +50%
- All alignment scores in 0.00-1.00 range

✅ **Performance**
- All queries < 100ms
- Alignment calculation < 1 second for all badges
- View queries return data quickly (< 50ms)

✅ **Business Validation**
- Career-group mappings reviewed by business
- Sample alignments spot-checked for validity
- Wage data aligns with known BLS data

✅ **Documentation**
- All mapping logic documented
- All assumptions recorded
- Data lineage tracked
- Phase 3.5 completion report generated

---

## Known Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| BLS data not available for all SOC codes | Medium | Use O*NET codes as fallback; document gaps |
| Career-group mapping ambiguity | High | Create business review process; get stakeholder sign-off |
| Alignment scoring algorithm validity | High | Test with known career paths; refine based on feedback |
| Performance degradation with new joins | Low | Add appropriate indexes; benchmark before/after |
| Data currency (wage data ages quickly) | Low | Document data currency; plan annual refresh |

---

## Timeline

| Task | Duration | Days | Completion Date |
|------|----------|------|-----------------|
| Data Acquisition | 2 days | 1-2 | TBD + 2 |
| Populate Dimensions | 2 days | 3-4 | TBD + 4 |
| Career Group Mapping | 1 day | 5 | TBD + 5 |
| Alignment Scoring | 2 days | 6-7 | TBD + 7 |
| Analytical Views | 1 day | 8 | TBD + 8 |
| Testing & Validation | 2 days | 9-10 | TBD + 10 |
| **Total** | **10 days** | | |

---

## Deliverables

### SQL Scripts (10+ files)
- Staging table creation/load
- Dimension update procedures
- Mapping control logic
- Alignment scoring calculations
- Analytical views
- Validation test suite

### Documentation
- Phase 3.5 Completion Report
- Career-group mapping methodology
- Alignment scoring algorithm documentation
- Data quality validation results
- Performance benchmarks

### Data Files
- BLS data integration log
- Career-group mapping table (exported for audit)
- Alignment score distribution report

---

## Next Steps

1. **Acquire external data sources** (BLS, O*NET)
2. **Schedule business review session** for career-group mappings
3. **Set up ETL pipeline** for ongoing data refreshes (annual)
4. **Prepare Phase 3.5 implementation schedule**
5. **Begin Phase 3.5 work** after Phase 4 completion

---

**Phase 3.5 Status:** Ready for implementation
**Estimated Start:** After Phase 4 completion
**Estimated Duration:** 1-2 weeks
