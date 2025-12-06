# Phase 2 Enhancement Roadmap - Dimension Tables

This document tracks all recommended enhancements for dimension tables identified during Phase 1 null columns analysis.

## Overview
Phase 1 successfully created 5-level hierarchy with complete referential integrity. Phase 2 will enhance dimensions with additional attributes available in source data and derived calculations.

---

## 1. dim_cluster - Recommended Enhancements

### NULL COLUMNS IDENTIFIED:
- **cluster_code** (ALL NULL)
- **cluster_icon_url** (ALL NULL - BUT MAY BE AVAILABLE)
- **display_order** (ALL NULL)

### PHASE 2 ENHANCEMENTS:

#### 1.1 cluster_code Derivation
**Status:** NO SOURCE DATA
**Recommendation:** Generate abbreviations from cluster names
- Example derivations: "Agriculture, Food & Natural Resources" → "AGRI"
- **Approach:** Create lookup table or derivation logic in stored procedure
- **Priority:** MEDIUM

#### 1.2 cluster_icon_url Population
**Status:** CHECK IF ImageURL EXISTS IN STAGING
**Recommendation:** If available in source, populate from ImageURL
- **Priority:** HIGH - Visual assets needed for UI

#### 1.3 display_order Population
**Status:** NO SOURCE DATA
**Recommendation:** Use natural sort order or derive from cluster hierarchy
- **Priority:** MEDIUM - UI/UX improvement

---

## 2. dim_pathway - Recommended Enhancements

### COMPLETED IN PHASE 1:
- **pathway_icon_url** ✓ POPULATED (all 117 have ImageURL)
- **cluster_key** ✓ POPULATED (all mapped to clusters)

### NULL COLUMNS IDENTIFIED:
- **pathway_code** (ALL NULL)
- **pathway_description** (ALL NULL - 1 of 117 available)
- **display_order** (ALL NULL)
- **cip_code** (ALL NULL)

### PHASE 2 ENHANCEMENTS:

#### 2.1 pathway_code Derivation
**Status:** NO SOURCE DATA
**Recommendation:** Generate from pathway name
- Example: "Food Products & Processing Systems" → "FOOD"
- **Priority:** MEDIUM

#### 2.2 display_order Population
**Status:** NO SOURCE DATA
**Recommendation:** Sequential or custom sort configuration
- **Priority:** MEDIUM

#### 2.3 CIP Code Integration
**Status:** NO SOURCE DATA IN STAGING - EXTERNAL SOURCE REQUIRED
**Recommendation:** Integrate Classification of Instructional Programs data
- **Source:** U.S. Department of Education
- **Use Case:** Career alignment and labor statistics reporting
- **Priority:** HIGH - Essential for workforce readiness metrics

---

## 3. dim_specialty - Recommended Enhancements

### COMPLETED IN PHASE 1:
- **specialty_icon_url** ✓ POPULATED (all 112 have ImageURL)

### NULL COLUMNS IDENTIFIED:
- **specialty_code** (ALL NULL)
- **specialty_description** (110/112 NULL - 1% available)
- **display_order** (ALL NULL)
- **required_badge_count** (ALL NULL - CAN BE CALCULATED)
- **required_skill_count** (ALL NULL - CAN BE CALCULATED)

### PHASE 2 ENHANCEMENTS:

#### 3.1 specialty_code Derivation
**Status:** NO SOURCE DATA
**Recommendation:** Generate from specialty name
- Example: "Leadership Development" → "LEAD"
- **Priority:** MEDIUM

#### 3.2 required_badge_count Calculation
**Status:** CAN BE CALCULATED FROM FK RELATIONSHIPS
**Recommendation:** Calculate COUNT(DISTINCT badge_key) WHERE specialty_key = X
- **Priority:** HIGH - Data quality metric

#### 3.3 required_skill_count Calculation
**Status:** CAN BE CALCULATED FROM FK RELATIONSHIPS
**Recommendation:** Calculate from specialty's badges' skills
- **Priority:** HIGH - Data quality metric

#### 3.4 display_order Population
**Status:** NO SOURCE DATA
**Recommendation:** Sequential or custom configuration
- **Priority:** MEDIUM

---

## 4. dim_badge - Recommended Enhancements

### COMPLETED IN PHASE 1:
- **badge_icon_url** ✓ POPULATED (786/800 = 98.75%)
- **badge_validity_months** ✓ POPULATED (77/800 = 9.63%)
- **specialty_key** ✓ POPULATED (all 800 mapped)

### NULL COLUMNS IDENTIFIED:
- **display_order** (ALL NULL)

### PHASE 2 ENHANCEMENTS:

#### 4.1 display_order Population
**Status:** NO SOURCE DATA
**Recommendation:** Sequential or custom sort configuration
- **Priority:** MEDIUM

---

## 5. dim_skill - Recommended Enhancements

### NULL COLUMNS IDENTIFIED:
- **skill_guid** (ALL NULL - no source)
- **skill_type** (ALL NULL - no source)

### PHASE 2 ENHANCEMENTS:

#### 5.1 ParentBadgeId Relationship
**Status:** PARTIALLY MAPPED
**Recommendation:** Consider parent-child skill hierarchy
- Note: 5,688 skills have ParentBadgeId (100%), only 1,007 have BadgeId (17%)
- **Decision:** Evaluate if parent-child relationships needed
- **Priority:** MEDIUM

#### 5.2 skill_type Derivation
**Status:** NO SOURCE DATA
**Recommendation:** Derive from SkillSetId or skill characteristics
- Types: "Technical", "Soft Skills", "Leadership", etc.
- **Priority:** LOW - Limited source data

---

## 6. dim_user - Recommended Enhancements

### COMPLETED IN PHASE 1:
- **graduation_year** ✓ POPULATED (20,507/76,823 = 26.7%)

### NULL COLUMNS IDENTIFIED:
- **user_type** (ALL NULL)

### PHASE 2 ENHANCEMENTS:

#### 6.1 user_type Derivation
**Status:** NO DIRECT SOURCE - CAN BE DERIVED
**Recommendation:** Derive from IsHighSchool flag
- IsHighSchool = 1 → "High School"
- IsHighSchool = 0 → "Post-Secondary"
- **Priority:** MEDIUM - Demographic reporting

#### 6.2 Data Quality Remediation
**Status:** RECOMMENDED
**Recommendation:** Clean graduation year data anomalies
- Issues: 109 users with graduation_year = 0, plus values like 7, 12, 76, 87, 98
- **Priority:** MEDIUM - Data quality

---

## 7. dim_institution - Recommended Enhancements

### NULL COLUMNS IDENTIFIED:
- **institution_type** (ALL NULL)
- **address_line1, address_line2, city, state, zip_code** (ALL NULL)
- **phone, email** (ALL NULL)
- **region_name, region_number** (ALL NULL)
- **ipeds_id, ope_id** (ALL NULL)
- **accreditation_status** (ALL NULL)

### PHASE 2 ENHANCEMENTS:

#### 7.1 Address Information Integration
**Status:** NO SOURCE DATA IN STAGING
**Recommendation:** Integrate institution address data
- Fields: address_line1, address_line2, city, state, zip_code
- **Priority:** HIGH - Geographic reporting

#### 7.2 Region Mapping
**Status:** stg.INST_InstitutionRegions EXISTS (15 rows)
**Recommendation:** Create bridge logic for many-to-many mapping
- Challenge: Multiple regions per institution
- Solution: Create dim_institution_region_bridge table
- **Priority:** HIGH - Regional hierarchy

#### 7.3 Contact Information
**Status:** NO SOURCE DATA IN STAGING
**Recommendation:** Integrate phone and email data
- **Priority:** MEDIUM

#### 7.4 Institution Type Classification
**Status:** NO SOURCE DATA
**Recommendation:** Create classification (K-12, Community College, University, etc.)
- **Priority:** MEDIUM

#### 7.5 IPEDS & OPE ID Integration
**Status:** NO SOURCE DATA IN STAGING - EXTERNAL SOURCE
**Recommendation:** Integrate federal identifier data
- Source: U.S. Department of Education IPEDS database
- **Priority:** MEDIUM

---

## Summary - Phase 2 Priority Matrix

### TIER 1 (HIGH PRIORITY)
1. dim_pathway.cip_code - Career alignment essential
2. dim_specialty.required_badge_count - Data quality metric
3. dim_specialty.required_skill_count - Data quality metric
4. dim_institution.ADDRESS - Geographic reporting
5. dim_institution.REGION - Regional hierarchy
6. dim_user.user_type - Demographic segmentation

### TIER 2 (MEDIUM PRIORITY)
1. dim_cluster.cluster_code - Code generation
2. dim_cluster.display_order - UI ordering
3. dim_pathway.pathway_code - Code generation
4. dim_pathway.display_order - UI ordering
5. dim_specialty.specialty_code - Code generation
6. dim_badge.display_order - UI ordering
7. dim_user.DATA QUALITY - Graduation year remediation
8. dim_institution.CONTACT - Communication

### TIER 3 (LOW PRIORITY)
1. dim_pathway.pathway_description - Limited source data
2. dim_specialty.specialty_description - Limited source data
3. dim_skill.skill_type - Limited source data
4. dim_institution.IPEDS/OPE - Federal IDs
5. dim_institution.ACCREDITATION - Context only

---

## Implementation Notes for Phase 2

- **Code Generation:** For _code columns, decide on derivation: abbreviation, manual table, or skip
- **External Integrations:** CIP codes, IPEDS, OPE require external data source
- **Calculated Fields:** Badge/skill counts via SQL or materialized columns
- **Data Quality:** Address graduation year source validation
- **Bridge Tables:** Institution-Region bridge essential for many-to-many
- **Testing:** Each enhancement requires data quality validation
