# External Data Sources Guide for Phase 3.5

**Document Purpose:** Explain BLS and O*NET data requirements, sources, and integration process
**Phase:** Phase 3.5 - Labor Market Data Integration
**Date:** December 8, 2025

---

## Overview

Phase 3.5 requires two external labor market data sources to enhance career and occupation analysis:

1. **BLS (Bureau of Labor Statistics)** - US government agency providing wage and job outlook data
2. **O*NET (Occupational Information Network)** - Comprehensive occupational database with detailed job descriptions and skills

---

## 1. BLS (Bureau of Labor Statistics) Data

### What is BLS?
The Bureau of Labor Statistics is part of the US Department of Labor. It publishes:
- Employment statistics
- Wage and salary data
- Job growth projections
- Industry analysis

### What Data We Need

From BLS, we need for **each occupation**:

| Field | Description | Example | Data Type |
|-------|-------------|---------|-----------|
| **SOC Code** | 6-digit Standard Occupational Classification | "51-3011" | NVARCHAR(8) |
| **Occupation Title** | Official BLS occupation name | "Bakers" | NVARCHAR(256) |
| **Median Annual Wage** | Annual wage in USD | 32850 | NUMERIC(10,2) |
| **Median Hourly Wage** | Hourly wage in USD | 15.79 | NUMERIC(8,2) |
| **Employment Count** | Total current employment | 187500 | INT |
| **Job Growth %** | 10-year projected growth percentage | 5.2 | NUMERIC(5,2) |
| **New Job Openings** | Estimated new jobs (10-year) | 9400 | INT |
| **Replacement Openings** | Estimated replacement jobs (10-year) | 8600 | INT |

### BLS Data Sources

#### Option 1: BLS Public Data API (Recommended for automation)
**URL:** https://www.bls.gov/developers/home.htm

**What you get:**
- Real-time access to BLS data
- Can query specific series IDs for occupational data
- Free (registration required for higher query limits)
- Updated regularly

**Series IDs for Occupational Data:**
- **Occupational Employment and Wages (OES):** OEUS (Occupational Employment and Wage Statistics)
  - Examples:
    - OEUS003000000 = All workers in all occupations
    - OEUS110000000 = Management occupations
    - OEUS513011000 = Bakers

**Key OES Series:**
- Employment levels
- Mean wages
- Median wages
- Percentile wages (10th, 25th, 75th, 90th)

**API Example Request:**
```bash
curl -X POST https://api.bls.gov/publicAPI/v2/timeseries/data \
  -H "Content-Type: application/json" \
  -d '{
    "seriesid": ["OEUS513011000"],
    "startyear": "2023",
    "endyear": "2024",
    "registrationkey": "YOUR_API_KEY"
  }'
```

**Registration:** https://www.bls.gov/developers/api_signature_v2.htm

---

#### Option 2: BLS Data Download (CSV/Excel)
**URL:** https://www.bls.gov/oes/

**What you get:**
- Pre-compiled occupation data in downloadable files
- Excel or CSV format
- Free download (no API calls)
- Less current (typically 6-12 months behind real-time)

**Files to Download:**
1. **Occupational Employment and Wages by State** (May annual data)
   - File: `oesm23or.xlsx` or `oesm24or.xlsx`
   - Contains: All occupations, employment, wages by state

2. **National Occupational Employment and Wage Estimates**
   - File: `oes_nat.xlsx`
   - Contains: All occupations, national employment, wages

**Format Example (from downloaded file):**
```
SOC Code | Occupation Title        | Employment | Mean Wage | Median Wage | 10th %ile | 25th %ile | 75th %ile | 90th %ile
51-3011  | Bakers                  | 187,520    | $36,500   | $32,850     | $22,140   | $26,380   | $39,650   | $48,920
51-3021  | Butchers and Meat Cutters| 129,780   | $34,120   | $30,280     | $21,310   | $25,020   | $37,450   | $45,880
```

**Download Instructions:**
1. Go to https://www.bls.gov/oes/current_oesm01.htm
2. Select "National occupational employment and wage estimates" → Download Excel file
3. Import into SQL Server staging table (sql/20_create_stg_bls_occupation_data.sql)

---

#### Option 3: Idaho-Specific Labor Market Data
**URL:** https://www.idahoworks.com/ (Idaho Department of Labor)

**What you get:**
- Idaho-specific employment and wage data
- Aligned with state education goals
- Regional breakdowns
- Free access

**Data Available:**
- Occupational employment in Idaho
- Wage data for Idaho occupations
- Industry trends in Idaho
- Regional labor market information

---

### BLS Data Integration into SQL

#### Step 1: Download BLS Data
Choose Option 2 (CSV/Excel download) - simplest approach:
1. Visit https://www.bls.gov/oes/
2. Download national occupational data Excel file (latest year)
3. Extract to CSV format

#### Step 2: Prepare Data (Transform)
Create a CSV with these columns:
```
soc_code,occupation_title,median_annual_wage,median_hourly_wage,employment_count,job_growth_percentage,new_jobs_openings,replacement_openings,is_stem,is_high_demand,source_year
"51-3011","Bakers",32850,15.79,187500,5.2,9400,8600,0,0,2024
"51-3021","Butchers and Meat Cutters",30280,14.56,129780,3.1,4000,4100,0,0,2024
...
```

#### Step 3: Load into SQL Staging Table
```sql
-- Bulk insert CSV into staging table
BULK INSERT SkillStack_Staging.stg.BLS_OccupationData
FROM 'C:\temp\bls_occupation_data.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,  -- Skip header
    TABLOCK
);
```

#### Step 4: Validate Data
```sql
-- Check row count
SELECT COUNT(*) FROM SkillStack_Staging.stg.BLS_OccupationData;
-- Expected: 700-900 occupations

-- Check data quality
SELECT COUNT(*) FROM SkillStack_Staging.stg.BLS_OccupationData
WHERE soc_code IS NULL OR occupation_title IS NULL;
-- Expected: 0

-- Check wage data
SELECT MIN(median_annual_wage), MAX(median_annual_wage), AVG(median_annual_wage)
FROM SkillStack_Staging.stg.BLS_OccupationData;
-- Expected: Min ~$20K, Max ~$200K, Avg ~$60K
```

---

## 2. O*NET (Occupational Information Network) Data

### What is O*NET?
O*NET is the US Department of Labor's comprehensive occupational database maintained by the National Center for O*NET Development. It provides:
- Detailed job descriptions
- Skills required for each occupation
- Work activities and tasks
- Work context and environment
- Education and training requirements
- Career pathways

**Website:** https://www.onetcenter.org/

### What Data We Need

From O*NET, we need for **each occupation**:

| Field | Description | Example | Data Type |
|-------|-------------|---------|-----------|
| **O*NET-SOC Code** | O*NET occupational code (8 digits + .00) | "51-3011.00" | NVARCHAR(10) |
| **SOC Code** | 6-digit SOC mapping | "51-3011" | NVARCHAR(8) |
| **Occupation Title** | O*NET job title | "Bakers" | NVARCHAR(256) |
| **DWA Occupation Title** | Detailed Work Activity title | "Operating industrial baking ovens" | NVARCHAR(256) |
| **Is Rapid Growth** | Flag if rapidly growing occupation | 0 or 1 | BIT |
| **Is Emerging** | Flag if emerging/innovative | 0 or 1 | BIT |
| **Typical Entry Education** | Education level required | "High School Diploma" | NVARCHAR(100) |
| **Typical Experience** | Years of experience typical | 0 or 3 | INT |
| **Skills Complexity Level** | Overall complexity (1-5) | 3 | INT |
| **Technology Level** | Technology skills (1-5) | 2 | INT |
| **Mean Wage** | Mean annual wage from O*NET | 36500 | NUMERIC(10,2) |

### O*NET Data Sources

#### Option 1: O*NET Database Download (Recommended)
**URL:** https://www.onetcenter.org/database.html

**What you get:**
- Complete O*NET occupational database
- Multiple file formats (Excel, Access, SQL)
- Free download
- Updated annually

**Files to Download:**
1. **db_24_1_sqlite.zip** (or latest version)
   - SQLite format database
   - ~100MB compressed, ~500MB extracted
   - Contains: All occupational data

**Database Tables in O*NET:**
- `Occupation` - Basic occupation info
- `Occupation_Data` - Detailed attributes
- `Skills` - Skill requirements
- `Work_Activities` - Work activity descriptions
- `Education_Training_Experience` - Education requirements
- `Job_Zone` - Job zone levels (1-5)

**Key Tables for Our Needs:**
```sql
-- Occupation master table
SELECT *FROM Occupation
WHERE Code LIKE '51-3011%'

-- Skills by occupation
SELECT * FROM Skills
WHERE ONET_SOC_Code = '51-3011.00'

-- Education requirements
SELECT * FROM Education_Training_Experience
WHERE ONET_SOC_Code = '51-3011.00'
```

**Download Instructions:**
1. Go to https://www.onetcenter.org/database.html
2. Click "Download O*NET Database" (free registration required)
3. Choose latest version (currently v24.1 as of 2024)
4. Download ZIP file
5. Extract to local directory

---

#### Option 2: O*NET API (Real-time access)
**URL:** https://services.onetcenter.org/

**What you get:**
- Real-time occupational data
- Detailed occupational information
- Skills and abilities
- Work context
- API-based integration

**API Endpoints:**
```
GET https://services.onetcenter.org/v1/occupations/51-3011.00
GET https://services.onetcenter.org/v1/occupations/51-3011.00/skills
GET https://services.onetcenter.org/v1/occupations/51-3011.00/tasks
```

**API Authentication:**
- Free tier available (limited requests)
- Paid tier for higher volume
- See https://services.onetcenter.org/

---

#### Option 3: O*NET Web Interface
**URL:** https://www.onetonline.org/

**What you get:**
- Interactive job search and exploration
- Detailed job descriptions
- Skills, tasks, and abilities
- Education and training info
- Related occupations
- Not API-based (manual lookup only)

**Use Case:** Verify data or manually lookup specific occupations

---

### O*NET Data Integration into SQL

#### Step 1: Download O*NET Database
1. Register at https://www.onetcenter.org/database.html
2. Download `db_24_1_sqlite.zip` (or latest)
3. Extract files to `C:\temp\onet_data\`

#### Step 2: Extract Data from O*NET Database
O*NET databases are SQL-based (SQLite). You can query them directly:

**Using SQLite Command Line:**
```bash
# Export occupations to CSV
sqlite3 db_24_1.db "SELECT * FROM Occupation" > occupations.csv

# Export occupation data to CSV
sqlite3 db_24_1.db "SELECT * FROM Occupation_Data" > occupation_data.csv

# Export skills to CSV
sqlite3 db_24_1.db "SELECT * FROM Skills" > skills.csv
```

#### Step 3: Transform Data for SQL Server
Create a CSV matching our staging table schema:
```
onet_code,soc_code,occupation_title,dwa_occupation_title,is_rapid_growth,is_emerging,typical_entry_education,typical_experience_required,skills_complexity_level,mean_wage_national
"51-3011.00","51-3011","Bakers","Operating industrial baking ovens",0,0,"High School Diploma",0,3,36500
"51-3021.00","51-3021","Butchers and Meat Cutters","Cutting meat for sale",0,0,"High School Diploma",1,3,34120
...
```

#### Step 4: Load into SQL Staging Table
```sql
-- Bulk insert CSV into staging table
BULK INSERT SkillStack_Staging.stg.ONET_SOCCrosswalk
FROM 'C:\temp\onet_crosswalk_data.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FIRSTROW = 2,  -- Skip header
    TABLOCK
);
```

#### Step 5: Validate Data
```sql
-- Check row count
SELECT COUNT(*) FROM SkillStack_Staging.stg.ONET_SOCCrosswalk;
-- Expected: 800-900 occupations

-- Check SOC code distribution
SELECT soc_code, COUNT(*) as onet_codes
FROM SkillStack_Staging.stg.ONET_SOCCrosswalk
GROUP BY soc_code
ORDER BY COUNT(*) DESC;
-- Expected: Each SOC code has 1+ O*NET codes

-- Check education levels
SELECT DISTINCT typical_entry_education
FROM SkillStack_Staging.stg.ONET_SOCCrosswalk
ORDER BY typical_entry_education;
-- Expected: HS Diploma, AA, BA, MA, Doctorate, etc.
```

---

## 3. SOC Code Structure Explanation

### What is SOC?
**SOC = Standard Occupational Classification**

A hierarchical coding system used by US government to classify all occupations:

### SOC Code Format
```
XX-XXXX
│  └────── Detailed Occupation Code (001-999)
└───────── Occupation Group (01-99)
           └─ First 2 digits = Occupation Division (11-99)
```

**Example: 51-3011**
- **51** = Division = Production, Transportation, Material Moving
- **51-3** = Group = Production Occupations - Precision Metal Workers, Production Planners
- **51-30** = Minor Group = Assemblers and Fabricators
- **51-3011** = Detailed = Computer-Controlled Machine Tool Operators, Metal and Plastic

### Our 149 Occupations Span These SOC Divisions:

| SOC Division | Category | Examples |
|--------------|----------|----------|
| **11-19** | Management, Business, Financial | Manager, Accountant, HR Specialist |
| **21-29** | Professional and Related | Teacher, Nurse, Engineer |
| **31-39** | Service Occupations | Healthcare Support, Personal Care |
| **41-49** | Sales and Administrative Support | Sales, Office Support, Customer Service |
| **51-59** | Production and Transportation | Assembly, Manufacturing, Truck Driver |
| **61-65** | Natural Resources and Agriculture | Farmer, Forester, Fishery |

---

## 4. Data Mapping Example

### How BLS and O*NET Data Maps Together

**BLS Data (Wage & Growth):**
```
SOC Code: 51-3011
Occupation: Bakers
Median Wage: $32,850
Job Growth: 5.2%
Employment: 187,500
```

**O*NET Data (Occupational Detail):**
```
O*NET Code: 51-3011.00
SOC Code: 51-3011
Occupation: Bakers
Entry Education: High School Diploma
Skills:
  - Operating industrial equipment
  - Mathematics
  - Chemistry knowledge
  - Quality control
Typical Experience: 0 years
```

**Combined in dim_occupation:**
```
occupation_key: 101
occupation_id: 3011
occupation_name: Bakers
soc_code: 51-3011 ← From BLS
onet_code: 51-3011.00 ← From O*NET
median_annual_wage: 32850 ← From BLS
job_growth_percentage: 5.2 ← From BLS
typical_entry_education: High School Diploma ← From O*NET
is_stem: 0 ← From O*NET
is_high_demand: 0 ← Derived from BLS growth
```

---

## 5. Step-by-Step Integration Process

### Timeline: 2-3 Days

**Day 1: Data Sourcing & Preparation**
- [ ] Register for BLS data access (5 min)
- [ ] Download BLS occupational data (10 min)
- [ ] Download O*NET database (20 min)
- [ ] Extract and transform BLS data to CSV (30 min)
- [ ] Extract and transform O*NET data to CSV (30 min)
- [ ] Validate CSV files for quality (30 min)

**Day 2: Database Load & Procedures**
- [ ] Create staging tables (sql files 20-21): 30 sec
- [ ] Bulk insert BLS data into staging: 1 min
- [ ] Bulk insert O*NET data into staging: 1 min
- [ ] Validate staging data (row counts, nulls): 5 min
- [ ] Create control table (sql file 22): 30 sec
- [ ] Execute sp_Populate_dim_occupation_external_data: 2 min
- [ ] Execute sp_Populate_career_group_mapping: 3 min
- [ ] Execute sp_Recalculate_alignment_scores: 5 min
- [ ] Validate results (test queries): 10 min

**Day 3: Views & Validation**
- [ ] Create analytical views (sql file 26): 30 sec
- [ ] Test view performance: 5 min
- [ ] Generate sample reports: 15 min
- [ ] Sign-off on data quality: 30 min

---

## 6. Troubleshooting Common Issues

### Issue 1: SOC Code Mismatch
**Problem:** BLS has "51-3011" but O*NET has "51-3011.00"
**Solution:** Remove trailing ".00" from O*NET code for joining
```sql
SUBSTRING(onet_code, 1, 7) = bls_soc_code
-- "51-3011.00" becomes "51-3011"
```

### Issue 2: Occupation Title Variations
**Problem:** BLS says "Bakers" but O*NET says "Bakers, Bread and Pastry"
**Solution:** Use SOC code for joining (more reliable than names)
```sql
LEFT JOIN stg.ONET_SOCCrosswalk onet
    ON stg.BLS_OccupationData.soc_code = onet.soc_code
    -- NOT by occupation_title
```

### Issue 3: Missing Occupations in Our Database
**Problem:** BLS has 900 occupations but dim_occupation only has 149
**Solution:** This is normal. We only map occupations relevant to CTE programs.
```sql
-- Join to existing occupations first
INNER JOIN dim_occupation do
    ON bls.soc_code = do.soc_code
```

### Issue 4: Wage Data Seems Wrong
**Problem:** Median wage is $0 or extremely high
**Solution:** Check data type and format in source file
```sql
-- Verify wage data quality
SELECT soc_code, MIN(median_annual_wage), MAX(median_annual_wage)
FROM stg.BLS_OccupationData
GROUP BY soc_code
HAVING MIN(median_annual_wage) = 0
   OR MAX(median_annual_wage) > 500000;
```

---

## 7. Sample Data for Testing

If you want to test with sample data before sourcing real BLS/O*NET:

### Sample BLS Data (Insert Manually)
```sql
INSERT INTO SkillStack_Staging.stg.BLS_OccupationData
(soc_code, occupation_title, median_annual_wage, median_hourly_wage, employment_count,
 job_growth_percentage, new_jobs_openings, replacement_openings, is_stem, is_high_demand, source_year)
VALUES
('51-3011', 'Bakers', 32850, 15.79, 187500, 5.2, 9400, 8600, 0, 0, 2024),
('51-3021', 'Butchers and Meat Cutters', 30280, 14.56, 129780, 3.1, 4000, 4100, 0, 0, 2024),
('17-2011', 'Aerospace Engineers', 118300, 56.87, 77900, 3.3, 2500, 2800, 1, 1, 2024),
('29-1141', 'Registered Nurses', 77600, 37.31, 2962100, 6.1, 175000, 187000, 0, 1, 2024),
('15-1256', 'Software Developers', 124200, 59.71, 1464500, 15.2, 150000, 180000, 1, 1, 2024);
```

### Sample O*NET Data (Insert Manually)
```sql
INSERT INTO SkillStack_Staging.stg.ONET_SOCCrosswalk
(onet_code, soc_code, occupation_title, typical_entry_education, is_stem, is_rapid_growth)
VALUES
('51-3011.00', '51-3011', 'Bakers', 'High School Diploma', 0, 0),
('51-3021.00', '51-3021', 'Butchers and Meat Cutters', 'High School Diploma', 0, 0),
('17-2011.00', '17-2011', 'Aerospace Engineers', 'Bachelor''s Degree', 1, 1),
('29-1141.00', '29-1141', 'Registered Nurses', 'Bachelor''s Degree', 0, 1),
('15-1256.00', '15-1256', 'Software Developers', 'Bachelor''s Degree', 1, 1);
```

---

## 8. References & Links

**BLS Resources:**
- Main Website: https://www.bls.gov/
- OES Data: https://www.bls.gov/oes/
- API Documentation: https://www.bls.gov/developers/
- Idaho Labor Data: https://www.idahoworks.com/

**O*NET Resources:**
- Main Website: https://www.onetcenter.org/
- Database Download: https://www.onetcenter.org/database.html
- Online Explorer: https://www.onetonline.org/
- API Services: https://services.onetcenter.org/

**SOC Documentation:**
- SOC Manual: https://www.bls.gov/soc/2020/
- Classification System: https://www.bls.gov/soc/

**CTE Career Alignment:**
- CTSOs (Career and Technical Student Organizations): https://acteonline.org/
- PCSB (Postsecondary and Comprehensive Career Planning): https://www.postsecondarycareerplanning.org/

---

## 9. Recommended Implementation Path

### Quick Start (Test Environment)
1. Use sample data provided in Section 7
2. Test procedures and views with sample data
3. Validate SQL logic without external data sourcing

### Production (Real Data)
1. Download real BLS and O*NET data (Option 2: CSV download is easiest)
2. Transform to CSV format matching staging tables
3. Run Phase 3.5 SQL files 20-26
4. Execute procedures and validate results
5. Deploy to production with real data

### Automation (Future)
1. Set up BLS API integration for automated daily/weekly updates
2. Set up O*NET database refresh (annually)
3. Schedule stored procedures to run on a schedule
4. Implement error handling and alerting

---

**Document Prepared:** December 8, 2025
**For Phase:** 3.5 - Labor Market Data Integration
**Status:** Ready for data sourcing and integration

