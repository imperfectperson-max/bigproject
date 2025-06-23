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

