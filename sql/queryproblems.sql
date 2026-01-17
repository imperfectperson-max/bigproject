/*
NBRN Database - Query Problems (Updated for New Schema)
Problem 1: Institutional Analytics

"List all government facilities with BSL-4 labs that have conducted Phase III trials in the
last 5 years, including their total funding received and average trial severity grade. Exclude
institutions under export control restrictions."

Skills Tested:
• Multi-table joins (Institutions → Trials → Funding)
• Date filtering
• Exclusion logic

FIXES APPLIED:
- Added Trials table join (was missing)
- Fixed Funding reference to use ProjectFunding junction table
- Corrected column name from Disbursements to TotalAmount
- Fixed Participant join logic (was joining on wrong column)
- Added GovernmentFacility table join for proper filtering
*/

SELECT 
    I.InstitutionID,
    I.LegalName AS InstitutionName,
    GF.AgencyAffiliation,
    L.Address AS LocationAddress,
    L.BSLLabLevel,
    COUNT(DISTINCT T.TrialID) AS TotalPhaseIIITrials,
    SUM(F.TotalAmount) AS TotalFundingReceived,
    AVG(CAST(AER.SeverityGrade AS FLOAT)) AS AverageAdverseEventSeverity,
    COUNT(DISTINCT P.ParticipantID) AS TotalParticipants
FROM 
    Institution I
INNER JOIN 
    GovernmentFacility GF ON I.InstitutionID = GF.InstitutionID
INNER JOIN 
    Location L ON I.LocationID = L.LocationID
INNER JOIN 
    Project PR ON I.InstitutionID = PR.InstitutionID
INNER JOIN 
    Trials T ON PR.ProtocolID = T.ProjectID
INNER JOIN 
    ProjectFunding PF ON PR.ProtocolID = PF.ProjectID
INNER JOIN 
    Funding F ON PF.FundingID = F.FundingID
LEFT JOIN 
    Participant P ON T.TrialID = P.TrialID
LEFT JOIN 
    AdverseEventReport AER ON P.ParticipantID = AER.ParticipantID
LEFT JOIN 
    Regulatory R ON PR.ProtocolID = R.ProjectID
WHERE 
    I.Type = 'Government'
    AND L.BSLLabLevel = 4  -- BSL-4 labs only
    AND T.Phase = 'III'     -- Phase III trials
    AND T.StartDate >= DATEADD(YEAR, -5, GETDATE())  -- Last 5 years
    AND (R.ExportRestriction IS NULL OR R.ExportRestriction IN ('None', 'EAR99'))
GROUP BY 
    I.InstitutionID, I.LegalName, GF.AgencyAffiliation, L.Address, L.BSLLabLevel
ORDER BY 
    TotalFundingReceived DESC;

/*
2. Researcher Workload
Problem:
"Identify researchers holding concurrent appointments at multiple institutions who are PIs
on more than 3 active projects. Include their qualification level and total FTE percentage
across all roles."

Skills Tested:
• Self-joins or subqueries for concurrent positions
• Aggregation with HAVING
• Percentage calculations

FIXES APPLIED:
- Fixed ConcurrentResearchers CTE to count EmploymentHistory.InstitutionID (not Researcher.InstitutionID)
- Added FirstName and LastName to output for better readability
- Fixed ActiveProjectPIs to check Status field and EndDate properly
- Improved degree qualification logic to use DegreeType field
*/

WITH ConcurrentResearchers AS (
    -- Researchers with current appointments at multiple institutions
    SELECT 
        R.ResearcherID,
        COUNT(DISTINCT EH.InstitutionID) AS InstitutionCount,
        SUM(EH.FTEPercentage) AS TotalFTE
    FROM 
        Researcher R
    INNER JOIN 
        EmploymentHistory EH ON R.ResearcherID = EH.ResearcherID
    WHERE 
        EH.EndDate IS NULL -- Current positions only
    GROUP BY 
        R.ResearcherID
    HAVING 
        COUNT(DISTINCT EH.InstitutionID) > 1
),

ActiveProjectPIs AS (
    -- Researchers who are PIs on active projects
    SELECT 
        P.PrincipalInvestigatorID AS ResearcherID,
        COUNT(*) AS ActiveProjectCount
    FROM 
        Project P
    WHERE 
        P.Status = 'Active'
        AND (P.EndDate IS NULL OR P.EndDate >= GETDATE())
    GROUP BY 
        P.PrincipalInvestigatorID
    HAVING 
        COUNT(*) > 3
)

SELECT 
    R.ResearcherID,
    R.FirstName + ' ' + R.LastName AS ResearcherName,
    R.NIHHISID,
    R.ORCID,
    R.SecurityClearance AS QualificationLevel,
    CR.InstitutionCount,
    CR.TotalFTE,
    AP.ActiveProjectCount,
    -- Highest degree using DegreeType field
    (
        SELECT TOP 1 D.DegreeType + ' in ' + D.Field 
        FROM Degree D 
        WHERE D.ResearcherID = R.ResearcherID 
        ORDER BY 
            CASE D.DegreeType
                WHEN 'PhD' THEN 1
                WHEN 'MD' THEN 2
                WHEN 'DVM' THEN 3
                WHEN 'PharmD' THEN 4
                WHEN 'MSc' THEN 5
                WHEN 'BSc' THEN 6
                ELSE 7
            END,
            D.Year DESC
    ) AS HighestQualification,
    -- List of current institutions
    STRING_AGG(I.LegalName, '; ') AS CurrentInstitutions
FROM 
    Researcher R
INNER JOIN 
    ConcurrentResearchers CR ON R.ResearcherID = CR.ResearcherID
INNER JOIN 
    ActiveProjectPIs AP ON R.ResearcherID = AP.ResearcherID
INNER JOIN 
    EmploymentHistory E ON R.ResearcherID = E.ResearcherID
INNER JOIN 
    Institution I ON E.InstitutionID = I.InstitutionID
WHERE 
    E.EndDate IS NULL -- Current positions only
GROUP BY 
    R.ResearcherID, R.FirstName, R.LastName, R.NIHHISID, R.ORCID, R.SecurityClearance,
    CR.InstitutionCount, CR.TotalFTE, AP.ActiveProjectCount
ORDER BY 
    AP.ActiveProjectCount DESC, CR.TotalFTE DESC;

/**
3. Compliance Monitoring 
Problem: 
"Generate a report of all clinical trials missing IRB renewal dates within the next 30 days, 
flagged by institution type and PI contact info. Include trials with past-due renewals in 
red."

Skills Tested: 
• Date arithmetic (CURRENT_DATE + INTERVAL '30 days') 
• Conditional formatting (use CASE WHEN) 
• Hierarchical joins (Institution → Department → Researcher → Trial)

FIXES APPLIED:
- Added Regulatory table join to also check IRBExpirationDate
- Improved date handling to use ISNULL for NULL dates
- Added days until renewal calculation
- Added priority level for sorting
*/

SELECT 
    PR.ProtocolID,
    PR.ProjectTitle,
    I.LegalName AS Institution,
    I.Type AS InstitutionType,
    R.FirstName + ' ' + R.LastName AS PrincipalInvestigator,
    R.Email AS PI_Contact,
    R.IRBRenewalDate,
    REG.IRBApprovalDate AS OriginalIRBApproval,
    REG.IRBExpirationDate AS IRBExpiration,
    DATEDIFF(DAY, GETDATE(), ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate)) AS DaysUntilRenewal,
    CASE 
        WHEN ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate) < GETDATE() THEN 'PAST DUE'
        WHEN ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate) <= DATEADD(DAY, 7, GETDATE()) THEN 'DUE WITHIN 7 DAYS'
        WHEN ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate) <= DATEADD(DAY, 30, GETDATE()) THEN 'DUE WITHIN 30 DAYS'
        ELSE 'UP TO DATE'
    END AS RenewalStatus,
    CASE 
        WHEN ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate) < GETDATE() THEN '🔴 RED'
        WHEN ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate) <= DATEADD(DAY, 7, GETDATE()) THEN '🔴 RED'
        WHEN ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate) <= DATEADD(DAY, 30, GETDATE()) THEN '🟡 YELLOW'
        ELSE '🟢 GREEN'
    END AS StatusColor,
    CASE 
        WHEN ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate) < GETDATE() THEN 1
        WHEN ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate) <= DATEADD(DAY, 7, GETDATE()) THEN 2
        WHEN ISNULL(R.IRBRenewalDate, REG.IRBExpirationDate) <= DATEADD(DAY, 30, GETDATE()) THEN 3
        ELSE 4
    END AS PriorityLevel
FROM 
    Project PR
INNER JOIN 
    Researcher R ON PR.PrincipalInvestigatorID = R.ResearcherID
INNER JOIN 
    Institution I ON PR.InstitutionID = I.InstitutionID
LEFT JOIN 
    Regulatory REG ON PR.ProtocolID = REG.ProjectID
WHERE 
    PR.Status IN ('Active', 'On-Hold')
    AND (
        R.IRBRenewalDate IS NULL 
        OR R.IRBRenewalDate <= DATEADD(DAY, 30, GETDATE())
        OR REG.IRBExpirationDate IS NULL
        OR REG.IRBExpirationDate <= DATEADD(DAY, 30, GETDATE())
    )
ORDER BY 
    PriorityLevel,
    COALESCE(R.IRBRenewalDate, REG.IRBExpirationDate, '9999-12-31'),  -- NULL dates sort last
    PR.ProtocolID;

/**
4. Biospecimen Chain-of-Custody 
Problem: 
"Find all biospecimen aliquots stored in freezers at locations with temperature violations 
(≥ -70°C) in the last week, tracing back to the originating trial and PI."

Skills Tested: 
• Time-series filtering 
• Multi-hop joins (Freezer → Biospecimen → Trial → Researcher) 
• Threshold validation

FIXES APPLIED:
- Use TemperatureViolations table instead of calculating from TemperatureLog
- Removed non-existent columns (AliquotID, AliquotCount -> AliquotCounts)
- Removed non-existent Phone column from Researcher
- Join Freezer and Location properly for location information
- Added chain of custody event count
- Use SpecimenType from Biospecimen table
*/

WITH RecentViolations AS (
    -- Get freezers with recent temperature violations from TemperatureViolations table
    SELECT 
        TV.FreezerID,
        TV.MaxViolationTemp,
        TV.FirstViolation,
        TV.LastViolation,
        F.FreezerName,
        L.Address AS FreezerLocation
    FROM 
        TemperatureViolations TV
    INNER JOIN 
        Freezer F ON TV.FreezerID = F.FreezerID
    INNER JOIN 
        Location L ON F.LocationID = L.LocationID
    WHERE 
        TV.LastViolation >= DATEADD(DAY, -7, GETDATE())  -- Last 7 days
        AND TV.MaxViolationTemp >= -70  -- Temperature threshold
)

SELECT 
    B.RepositoryID,
    B.SpecimenType,
    B.AliquotCounts,
    RV.FreezerName,
    RV.FreezerLocation,
    RV.MaxViolationTemp,
    RV.FirstViolation,
    RV.LastViolation,
    DATEDIFF(HOUR, RV.FirstViolation, RV.LastViolation) AS ViolationDurationHours,
    -- Trial information
    T.TrialID,
    T.ClinicalTrialsGovID,
    T.Phase AS TrialPhase,
    PR.ProjectTitle,
    -- PI information
    R.FirstName + ' ' + R.LastName AS PrincipalInvestigator,
    R.Email AS PI_Contact,
    -- Institution
    I.LegalName AS Institution,
    -- Chain of custody summary
    (SELECT COUNT(*) FROM ChainOfCustody COC WHERE COC.BiospecimenID = B.RepositoryID) AS ChainEvents,
    (SELECT TOP 1 COC.HandoffDate FROM ChainOfCustody COC 
     WHERE COC.BiospecimenID = B.RepositoryID 
     ORDER BY COC.HandoffDate DESC) AS LastHandoff,
    -- Severity assessment
    CASE 
        WHEN RV.MaxViolationTemp >= -60 THEN 'CRITICAL - Immediate Action Required'
        WHEN RV.MaxViolationTemp >= -70 THEN 'WARNING - Review Required'
        ELSE 'MINOR'
    END AS SeverityLevel
FROM 
    Biospecimen B
INNER JOIN 
    RecentViolations RV ON B.FreezerID = RV.FreezerID
INNER JOIN 
    Project PR ON B.ProjectID = PR.ProtocolID
INNER JOIN 
    Researcher R ON PR.PrincipalInvestigatorID = R.ResearcherID
INNER JOIN 
    Institution I ON B.InstitutionID = I.InstitutionID
LEFT JOIN 
    Trials T ON B.ProjectID = T.ProjectID
ORDER BY 
    RV.MaxViolationTemp DESC,
    RV.LastViolation DESC;
