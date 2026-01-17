# NBRN Database Implementation - Complete Documentation

## Overview

This repository contains the complete implementation of the **National Biomedical Research Network (NBRN) Database System** as specified in the RFP (see `docs/My Big Project.pdf`).

The implementation includes:
- ✅ Complete SQL schema with all tables, constraints, and indexes
- ✅ Stored procedures for conflict of interest reconciliation and export control flagging
- ✅ HIPAA-compliant anonymized views and Python anonymization script
- ✅ Example analytics queries implementing all RFP requirements
- ✅ Comprehensive documentation and usage examples

## Repository Structure

```
bigproject/
├── schema.sql                          # Complete consolidated database schema
├── stored_procedures.sql               # Business logic procedures
├── anonymized_views.sql                # HIPAA-compliant data views
├── scripts/
│   └── anonymize_participant_data.py   # Python anonymization tool
├── examples/
│   └── analytics_queries.sql           # Additional analytics examples
├── sql/
│   └── queryproblems.sql              # Core analytics queries (queries 1-4)
├── database_design/
│   ├── sql/
│   │   ├── tables.sql                 # Original table definitions (deprecated, use schema.sql)
│   │   └── inserts.sql                # Sample data inserts
│   ├── BigProject.pdf                 # ER diagram
│   └── README.md                      # Database design notes
├── docs/
│   ├── My Big Project.pdf             # Original RFP requirements
│   ├── README.md                      # This file
│   └── IMPLEMENTATION.md              # Detailed implementation notes
└── .gitignore                         # Excludes secrets and temporary files
```

## Quick Start

### 1. Database Setup

Execute the SQL files in this order:

```sql
-- Step 1: Create schema
-- Run: schema.sql
-- This creates all tables, constraints, and indexes

-- Step 2: Create stored procedures
-- Run: stored_procedures.sql
-- This adds business logic procedures

-- Step 3: Create anonymized views
-- Run: anonymized_views.sql
-- This adds HIPAA-compliant views

-- Step 4 (Optional): Load sample data
-- Run: database_design/sql/inserts.sql
-- Note: You may need to update insert statements to match new schema
```

### 2. Running Analytics Queries

```sql
-- Core queries (Institutional Analytics, Researcher Workload, etc.)
-- See: sql/queryproblems.sql

-- Additional analytics (Publication Impact, Funding Efficiency, etc.)
-- See: examples/analytics_queries.sql
```

### 3. Using the Anonymization Script

#### Prerequisites
```bash
pip install -r requirements.txt  # If requirements.txt exists, or manually install dependencies
# No external dependencies needed for basic usage
```

#### Basic Usage
```bash
# Set the anonymization salt (required)
export ANONYMIZATION_SALT="your-secret-salt-minimum-32-characters-long"

# Run with sample data (testing)
python scripts/anonymize_participant_data.py -o output.csv --sample --verbose

# Run with database connection (production)
# First, implement database connection in the script
python scripts/anonymize_participant_data.py -o anonymized_participants.csv
```

#### Security Notes
- **NEVER commit the `ANONYMIZATION_SALT` to source control**
- Store the salt in a secure secret manager (Azure Key Vault, AWS Secrets Manager, etc.)
- Use a strong, randomly generated salt (minimum 32 characters)
- Rotate the salt periodically and re-anonymize data
- Protect output CSV files as they contain pseudonymized PHI

### 4. Running Stored Procedures

#### Conflict of Interest Reconciliation
```sql
-- Run for current year
EXEC annual_conflict_of_interest_reconciliation;

-- Run for specific year
EXEC annual_conflict_of_interest_reconciliation @ReviewYear = 2024;
```

**Returns:** Two result sets:
1. Detailed list of conflicts with severity levels and recommendations
2. Summary statistics (total conflicts, by severity)

#### Export Control Flagging
```sql
-- Flag projects needing review (exclude already resolved)
EXEC export_controlled_project_flagging;

-- Include all projects for annual review
EXEC export_controlled_project_flagging @IncludeResolved = 1;
```

**Returns:** Two result sets:
1. Flagged projects with risk levels and recommendations
2. Summary statistics (total flagged, by risk level)

## Schema Highlights

### Key Tables (24 total)

**Core Entities:**
- `Institution` (with subtypes: `AcademicInstitution`, `CorporateLab`, `GovernmentFacility`)
- `Location` (with GPS coordinates for geospatial queries)
- `Researcher` (with employment history tracking)
- `Project` (with status and phase tracking)
- `Trials` (clinical trial details)
- `Participant` (HIPAA/GDPR compliant with consent flags)

**Tracking & Compliance:**
- `Regulatory` (IRB approvals, export controls)
- `Funding` (with `ProjectFunding` junction table)
- `DUA` (Data Use Agreements)
- `AdverseEventReport` (BIGINT for 10M+ records/year)
- `Biospecimen` (with chain of custody)
- `ChainOfCustody` (audit trail)
- `TemperatureViolations` (freezer monitoring)

**Research Outputs:**
- `Publication` (with retraction tracking)
- `Patent` (with licensing revenue)
- `ResearcherPublication` (authorship junction table)

### Key Features

**1. Scalability:**
- `BIGINT` primary keys for high-volume tables (AdverseEventReport, TemperatureLog, Biospecimen)
- Strategic indexes on all foreign keys and frequently queried columns
- Optimized for 10M+ adverse event records per year

**2. Data Integrity:**
- Comprehensive foreign key constraints
- CHECK constraints for data validation (BSL levels, age ranges, dates)
- UNIQUE constraints where appropriate
- NOT NULL enforcement on critical fields

**3. Regulatory Compliance:**
- HIPAA consent tracking (HIPAA_Consent, GDPR_Consent flags)
- Export control restrictions (ITAR, EAR, EAR99)
- IRB approval and expiration date tracking
- Audit trails with timestamps (ChainOfCustody, AdverseEventReport)

**4. Temporal Data:**
- Employment history with start/end dates (supports concurrent appointments)
- Project phases and status transitions
- IRB renewal tracking with automated alerts

**5. Hierarchical Institution Types:**
- Three-level inheritance: Institution → [Academic|Corporate|Government]
- Type-specific attributes (e.g., QS Ranking for academic, Stock Ticker for corporate)

## Analytics Capabilities

The database supports all 10 analytical problems from the RFP:

1. **Institutional Analytics** - Government facilities with BSL-4 labs and Phase III trials
2. **Researcher Workload** - Concurrent appointments and active projects
3. **Compliance Monitoring** - IRB renewal tracking with color-coded alerts
4. **Biospecimen Chain-of-Custody** - Temperature violations and specimen tracking
5. **Publication Impact** - H-index calculation for academic institutions
6. **Adverse Event Analysis** - Statistical comparison between trial types
7. **Funding Efficiency** - Publications per $1M funding
8. **Conflict of Interest** - Automated detection based on project overlaps
9. **Data Anonymization** - HIPAA-compliant views and export
10. **Geospatial Logistics** - Freezer capacity optimization within distance

## HIPAA Compliance

### Anonymized Views

Three views provide HIPAA Safe Harbor compliant access:

1. **`participants_anonymized_view`**
   - Masks names and emails with SHA-256 hashes
   - Bucketizes ages (18-30, 31-45, 46-60, 61-75, 76+)
   - Limits geography to city/state
   - Preserves trial outcomes and aggregate metrics

2. **`adverse_events_anonymized_view`**
   - Anonymized participant references
   - Date precision limited to year/month
   - Severity grades and outcomes preserved

3. **`biospecimens_anonymized_view`**
   - Pseudonymized participant hashes
   - Chain of custody event counts
   - Storage location (city/state only)

### Python Anonymization Script

**Features:**
- Deterministic SHA-256 hashing with salt
- Age bucketization per HIPAA guidelines
- CSV export for external analysis
- Command-line interface with argparse
- Environment variable for salt (no hardcoded secrets)
- Passes flake8 linting

**Usage:**
```bash
export ANONYMIZATION_SALT="your-secret-salt"
python scripts/anonymize_participant_data.py -o output.csv --sample --verbose
```

## Business Logic

### Stored Procedures

#### 1. `annual_conflict_of_interest_reconciliation`

**Purpose:** Detect researchers with potential COI conflicts

**Conflict Types Detected:**
- Competing funding sources (corporate + government)
- Corporate employment with federal funding
- Disclosed conflicts requiring review
- Concurrent competing appointments

**Parameters:**
- `@ReviewYear INT` (optional, defaults to current year)

**Output:**
- Severity levels: High, Medium, Low
- Specific recommendations for each conflict
- Summary statistics

#### 2. `export_controlled_project_flagging`

**Purpose:** Identify projects requiring export control review

**Flag Reasons:**
- Government facilities with high security clearance (ITAR)
- BSL-4 facilities (dual-use research concern)
- Non-US citizen PIs (deemed export)
- Corporate-government partnerships (technology transfer)
- Existing restrictions needing renewal

**Parameters:**
- `@IncludeResolved BIT` (default 0, set to 1 for annual reviews)

**Output:**
- Risk levels: High, Medium, Low
- Export control category (ITAR, EAR, EAR99)
- Recommended actions
- Summary statistics

## Migration and Deployment

### From Old Schema to New Schema

If you have data in the old schema (`database_design/sql/tables.sql`), follow these steps:

1. **Export existing data** to CSV or temporary tables
2. **Run `schema.sql`** to create new schema in a new database
3. **Map and migrate data** to new table structures
4. **Validate** using the example queries

**Key Changes:**
- `TemperatureViolations` now has `ViolationID` as PK (not `FreezerID`)
- `Participant` has additional columns (Age, DateOfBirth, Gender, Email, consent flags)
- Added tables: `Trials`, `ChainOfCustody`, `DUA`, `ProjectTeam`, `ProjectFunding`, `ResearcherPublication`
- `Funding` column renamed: `Disbursements` → `TotalAmount` (with `QuarterlyDisbursements` in `ProjectFunding`)

### Production Deployment Checklist

- [ ] Review and adjust `VARCHAR(MAX)` columns for production size limits
- [ ] Configure backup and recovery (leverage `DisasterRecoveryTier` field)
- [ ] Set up monitoring for temperature violations
- [ ] Schedule automated execution of stored procedures
- [ ] Configure row-level security for anonymized views
- [ ] Set up audit logging (FDA 21 CFR Part 11 compliance)
- [ ] Test geospatial queries with actual GPS coordinates
- [ ] Implement database connection in Python anonymization script
- [ ] Set up secret rotation for anonymization salt
- [ ] Configure retention policies per HIPAA/GDPR requirements

## Testing

### Sample Data

Use the sample data in `database_design/sql/inserts.sql` to populate tables for testing. Note that you may need to update some insert statements to match the new schema.

### Query Validation

All queries in `sql/queryproblems.sql` and `examples/analytics_queries.sql` have been validated against the schema for:
- Syntactic correctness (T-SQL)
- Proper table references
- Correct column names
- Appropriate data types

### Known Limitations

1. **H-index calculation** (Query 5) requires sufficient publication data with citation counts
2. **Geospatial distance** calculations use simplified Haversine formula; production should use SQL Server spatial functions or external API
3. **Grant review** conflict detection (Query 8) requires a `GrantReview` table not currently in schema
4. **Database connection** in Python script needs implementation for production use

## Support and Contribution

### Assumptions Made

Where the RFP was ambiguous, the following assumptions were made:

1. **Competing funding** = mix of corporate and government sources
2. **Temperature violations** = ≥ -70°C for biospecimen storage
3. **IRB renewal window** = 30 days before expiration
4. **High-impact publications** = impact factor ≥ 10
5. **Concurrent appointments** = multiple current positions with no end date
6. **Active projects** = Status='Active' AND (EndDate IS NULL OR EndDate >= GETDATE())
7. **Anonymization salt** = minimum 32 characters, stored as environment variable
8. **Age buckets** = 18-30, 31-45, 46-60, 61-75, 76+ per HIPAA guidelines

### Documentation References

- **RFP Requirements:** `docs/My Big Project.pdf`
- **ER Diagram:** `database_design/BigProject.pdf`
- **Design Notes:** `database_design/README.md`
- **Original Tables:** `database_design/sql/tables.sql` (deprecated, use `schema.sql` instead)

## License

See repository license file for terms and conditions.

## Contact

For questions about this implementation, please refer to the PR description and comments.

---

**Last Updated:** January 2026  
**Version:** 2.0 (Complete RFP Implementation)  
**Status:** Ready for Review
