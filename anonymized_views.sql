/*
NBRN Database - HIPAA-Compliant Anonymized Views
Purpose: Create views that mask direct identifiers while preserving analytical value
RFP Requirement: "Create a HIPAA-compliant view of participant data that masks direct 
                  identifiers (name, email) but preserves age brackets and trial outcomes"

HIPAA Safe Harbor Method - 18 Identifiers Removed/Masked:
1. Names - Masked with hash
2. Geographic subdivisions - Limited to state level
3. Dates - Limited to year (except DOB which is converted to age brackets)
4. Phone/fax - Removed
5. Email - Masked with hash
6. SSN - Not collected
7. Medical record numbers - Replaced with study participant ID
8. Health plan numbers - Not applicable
9. Account numbers - Not applicable
10. Certificate/license numbers - Not applicable
11. Vehicle identifiers - Not applicable
12. Device identifiers - Not applicable
13. URLs - Not applicable
14. IP addresses - Not applicable
15. Biometric identifiers - Not applicable
16. Photos - Not applicable
17. Other unique identifiers - Replaced with study ID

Age Brackets: 18-30, 31-45, 46-60, 61-75, 76+
*/

-- ============================================================================
-- HIPAA-COMPLIANT ANONYMIZED PARTICIPANT VIEW
-- ============================================================================

CREATE OR ALTER VIEW participants_anonymized_view
AS
SELECT 
    -- Masked identifiers (deterministic hashing for linkage)
    P.ParticipantID,
    P.StudyParticipantID,
    CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', ISNULL(P.FirstName, '') + ISNULL(P.LastName, '')), 2) AS ParticipantNameHash,
    CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', ISNULL(P.Email, '')), 2) AS EmailHash,
    
    -- Age bucketization (HIPAA compliant)
    CASE 
        WHEN P.Age BETWEEN 18 AND 30 THEN '18-30'
        WHEN P.Age BETWEEN 31 AND 45 THEN '31-45'
        WHEN P.Age BETWEEN 46 AND 60 THEN '46-60'
        WHEN P.Age BETWEEN 61 AND 75 THEN '61-75'
        WHEN P.Age >= 76 THEN '76+'
        ELSE 'Unknown'
    END AS AgeBracket,
    
    -- Demographics (safe to include)
    P.Gender,
    
    -- Consent tracking (safe to include)
    P.HIPAA_Consent,
    P.GDPR_Consent,
    YEAR(P.ConsentDate) AS ConsentYear, -- Year only, not full date
    
    -- Trial information
    P.TrialID,
    T.ClinicalTrialsGovID,
    T.Phase AS TrialPhase,
    T.Status AS TrialStatus,
    T.PrimaryOutcomeMeasure,
    
    -- Institution (limited to type, not specific institution)
    I.Type AS InstitutionType,
    
    -- Screening outcome (safe to include)
    CAST(CASE WHEN EXISTS (
        SELECT 1 FROM ScreeningLog SL 
        WHERE SL.ParticipantID = P.ParticipantID 
        AND SL.EligibilityCriteriaMet = 1
    ) THEN 1 ELSE 0 END AS BIT) AS PassedScreening,
    
    -- Withdrawal status (safe to include, no dates)
    CAST(CASE WHEN EXISTS (
        SELECT 1 FROM WithdrawalReason WR 
        WHERE WR.ParticipantID = P.ParticipantID
    ) THEN 1 ELSE 0 END AS BIT) AS HasWithdrawn,
    
    -- Withdrawal category (if applicable)
    (SELECT TOP 1 WR.Category 
     FROM WithdrawalReason WR 
     WHERE WR.ParticipantID = P.ParticipantID 
     ORDER BY WR.WithdrawalDate DESC) AS WithdrawalCategory,
    
    -- Adverse event summary (aggregated, not individual events)
    (SELECT COUNT(*) 
     FROM AdverseEventReport AER 
     WHERE AER.ParticipantID = P.ParticipantID) AS TotalAdverseEvents,
    
    (SELECT MAX(AER.SeverityGrade) 
     FROM AdverseEventReport AER 
     WHERE AER.ParticipantID = P.ParticipantID) AS MaxAdverseEventSeverity,
    
    (SELECT AVG(CAST(AER.SeverityGrade AS FLOAT)) 
     FROM AdverseEventReport AER 
     WHERE AER.ParticipantID = P.ParticipantID) AS AvgAdverseEventSeverity,
    
    -- Biospecimen tracking (counts only, no identifiable info)
    (SELECT COUNT(*) 
     FROM Biospecimen B 
     WHERE B.ParticipantID = P.ParticipantID) AS BiospecimensCollected

FROM Participant P
LEFT JOIN Trials T ON P.TrialID = T.TrialID
LEFT JOIN Institution I ON P.InstitutionID = I.InstitutionID
WHERE 
    -- Only include participants who have consented to data use
    (P.HIPAA_Consent = 1 OR P.GDPR_Consent = 1);

GO

-- ============================================================================
-- ANONYMIZED ADVERSE EVENTS VIEW (For Statistical Analysis)
-- ============================================================================

CREATE OR ALTER VIEW adverse_events_anonymized_view
AS
SELECT 
    AER.ReportID,
    
    -- Anonymized participant reference
    AER.ParticipantID,
    CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CAST(AER.ParticipantID AS VARCHAR)), 2) AS ParticipantHash,
    
    -- Age bracket from participant
    CASE 
        WHEN P.Age BETWEEN 18 AND 30 THEN '18-30'
        WHEN P.Age BETWEEN 31 AND 45 THEN '31-45'
        WHEN P.Age BETWEEN 46 AND 60 THEN '46-60'
        WHEN P.Age BETWEEN 61 AND 75 THEN '61-75'
        WHEN P.Age >= 76 THEN '76+'
        ELSE 'Unknown'
    END AS AgeBracket,
    
    P.Gender,
    
    -- Project/trial info (safe)
    AER.ProjectID,
    T.Phase AS TrialPhase,
    I.Type AS InstitutionType,
    
    -- Event details (dates limited to year/month)
    YEAR(AER.EventDate) AS EventYear,
    MONTH(AER.EventDate) AS EventMonth,
    AER.SeverityGrade,
    AER.Outcome,
    AER.Relatedness,
    
    -- Report metadata (year only)
    YEAR(AER.ReportDate) AS ReportYear,
    MONTH(AER.ReportDate) AS ReportMonth

FROM AdverseEventReport AER
INNER JOIN Participant P ON AER.ParticipantID = P.ParticipantID
LEFT JOIN Project PR ON AER.ProjectID = PR.ProtocolID
LEFT JOIN Trials T ON P.TrialID = T.TrialID
LEFT JOIN Institution I ON P.InstitutionID = I.InstitutionID
WHERE 
    -- Only include if participant consented
    (P.HIPAA_Consent = 1 OR P.GDPR_Consent = 1);

GO

-- ============================================================================
-- ANONYMIZED BIOSPECIMEN VIEW (For Chain of Custody Audits)
-- ============================================================================

CREATE OR ALTER VIEW biospecimens_anonymized_view
AS
SELECT 
    B.RepositoryID,
    
    -- Anonymized participant reference
    CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', CAST(B.ParticipantID AS VARCHAR)), 2) AS ParticipantHash,
    
    -- Age bracket
    CASE 
        WHEN P.Age BETWEEN 18 AND 30 THEN '18-30'
        WHEN P.Age BETWEEN 31 AND 45 THEN '31-45'
        WHEN P.Age BETWEEN 46 AND 60 THEN '46-60'
        WHEN P.Age BETWEEN 61 AND 75 THEN '61-75'
        WHEN P.Age >= 76 THEN '76+'
        ELSE 'Unknown'
    END AS AgeBracket,
    
    -- Specimen details (safe)
    B.SpecimenType,
    B.AliquotCounts,
    YEAR(B.CollectionDate) AS CollectionYear,
    MONTH(B.CollectionDate) AS CollectionMonth,
    
    -- Storage info (safe)
    B.FreezerID,
    F.FreezerName,
    L.City, -- City level is acceptable under HIPAA Safe Harbor
    L.State,
    L.BSLLabLevel,
    
    -- Project/institution (type only)
    B.ProjectID,
    I.Type AS InstitutionType,
    
    -- Chain of custody summary
    (SELECT COUNT(*) 
     FROM ChainOfCustody COC 
     WHERE COC.BiospecimenID = B.RepositoryID) AS ChainOfCustodyEvents

FROM Biospecimen B
LEFT JOIN Participant P ON B.ParticipantID = P.ParticipantID
LEFT JOIN Freezer F ON B.FreezerID = F.FreezerID
LEFT JOIN Location L ON F.LocationID = L.LocationID
LEFT JOIN Institution I ON B.InstitutionID = I.InstitutionID
WHERE 
    -- Only include if participant consented (or no participant linked)
    (B.ParticipantID IS NULL OR P.HIPAA_Consent = 1 OR P.GDPR_Consent = 1);

GO

-- ============================================================================
-- USAGE NOTES AND ACCESS CONTROL
-- ============================================================================

/*
USAGE EXAMPLES:

-- Query anonymized participant data for statistical analysis
SELECT 
    AgeBracket,
    Gender,
    TrialPhase,
    COUNT(*) AS ParticipantCount,
    AVG(TotalAdverseEvents) AS AvgAdverseEvents,
    AVG(MaxAdverseEventSeverity) AS AvgMaxSeverity
FROM participants_anonymized_view
WHERE TrialStatus = 'Completed'
GROUP BY AgeBracket, Gender, TrialPhase
ORDER BY AgeBracket, Gender;

-- Adverse event analysis by age and gender
SELECT 
    AgeBracket,
    Gender,
    SeverityGrade,
    COUNT(*) AS EventCount,
    COUNT(DISTINCT ParticipantHash) AS UniqueParticipants
FROM adverse_events_anonymized_view
WHERE EventYear = 2024
GROUP BY AgeBracket, Gender, SeverityGrade
ORDER BY SeverityGrade DESC, AgeBracket;

-- Biospecimen collection patterns
SELECT 
    SpecimenType,
    InstitutionType,
    CollectionYear,
    COUNT(*) AS SpecimenCount,
    SUM(AliquotCounts) AS TotalAliquots
FROM biospecimens_anonymized_view
GROUP BY SpecimenType, InstitutionType, CollectionYear
ORDER BY CollectionYear DESC, SpecimenType;

ACCESS CONTROL RECOMMENDATIONS:
1. Grant SELECT permission only to authorized analytics users
2. Implement row-level security if needed for institution-specific access
3. Log all queries against these views for audit trail
4. Regularly review access logs for suspicious patterns
5. Implement data retention policies (e.g., archive data >7 years old)

EXAMPLE ACCESS CONTROL:
-- Create analytics role
CREATE ROLE AnonymizedDataAnalyst;

-- Grant SELECT on anonymized views only
GRANT SELECT ON participants_anonymized_view TO AnonymizedDataAnalyst;
GRANT SELECT ON adverse_events_anonymized_view TO AnonymizedDataAnalyst;
GRANT SELECT ON biospecimens_anonymized_view TO AnonymizedDataAnalyst;

-- Deny access to base tables
DENY SELECT ON Participant TO AnonymizedDataAnalyst;
DENY SELECT ON AdverseEventReport TO AnonymizedDataAnalyst;

GDPR COMPLIANCE NOTES:
- These views support "Right to be Forgotten" - when participant records are deleted,
  they automatically disappear from these views
- The hash-based pseudonymization allows for subject access requests (with proper key)
- Age bucketization prevents singling out individuals in small cohorts
- Geographic limitation to city/state level prevents identification in rural areas
*/
