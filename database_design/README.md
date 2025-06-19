# Database Design Documents
--Entity-Relationship Diagram (EERD) Overview
Scope: This diagram models the core data structure for the National Biomedical Research Network (NBRN), covering research institutions, projects, personnel, compliance, and biospecimen tracking.

Key Entities
Institution

Attributes: ID, Name, Type (Academic/Corporate/Government), AccreditationStatus, BSLLevel

Relationships:

HAS → Location (Address, GPS)

MANAGES → ResearchProject

ResearchProject

Attributes: ProtocolID, Phase (I-II-III), FundingSource, IRBApprovalDate

Relationships:

HAS → ClinicalTrial

ASSOCIATED_WITH → Pathogen

Personnel

Attributes: ResearcherID, Qualifications, Languages, SecurityClearance

Relationships:

WORKS_AT → Institution

AUTHORS → Publication

Biospecimen

Attributes: SpecimenID, StorageLocation, ChainOfCustodyLog

Relationships:

LINKED_TO → ClinicalTrial

STORED_IN → Freezer (Temperature logs)

Regulatory

Attributes: ComplianceID, ScreeningLogs, ExportControlFlags

Relationships:

GOVERNS → ResearchProject

Notable Features
Hierarchical Inheritance:

Institution subtypes (Academic, Corporate, Government) with specialized attributes.

Temporal Tracking:

EmploymentHistory (start/end dates) for researchers.

Compliance Constraints:

Validations for BSLLevel vs. PathogenRisk.
