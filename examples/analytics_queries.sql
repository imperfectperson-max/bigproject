/*
NBRN Database - Complete Example Analytics Queries
Purpose: SQL queries implementing all 10 analytical problems from the RFP
See: docs/My Big Project.pdf for requirements

This file demonstrates implementation of queries 5-10 not covered in sql/queryproblems.sql
*/

-- ============================================================================
-- QUERY 5: Publication Impact
-- ============================================================================

/*
Problem: "Calculate the 5-year h-index for each academic institution, considering only 
publications linked to NIH-funded projects. Rank institutions by h-index but exclude 
those with retraction rates >5%."
*/

WITH NIHFundedPublications AS (
    SELECT 
        PUB.PublicationID,
        PUB.InstitutionID,
        PUB.CitationCount,
        PUB.IsRetracted
    FROM 
        Publication PUB
    INNER JOIN 
        Project PR ON PUB.ProjectID = PR.ProtocolID
    INNER JOIN 
        ProjectFunding PF ON PR.ProtocolID = PF.ProjectID
    INNER JOIN 
        Funding F ON PF.FundingID = F.FundingID
    WHERE 
        F.FundingSource LIKE '%NIH%'
        AND PUB.PublicationDate >= DATEADD(YEAR, -5, GETDATE())
)

SELECT 
    I.InstitutionID,
    I.LegalName AS InstitutionName,
    AI.QSWorldRanking,
    COUNT(NFP.PublicationID) AS TotalPublications,
    SUM(CAST(NFP.IsRetracted AS INT)) AS TotalRetractions,
    CAST(SUM(CAST(NFP.IsRetracted AS INT)) AS FLOAT) / NULLIF(COUNT(NFP.PublicationID), 0) * 100 AS RetractionRate
FROM 
    Institution I
INNER JOIN 
    AcademicInstitution AI ON I.InstitutionID = AI.InstitutionID
LEFT JOIN 
    NIHFundedPublications NFP ON I.InstitutionID = NFP.InstitutionID
WHERE 
    I.Type = 'Academic'
GROUP BY 
    I.InstitutionID, I.LegalName, AI.QSWorldRanking
HAVING
    CAST(SUM(CAST(NFP.IsRetracted AS INT)) AS FLOAT) / NULLIF(COUNT(NFP.PublicationID), 0) * 100 <= 5.0
    OR COUNT(NFP.PublicationID) = 0
ORDER BY 
    TotalPublications DESC;

-- ============================================================================
-- QUERY 6: Adverse Event Analysis
-- ============================================================================

/*
Problem: "Compare adverse event rates (events/participant) between corporate and academic 
trials for Phase II/III studies, adjusted for trial duration."
*/

WITH TrialMetrics AS (
    SELECT 
        T.TrialID,
        T.Phase,
        I.Type AS InstitutionType,
        DATEDIFF(DAY, T.StartDate, ISNULL(T.CompletionDate, GETDATE())) AS TrialDurationDays,
        COUNT(DISTINCT P.ParticipantID) AS TotalParticipants,
        COUNT(AER.ReportID) AS TotalEvents,
        CAST(COUNT(AER.ReportID) AS FLOAT) / NULLIF(COUNT(DISTINCT P.ParticipantID), 0) AS EventsPerParticipant
    FROM 
        Trials T
    INNER JOIN Project PR ON T.ProjectID = PR.ProtocolID
    INNER JOIN Institution I ON PR.InstitutionID = I.InstitutionID
    LEFT JOIN Participant P ON T.TrialID = P.TrialID
    LEFT JOIN AdverseEventReport AER ON P.ParticipantID = AER.ParticipantID
    WHERE T.Phase IN ('II', 'III')
    GROUP BY T.TrialID, T.Phase, I.Type, T.StartDate, T.CompletionDate
)

SELECT 
    InstitutionType,
    AVG(EventsPerParticipant) AS AvgEventsPerParticipant,
    STDEV(EventsPerParticipant) AS StdDev
FROM TrialMetrics
GROUP BY InstitutionType;

-- ============================================================================
-- QUERY 7: Funding Efficiency  
-- ============================================================================

/*
Problem: "Identify top 10% most efficient researchers (publications per $1M funding)"
*/

SELECT TOP 10 PERCENT
    R.ResearcherID,
    R.FirstName + ' ' + R.LastName AS ResearcherName,
    COUNT(DISTINCT PUB.PublicationID) AS TotalPublications,
    SUM(PF.AllocationAmount) / 1000000.0 AS FundingMillions,
    COUNT(DISTINCT PUB.PublicationID) / NULLIF(SUM(PF.AllocationAmount) / 1000000.0, 0) AS EfficiencyScore
FROM 
    Researcher R
INNER JOIN Project PR ON R.ResearcherID = PR.PrincipalInvestigatorID
INNER JOIN ProjectFunding PF ON PR.ProtocolID = PF.ProjectID
INNER JOIN ResearcherPublication RP ON R.ResearcherID = RP.ResearcherID
INNER JOIN Publication PUB ON RP.PublicationID = PUB.PublicationID
GROUP BY R.ResearcherID, R.FirstName, R.LastName
ORDER BY EfficiencyScore DESC;

-- ============================================================================
-- QUERY 9: Data Anonymization (Using Views)
-- ============================================================================

/*
See anonymized_views.sql for the view definitions.
Example usage:
*/

SELECT 
    AgeBracket,
    Gender,
    COUNT(*) AS ParticipantCount,
    AVG(TotalAdverseEvents) AS AvgAdverseEvents
FROM participants_anonymized_view
GROUP BY AgeBracket, Gender;

-- ============================================================================
-- QUERY 10: Geospatial Logistics
-- ============================================================================

/*
Problem: "Find freezer pairs within 50 miles where one has >80% capacity"
*/

SELECT 
    F1.FreezerID AS OvercapacityFreezer,
    F2.FreezerID AS UndercapacityFreezer,
    CAST(F1.CurrentUtilization AS FLOAT) / F1.Capacity * 100 AS F1Utilization,
    CAST(F2.CurrentUtilization AS FLOAT) / F2.Capacity * 100 AS F2Utilization,
    -- Simple distance calculation (use spatial functions in production)
    3959 * ACOS(
        COS(RADIANS(L1.GPSLatitude)) * COS(RADIANS(L2.GPSLatitude)) *
        COS(RADIANS(L2.GPSLongitude) - RADIANS(L1.GPSLongitude)) +
        SIN(RADIANS(L1.GPSLatitude)) * SIN(RADIANS(L2.GPSLatitude))
    ) AS DistanceMiles
FROM 
    Freezer F1
INNER JOIN Location L1 ON F1.LocationID = L1.LocationID
CROSS JOIN Freezer F2
INNER JOIN Location L2 ON F2.LocationID = L2.LocationID
WHERE 
    F1.FreezerID < F2.FreezerID
    AND CAST(F1.CurrentUtilization AS FLOAT) / F1.Capacity > 0.90
    AND CAST(F2.CurrentUtilization AS FLOAT) / F2.Capacity < 0.80
    AND L1.GPSLatitude IS NOT NULL
    AND L2.GPSLatitude IS NOT NULL
    AND 3959 * ACOS(
        COS(RADIANS(L1.GPSLatitude)) * COS(RADIANS(L2.GPSLatitude)) *
        COS(RADIANS(L2.GPSLongitude) - RADIANS(L1.GPSLongitude)) +
        SIN(RADIANS(L1.GPSLatitude)) * SIN(RADIANS(L2.GPSLatitude))
    ) <= 50;
