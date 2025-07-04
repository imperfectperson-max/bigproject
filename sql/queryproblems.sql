/*
Problem:
*"List all government facilities with BSL-4 labs that have conducted Phase III trials in the
last 5 years, including their total funding received and average trial severity grade. Exclude
institutions under export control restrictions."*

Skills Tested:
• Multi-table joins (Institutions → Trials → Funding)
• Date filtering
• Exclusion logic

*/

-- Select rows from a Table or View '[TableOrViewName]' in schema '[dbo]'
SELECT 
    I.LegalName, 
    SUM(F.Disbursements) AS TotalFundingReceived,
    AVG(AE.SeverityGrade) AS AverageSeverityGrade
FROM 
    Institution I
JOIN 
    Funding F ON I.InstitutionID = F.InstitutionID
JOIN 
    Regulatory R ON I.InstitutionID = R.InstitutionID
JOIN 
    Location L ON I.LocationID = L.LocationID
LEFT JOIN
    Project P ON I.InstitutionID = P.InstitutionID
LEFT JOIN
    Project CT ON P.ProtocolID = CT.ProtocolID
LEFT JOIN 
    Participant PP ON CT.InstitutionID = F.InstitutionID
LEFT JOIN
    AdverseEventReport AE ON PP.ParticipantID = AE.ParticipantID
WHERE 
    I.Type = 'Government'
    AND L.BSLLabLevel = 4  -- BSL-4 labs only
    AND R.FDAPhase = 3     -- Phase III trials
    AND (R.ExportRestriction IS NULL OR R.ExportRestriction NOT IN ('ITAR', 'EAR'))
    AND R.IRBApprovalDate >= DATEADD(year, -5, GETDATE())  -- Last 5 years
GROUP BY 
    I.InstitutionID, I.LegalName
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
*/

WITH ConcurrentResearchers AS (
    -- Researchers with appointments at multiple institutions
    SELECT 
        R.ResearcherID,
        R.NIHHISID,
        R.ORCID,
        COUNT(DISTINCT R.InstitutionID) AS InstitutionCount
    FROM 
        Researcher R
    JOIN 
        EmploymentHistory E ON R.ResearcherID = E.ResearcherID
    WHERE 
        E.EndDate IS NULL -- Current positions only
    GROUP BY 
        R.ResearcherID, R.NIHHISID, R.ORCID
    HAVING 
        COUNT(DISTINCT R.InstitutionID) > 1
),

ActiveProjectPIs AS (
    -- Researchers who are PIs on active projects
    SELECT 
        P.PrincipalInvestigatorID AS ResearcherID,
        COUNT(*) AS ActiveProjectCount
    FROM 
        Project P
    WHERE 
        P.EndDate > GETDATE() -- Active projects
    GROUP BY 
        P.PrincipalInvestigatorID
    HAVING 
        COUNT(*) > 3
)

SELECT 
    R.ResearcherID,
    R.NIHHISID,
    R.ORCID,
    R.SecurityClearance AS QualificationLevel,
    CR.InstitutionCount,
    AP.ActiveProjectCount,
    -- Calculate total FTE (sum of all current positions)
    SUM(E.FTEPercentage) AS TotalFTE,
    -- Qualification level based on highest degree
    (
        SELECT TOP 1 D.Field 
        FROM Degree D 
        WHERE D.ResearcherID = R.ResearcherID 
        ORDER BY 
            CASE 
                WHEN D.Field LIKE '%PhD%' THEN 1
                WHEN D.Field LIKE '%MD%' THEN 2
                ELSE 3
            END
    ) AS HighestQualification,
    -- List of institutions
    STRING_AGG(I.LegalName, '; ') AS Institutions
FROM 
    Researcher R
JOIN 
    ConcurrentResearchers CR ON R.ResearcherID = CR.ResearcherID
JOIN 
    ActiveProjectPIs AP ON R.ResearcherID = AP.ResearcherID
JOIN 
    EmploymentHistory E ON R.ResearcherID = E.ResearcherID
JOIN 
    Institution I ON E.InstitutionID = I.InstitutionID
WHERE 
    E.EndDate IS NULL -- Current positions only
GROUP BY 
    R.ResearcherID, R.NIHHISID, R.ORCID, R.SecurityClearance,
    CR.InstitutionCount, AP.ActiveProjectCount
ORDER BY 
    ActiveProjectCount DESC, TotalFTE DESC;

/**
3. Compliance Monitoring 
Problem: 
*"Generate a report of all clinical trials missing IRB renewal dates within the next 30 days, 
flagged by institution type and PI contact info. Include trials with past-due renewals in 
red."* 
Skills Tested: 
• Date arithmetic (CURRENT_DATE + INTERVAL '30 days') 
• Conditional formatting (use CASE WHEN) 
• Hierarchical joins (Institution → Department → Researcher → Trial)
*/

SELECT 
    I.LegalName AS Institution,
    I.Type AS InstitutionType,
    R.FirstName + ' ' + R.LastName AS PrincipalInvestigator,
    R.Email AS PI_Contact,
    P.ProtocolID,
    P.ProjectTitle,
    R.IRBRenewalDate,
    CASE 
        WHEN R.IRBRenewalDate < GETDATE() THEN 'PAST DUE'
        WHEN R.IRBRenewalDate <= DATEADD(day, 30, GETDATE()) THEN 'DUE WITHIN 30 DAYS'
        ELSE 'UP TO DATE'
    END AS RenewalStatus,
    CASE 
        WHEN R.IRBRenewalDate < GETDATE() THEN '🔴 RED'
        WHEN R.IRBRenewalDate <= DATEADD(day, 30, GETDATE()) THEN '🟡 YELLOW'
        ELSE '🟢 GREEN'
    END AS StatusColor
FROM 
    Project P
JOIN 
    Researcher R ON P.PrincipalInvestigatorID = R.ResearcherID
JOIN 
    Institution I ON R.InstitutionID = I.InstitutionID
WHERE 
    R.IRBRenewalDate IS NULL 
    OR R.IRBRenewalDate <= DATEADD(day, 30, GETDATE())
ORDER BY 
    CASE 
        WHEN R.IRBRenewalDate < GETDATE() THEN 0
        WHEN R.IRBRenewalDate <= DATEADD(day, 30, GETDATE()) THEN 1
        ELSE 2
    END,
    R.IRBRenewalDate;

/**
4. Biospecimen Chain-of-Custody 
Problem: 
*"Find all biospecimen aliquots stored in freezers at locations with temperature violations 
(≥ -70°C) in the last week, tracing back to the originating trial and PI."* 
Skills Tested: 
• Time-series filtering 
• Multi-hop joins (Freezer → Biospecimen → Trial → Researcher) 
• Threshold validation
*/
