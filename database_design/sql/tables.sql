/*
NBRN Database Schema
Purpose: Tracks biomedical research institutions, personnel, projects, and compliance data
Designed for Azure SQL/SQL Server
*/

-- Core location data for all institutions
CREATE TABLE Location (
    LocationID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Address VARCHAR(255) NOT NULL,
    SquareFeet DECIMAL(10, 2) NOT NULL CHECK (SquareFeet > 0),
    BSLLabLevel INT NOT NULL CHECK (BSLLabLevel BETWEEN 1 AND 4), -- Biosafety Level 1-4
    CONSTRAINT UQ_LocationID UNIQUE (LocationID)
);
GO

-- Parent institution table with common attributes
CREATE TABLE Institution (
    InstitutionID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    LegalName VARCHAR(255) NOT NULL,
    DateFounded DATE NOT NULL CHECK (DateFounded <= GETDATE()),
    TaxStatus VARCHAR(20) NOT NULL CHECK (TaxStatus IN ('Nonprofit', 'For-Profit', 'Government')),
    LocationID INT NOT NULL,
    Type VARCHAR(20) NOT NULL CHECK (Type IN ('Academic', 'Corporate', 'Government')),
    CONSTRAINT FK_Institution_Location FOREIGN KEY (LocationID) REFERENCES Location(LocationID),
    CONSTRAINT UQ_InstitutionID UNIQUE (InstitutionID)
);
GO

-- Corporate lab subtype (extends Institution)
CREATE TABLE CorporateLab (
    InstitutionID INT NOT NULL PRIMARY KEY,
    ParentCompany VARCHAR(100) NOT NULL,
    StockTicker VARCHAR(10) NULL, -- Nullable for private companies
    RnDBudget DECIMAL(15, 2) NOT NULL CHECK (RnDBudget >= 0),
    CONSTRAINT FK_CorporateLab_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) ON DELETE CASCADE
);
GO

-- Academic institution subtype (extends Institution)
CREATE TABLE AcademicInstitution (
    InstitutionID INT NOT NULL PRIMARY KEY,
    QSWorldRanking INT NULL, -- Nullable for unranked institutions
    NumPhdPrograms INT NOT NULL CHECK (NumPhdPrograms >= 0),
    IRBApprovalCapacity INT NOT NULL CHECK (IRBApprovalCapacity >= 0),
    CONSTRAINT FK_Academic_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) ON DELETE CASCADE
);
GO

-- Government facility subtype (extends Institution)
CREATE TABLE GovernmentFacility (
    InstitutionID INT NOT NULL PRIMARY KEY,
    SecurityClearLevel VARCHAR(20) NOT NULL CHECK (SecurityClearLevel IN ('Confidential', 'Secret', 'Top Secret')),
    AgencyAffiliation VARCHAR(50) NOT NULL, -- Expanded from CHAR(8)
    CONSTRAINT FK_Government_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) ON DELETE CASCADE
);
GO

-- Researcher information (fixed typo in table name)
CREATE TABLE Researcher (
    ResearcherID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    NIHHISID CHAR(10) NOT NULL,
    ORCID CHAR(19) NOT NULL CHECK (
        ORCID LIKE '0000-000[1-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]' OR
        ORCID LIKE '0000-000[1-9]-[0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]X'
    ),
    VisaStatus VARCHAR(30) NOT NULL,
    SecurityClearance VARCHAR(30) NOT NULL,
    COIDisclosure VARCHAR(MAX) NOT NULL,
    InstitutionID INT NOT NULL,
    CONSTRAINT FK_Researcher_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID)
);
GO


-- Researcher employment history
CREATE TABLE EmploymentHistory (
    ExperienceRecordID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    StartDate DATE NOT NULL,
    EndDate DATE NULL, -- Nullable for current positions
    FTEPercentage DECIMAL(3, 2) NOT NULL CHECK (FTEPercentage BETWEEN 0 AND 1), -- 0-1.00 range
    Department VARCHAR(50) NOT NULL,
    ResearcherID INT NOT NULL,
    CONSTRAINT FK_Employment_Researcher FOREIGN KEY (ResearcherID) REFERENCES Researcher(ResearcherID),
    CONSTRAINT CHK_ValidEmploymentDates CHECK (EndDate IS NULL OR EndDate > StartDate)
);
GO

-- Researcher degrees (added missing ResearcherID column)
CREATE TABLE Degree (
    DegreeID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Institution VARCHAR(100) NOT NULL, -- Fixed typo in column name
    Year INT NOT NULL CHECK (Year > 1900 AND Year <= YEAR(GETDATE())), -- Changed from DATE to INT
    Field VARCHAR(60) NOT NULL,
    ResearcherID INT NOT NULL,
    CONSTRAINT FK_Degree_Researcher FOREIGN KEY (ResearcherID) REFERENCES Researcher(ResearcherID)
);
GO

-- Researcher certifications
CREATE TABLE Certification (
    CertificationID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    Year INT NOT NULL CHECK (Year > 1900 AND Year <= YEAR(GETDATE())),
    ResearcherID INT NOT NULL,
    CONSTRAINT FK_Certification_Researcher FOREIGN KEY (ResearcherID) REFERENCES Researcher(ResearcherID)
);
GO

-- Researcher language proficiencies
CREATE TABLE Language (
    LanguageID INT NOT NULL IDENTITY(1,1) PRIMARY KEY, 
    Name VARCHAR(40) NOT NULL,
    ProficiencyLevel INT NOT NULL CHECK (ProficiencyLevel BETWEEN 1 AND 5), -- 1-5 scale
    ResearcherID INT NOT NULL,
    CONSTRAINT FK_Language_Researcher FOREIGN KEY (ResearcherID) REFERENCES Researcher(ResearcherID)
);
GO

-- Research publications
CREATE TABLE Publication (
    PublicationID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    EmbargoPeriod DATETIME2 NOT NULL,
    AltmetricScore INT NOT NULL CHECK (AltmetricScore >= 0),
    PrePrintServerLink VARCHAR(255) NOT NULL,
    InstitutionID INT NOT NULL,
    CONSTRAINT FK_Publication_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID),
    CONSTRAINT CHK_EmbargoFuture CHECK (EmbargoPeriod > GETDATE())
);
GO

-- Biological specimen tracking
CREATE TABLE Biospecimen (
    RepositoryID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    AliquotCounts INT NOT NULL CHECK (AliquotCounts > 0), -- Fixed typo in column name
    FreezerLocation VARCHAR(255) NOT NULL,
    ChainOfCustodyLogs VARCHAR(MAX) NOT NULL, -- Changed to text for detailed logs
    InstitutionID INT NOT NULL,
    CONSTRAINT FK_Biospecimen_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) -- Changed to reference Institution
);
GO

-- Data sharing agreements
CREATE TABLE DataSharing (
    DataShareID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    DUA VARCHAR(100) NOT NULL,
    DeIdentificationMethod VARCHAR(30) NOT NULL CHECK (DeIdentificationMethod IN ('k-anonymity', 'differential privacy')),
    InstitutionID INT NOT NULL,
    CONSTRAINT FK_DataSharing_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) -- Changed to reference Institution
);
GO

-- Clinical trial participants
CREATE TABLE Participant (
    ParticipantID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    InstitutionID INT NOT NULL,
    CONSTRAINT FK_Participant_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) -- Changed to reference Institution
);
GO

-- Participant screening logs
CREATE TABLE ScreeningLog (
    LogID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    ParticipantID INT NOT NULL,
    CONSTRAINT FK_Screening_Participant FOREIGN KEY (ParticipantID) REFERENCES Participant(ParticipantID)
);
GO

-- Participant withdrawal reasons
CREATE TABLE WithdrawalReason (
    ReasonID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Description VARCHAR(255) NOT NULL, -- Expanded for detailed reasons
    ParticipantID INT NOT NULL,
    CONSTRAINT FK_Withdrawal_Participant FOREIGN KEY (ParticipantID) REFERENCES Participant(ParticipantID)
);
GO

-- Adverse event reports
CREATE TABLE AdverseEventReport (
    ReportID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    Description VARCHAR(MAX) NOT NULL, -- Large text for details
    SeverityGrade INT NOT NULL CHECK (SeverityGrade BETWEEN 1 AND 5), -- Added CTCAE severity scale
    ParticipantID INT NOT NULL,
    CONSTRAINT FK_AdverseEvent_Participant FOREIGN KEY (ParticipantID) REFERENCES Participant(ParticipantID)
);
GO

-- Patent information (fixed table/column names)
CREATE TABLE Patent (
    PatentID INT NOT NULL IDENTITY(1,1) PRIMARY KEY, -- Fixed typo in column name
    FilingDate DATE NOT NULL, 
    LicensingRevenue DECIMAL(15, 2) NOT NULL CHECK (LicensingRevenue >= 0), -- Fixed typo
    InstitutionID INT NOT NULL,
    CONSTRAINT FK_Patent_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) -- Changed to reference Institution
);
GO

-- Research projects
CREATE TABLE Project (
    ProtocolID INT NOT NULL IDENTITY(1,1) PRIMARY KEY, 
    PreRegistrationDOI VARCHAR(50) NOT NULL,
    DSMBOversightFlag BIT NOT NULL, -- Changed to boolean
    InstitutionID INT NOT NULL,
    CONSTRAINT FK_Project_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) -- Changed to reference Institution
);
GO

-- Funding information
CREATE TABLE Funding (
    FundingID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    GrantNumbers VARCHAR(50) NOT NULL, -- Expanded size
    Disbursements DECIMAL(15, 2) NOT NULL CHECK (Disbursements >= 0),
    InstitutionID INT NOT NULL,
    CONSTRAINT FK_Funding_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) -- Changed to reference Institution
);
GO

-- Regulatory compliance tracking
CREATE TABLE Regulatory (
    RegulatorID INT NOT NULL IDENTITY(1,1) PRIMARY KEY,
    IRBApprovalDate DATE NOT NULL,
    FDAPhase INT NULL CHECK (FDAPhase BETWEEN 1 AND 4), -- Nullable for non-FDA projects
    ExportRestriction VARCHAR(20) NULL, -- Expanded and made nullable
    InstitutionID INT NOT NULL,
    CONSTRAINT FK_Regulatory_Institution FOREIGN KEY (InstitutionID) REFERENCES Institution(InstitutionID) -- Changed to reference Institution
);
GO
--Add columns that are missing in Project and EmploymentHistory
BEGIN TRANSACTION;

-- Add PrincipalInvestigatorID column with foreign key constraint
-- Add date columns
BEGIN TRANSACTION;
ALTER TABLE Project
ADD StartDate DATE NULL,
    EndDate DATE NULL.
    ProjectTitle VARCHAR(100) NULL,
    PrincipalInvestigatorID INT NUL;
GO
    
BEGIN TRANSACTION;
ALTER TABLE Researcher
ADD IRBRenewalDate DATE NULL,
    FirstName VARCHAR(80) NULL, 
    LastName VARCHAR(80) NULL,
    Email VARCHAR(255) NULL;
GO;

BEGIN TRANSACTION;
-- Add InstitutionID column
ALTER TABLE EmploymentHistory
ADD InstitutionID INT NULL;
GO
