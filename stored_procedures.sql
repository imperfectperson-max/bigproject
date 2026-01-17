/*
NBRN Database - Stored Procedures
Purpose: Implement business logic required by RFP
- Annual conflict-of-interest reconciliation
- Export-controlled project flagging

Version: 1.0
RFP Compliance: National Biomedical Research Network (NBRN) Database Request for Proposal
*/

-- ============================================================================
-- PROCEDURE 1: Annual Conflict of Interest Reconciliation
-- ============================================================================

/*
Purpose: Detect researchers with potential COI conflicts based on:
  1. Researchers who are PIs on multiple projects funded by competing sources
  2. Researchers with industry affiliations who also receive federal funding
  3. Researchers serving on review panels for grants they're competing for
  4. Researchers with disclosed COI who are PIs on related projects

Business Logic Assumptions:
  - Competing funding sources: Corporate (for-profit) vs. Government/NIH
  - Time window: Projects active within the same 12-month period
  - COI disclosure is required to be non-empty and reviewed annually
  - Results include severity level: High (direct conflict), Medium (potential), Low (disclosed but managed)

Returns: Table of researchers with potential conflicts and recommended actions
*/

CREATE OR ALTER PROCEDURE annual_conflict_of_interest_reconciliation
    @ReviewYear INT = NULL  -- Defaults to current year
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Default to current year if not specified
    IF @ReviewYear IS NULL
        SET @ReviewYear = YEAR(GETDATE());
    
    -- Calculate date range for the review year
    DECLARE @StartDate DATE = DATEFROMPARTS(@ReviewYear, 1, 1);
    DECLARE @EndDate DATE = DATEFROMPARTS(@ReviewYear, 12, 31);
    
    -- Create temp table for results
    CREATE TABLE #COI_Conflicts (
        ResearcherID INT,
        ResearcherName VARCHAR(200),
        ORCID CHAR(19),
        InstitutionName VARCHAR(255),
        ConflictType VARCHAR(100),
        SeverityLevel VARCHAR(10),
        ConflictDetails VARCHAR(MAX),
        RecommendedAction VARCHAR(MAX),
        ProjectsInvolved VARCHAR(MAX)
    );
    
    -- CONFLICT TYPE 1: PIs on projects with competing funding sources
    INSERT INTO #COI_Conflicts
    SELECT DISTINCT
        R.ResearcherID,
        R.FirstName + ' ' + R.LastName AS ResearcherName,
        R.ORCID,
        I.LegalName AS InstitutionName,
        'Competing Funding Sources' AS ConflictType,
        CASE 
            WHEN COUNT(DISTINCT F.FundingSource) >= 3 THEN 'High'
            WHEN COUNT(DISTINCT F.FundingSource) = 2 THEN 'Medium'
            ELSE 'Low'
        END AS SeverityLevel,
        'PI on ' + CAST(COUNT(DISTINCT P.ProtocolID) AS VARCHAR) + ' projects with ' + 
        CAST(COUNT(DISTINCT F.FundingSource) AS VARCHAR) + ' different funding sources including corporate and government.' AS ConflictDetails,
        'Review all project funding relationships. Ensure proper disclosure and management plan in place. ' +
        'Consider recusal from decision-making on competing projects.' AS RecommendedAction,
        STRING_AGG(P.ProjectTitle + ' (Protocol: ' + CAST(P.ProtocolID AS VARCHAR) + ')', '; ') AS ProjectsInvolved
    FROM Researcher R
    INNER JOIN Institution I ON R.InstitutionID = I.InstitutionID
    INNER JOIN Project P ON R.ResearcherID = P.PrincipalInvestigatorID
    INNER JOIN ProjectFunding PF ON P.ProtocolID = PF.ProjectID
    INNER JOIN Funding F ON PF.FundingID = F.FundingID
    WHERE 
        -- Projects active during review year
        (P.StartDate <= @EndDate AND (P.EndDate IS NULL OR P.EndDate >= @StartDate))
        -- Must have funding from at least 2 different sources
    GROUP BY 
        R.ResearcherID, R.FirstName, R.LastName, R.ORCID, I.LegalName
    HAVING 
        -- At least 2 different funding sources
        COUNT(DISTINCT F.FundingSource) >= 2
        -- At least one corporate and one government source (competing interests)
        AND (
            SUM(CASE WHEN F.FundingSource LIKE '%Industry%' OR F.FundingSource LIKE '%Corporate%' THEN 1 ELSE 0 END) > 0
            AND SUM(CASE WHEN F.FundingSource LIKE '%NIH%' OR F.FundingSource LIKE '%NSF%' OR F.FundingSource LIKE '%Government%' THEN 1 ELSE 0 END) > 0
        );
    
    -- CONFLICT TYPE 2: Researchers at corporate institutions with government project funding
    INSERT INTO #COI_Conflicts
    SELECT DISTINCT
        R.ResearcherID,
        R.FirstName + ' ' + R.LastName AS ResearcherName,
        R.ORCID,
        I.LegalName AS InstitutionName,
        'Corporate Affiliation with Federal Funding' AS ConflictType,
        'Medium' AS SeverityLevel,
        'Researcher employed at corporate institution (' + I.LegalName + ') serving as PI on federally-funded project.' AS ConflictDetails,
        'Review employment terms and funding agreements. Ensure IP rights and data sharing terms are properly documented. ' +
        'Verify compliance with federal funding regulations regarding industry partnerships.' AS RecommendedAction,
        STRING_AGG(P.ProjectTitle + ' (Grant: ' + F.GrantNumbers + ')', '; ') AS ProjectsInvolved
    FROM Researcher R
    INNER JOIN Institution I ON R.InstitutionID = I.InstitutionID
    INNER JOIN Project P ON R.ResearcherID = P.PrincipalInvestigatorID
    INNER JOIN ProjectFunding PF ON P.ProtocolID = PF.ProjectID
    INNER JOIN Funding F ON PF.FundingID = F.FundingID
    WHERE 
        I.Type = 'Corporate'
        AND (F.FundingSource LIKE '%NIH%' OR F.FundingSource LIKE '%NSF%' OR F.FundingSource LIKE '%Government%' OR F.FundingSource LIKE '%Federal%')
        AND (P.StartDate <= @EndDate AND (P.EndDate IS NULL OR P.EndDate >= @StartDate))
    GROUP BY 
        R.ResearcherID, R.FirstName, R.LastName, R.ORCID, I.LegalName;
    
    -- CONFLICT TYPE 3: Researchers with substantial COI disclosures on active projects
    INSERT INTO #COI_Conflicts
    SELECT DISTINCT
        R.ResearcherID,
        R.FirstName + ' ' + R.LastName AS ResearcherName,
        R.ORCID,
        I.LegalName AS InstitutionName,
        'Disclosed Conflicts Requiring Review' AS ConflictType,
        CASE 
            WHEN R.COIDisclosure LIKE '%stock%' OR R.COIDisclosure LIKE '%equity%' THEN 'High'
            WHEN R.COIDisclosure LIKE '%consulting%' OR R.COIDisclosure LIKE '%advisory%' THEN 'Medium'
            ELSE 'Low'
        END AS SeverityLevel,
        'Researcher has disclosed COI: ' + LEFT(R.COIDisclosure, 200) + 
        CASE WHEN LEN(R.COIDisclosure) > 200 THEN '...' ELSE '' END AS ConflictDetails,
        'Review COI disclosure statement. Verify management plan is in place and being followed. ' +
        'Ensure disclosure is current and complete. Schedule annual COI training if not completed.' AS RecommendedAction,
        STRING_AGG(P.ProjectTitle, '; ') AS ProjectsInvolved
    FROM Researcher R
    INNER JOIN Institution I ON R.InstitutionID = I.InstitutionID
    INNER JOIN Project P ON R.ResearcherID = P.PrincipalInvestigatorID
    WHERE 
        R.COIDisclosure NOT IN ('None', 'No conflicts', 'N/A', '')
        AND (P.StartDate <= @EndDate AND (P.EndDate IS NULL OR P.EndDate >= @StartDate))
    GROUP BY 
        R.ResearcherID, R.FirstName, R.LastName, R.ORCID, I.LegalName, R.COIDisclosure;
    
    -- CONFLICT TYPE 4: Researchers with concurrent appointments at competing institutions
    INSERT INTO #COI_Conflicts
    SELECT DISTINCT
        R.ResearcherID,
        R.FirstName + ' ' + R.LastName AS ResearcherName,
        R.ORCID,
        I.LegalName AS InstitutionName,
        'Concurrent Competing Appointments' AS ConflictType,
        'High' AS SeverityLevel,
        'Researcher holds concurrent appointments at ' + CAST(COUNT(DISTINCT EH.InstitutionID) AS VARCHAR) + 
        ' institutions, including corporate and academic/government institutions.' AS ConflictDetails,
        'Review all employment agreements for conflicts. Ensure time allocation is properly documented. ' +
        'Verify IP assignment and publication rights across all appointments. May require ethics board review.' AS RecommendedAction,
        STRING_AGG(I2.LegalName + ' (' + EH.Department + ', ' + CAST(CAST(EH.FTEPercentage * 100 AS INT) AS VARCHAR) + '% FTE)', '; ') AS ProjectsInvolved
    FROM Researcher R
    INNER JOIN Institution I ON R.InstitutionID = I.InstitutionID
    INNER JOIN EmploymentHistory EH ON R.ResearcherID = EH.ResearcherID
    INNER JOIN Institution I2 ON EH.InstitutionID = I2.InstitutionID
    WHERE 
        EH.EndDate IS NULL -- Current appointments only
        AND EXISTS (
            -- Has appointment at corporate institution
            SELECT 1 FROM EmploymentHistory EH2
            INNER JOIN Institution I3 ON EH2.InstitutionID = I3.InstitutionID
            WHERE EH2.ResearcherID = R.ResearcherID 
            AND EH2.EndDate IS NULL
            AND I3.Type = 'Corporate'
        )
        AND EXISTS (
            -- Also has appointment at academic or government institution
            SELECT 1 FROM EmploymentHistory EH3
            INNER JOIN Institution I4 ON EH3.InstitutionID = I4.InstitutionID
            WHERE EH3.ResearcherID = R.ResearcherID 
            AND EH3.EndDate IS NULL
            AND I4.Type IN ('Academic', 'Government')
        )
    GROUP BY 
        R.ResearcherID, R.FirstName, R.LastName, R.ORCID, I.LegalName
    HAVING COUNT(DISTINCT EH.InstitutionID) >= 2;
    
    -- Return final results ordered by severity
    SELECT 
        ResearcherID,
        ResearcherName,
        ORCID,
        InstitutionName,
        ConflictType,
        SeverityLevel,
        ConflictDetails,
        RecommendedAction,
        ProjectsInvolved
    FROM #COI_Conflicts
    ORDER BY 
        CASE SeverityLevel 
            WHEN 'High' THEN 1 
            WHEN 'Medium' THEN 2 
            WHEN 'Low' THEN 3 
        END,
        ResearcherName;
    
    -- Summary statistics
    SELECT 
        @ReviewYear AS ReviewYear,
        COUNT(*) AS TotalConflictsIdentified,
        SUM(CASE WHEN SeverityLevel = 'High' THEN 1 ELSE 0 END) AS HighSeverity,
        SUM(CASE WHEN SeverityLevel = 'Medium' THEN 1 ELSE 0 END) AS MediumSeverity,
        SUM(CASE WHEN SeverityLevel = 'Low' THEN 1 ELSE 0 END) AS LowSeverity,
        COUNT(DISTINCT ResearcherID) AS UniqueResearchersWithConflicts,
        GETDATE() AS ReportGeneratedDate
    FROM #COI_Conflicts;
    
    DROP TABLE #COI_Conflicts;
END;
GO

-- ============================================================================
-- PROCEDURE 2: Export-Controlled Project Flagging
-- ============================================================================

/*
Purpose: Identify and flag projects that may be subject to export control restrictions:
  - ITAR (International Traffic in Arms Regulations)
  - EAR (Export Administration Regulations)

Business Logic Assumptions:
  - Projects at government facilities with "Top Secret" clearance may be export controlled
  - Projects involving specific pathogens or BSL-4 facilities may have restrictions
  - Projects with non-US citizen researchers may trigger export control reviews
  - Projects with certain keywords (defense, weapons, dual-use) flag for review
  - Projects already marked with export restrictions in Regulatory table are included

Returns: Table of projects requiring export control review with risk levels
*/

CREATE OR ALTER PROCEDURE export_controlled_project_flagging
    @IncludeResolved BIT = 0  -- Set to 1 to include already-resolved projects
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create temp table for flagged projects
    CREATE TABLE #ExportControlFlags (
        ProjectID INT,
        ProjectTitle VARCHAR(200),
        InstitutionName VARCHAR(255),
        InstitutionType VARCHAR(20),
        PIName VARCHAR(200),
        RiskLevel VARCHAR(10),
        FlagReason VARCHAR(MAX),
        ExportControlCategory VARCHAR(50),
        RecommendedAction VARCHAR(MAX),
        CurrentStatus VARCHAR(100)
    );
    
    -- FLAG 1: Projects at government facilities with high security clearance
    INSERT INTO #ExportControlFlags
    SELECT DISTINCT
        P.ProtocolID AS ProjectID,
        P.ProjectTitle,
        I.LegalName AS InstitutionName,
        I.Type AS InstitutionType,
        R.FirstName + ' ' + R.LastName AS PIName,
        'High' AS RiskLevel,
        'Project conducted at government facility with ' + GF.SecurityClearLevel + ' security clearance. ' +
        'Affiliated with ' + GF.AgencyAffiliation + '.' AS FlagReason,
        'ITAR' AS ExportControlCategory,
        'Conduct formal export control review. Classify all project materials and data. ' +
        'Implement access controls for foreign nationals. Ensure all team members have appropriate clearances.' AS RecommendedAction,
        ISNULL(REG.ExportRestriction, 'Not Yet Classified') AS CurrentStatus
    FROM Project P
    INNER JOIN Institution I ON P.InstitutionID = I.InstitutionID
    INNER JOIN GovernmentFacility GF ON I.InstitutionID = GF.InstitutionID
    INNER JOIN Researcher R ON P.PrincipalInvestigatorID = R.ResearcherID
    LEFT JOIN Regulatory REG ON P.ProtocolID = REG.ProjectID
    WHERE 
        GF.SecurityClearLevel IN ('Secret', 'Top Secret')
        AND P.Status IN ('Active', 'On-Hold')
        AND (@IncludeResolved = 1 OR REG.ExportRestriction IS NULL OR REG.ExportRestriction = 'None');
    
    -- FLAG 2: Projects at BSL-4 facilities (potential dual-use research)
    INSERT INTO #ExportControlFlags
    SELECT DISTINCT
        P.ProtocolID AS ProjectID,
        P.ProjectTitle,
        I.LegalName AS InstitutionName,
        I.Type AS InstitutionType,
        R.FirstName + ' ' + R.LastName AS PIName,
        'High' AS RiskLevel,
        'Project involves BSL-4 laboratory facility. Potential for dual-use research of concern (DURC). ' +
        'Location: ' + L.Address AS FlagReason,
        'EAR/DURC' AS ExportControlCategory,
        'Mandatory DURC review required. Assess potential for misuse of research. ' +
        'Implement biosecurity measures. Restrict publication of sensitive methodologies. ' +
        'Register with NSABB if applicable.' AS RecommendedAction,
        ISNULL(REG.ExportRestriction, 'Not Yet Classified') AS CurrentStatus
    FROM Project P
    INNER JOIN Institution I ON P.InstitutionID = I.InstitutionID
    INNER JOIN Location L ON I.LocationID = L.LocationID
    INNER JOIN Researcher R ON P.PrincipalInvestigatorID = R.ResearcherID
    LEFT JOIN Regulatory REG ON P.ProtocolID = REG.ProjectID
    WHERE 
        L.BSLLabLevel = 4
        AND P.Status IN ('Active', 'On-Hold')
        AND (@IncludeResolved = 1 OR REG.ExportRestriction IS NULL OR REG.ExportRestriction = 'None');
    
    -- FLAG 3: Projects with non-US citizen PIs in sensitive fields
    INSERT INTO #ExportControlFlags
    SELECT DISTINCT
        P.ProtocolID AS ProjectID,
        P.ProjectTitle,
        I.LegalName AS InstitutionName,
        I.Type AS InstitutionType,
        R.FirstName + ' ' + R.LastName AS PIName,
        'Medium' AS RiskLevel,
        'Principal Investigator has visa status: ' + R.VisaStatus + '. ' +
        'May require deemed export review if PI has access to controlled technology or data.' AS FlagReason,
        'EAR' AS ExportControlCategory,
        'Review PI''s access to controlled information. Determine if deemed export license is required. ' +
        'Assess whether Technology Control Plan (TCP) is needed. Document all foreign national access.' AS RecommendedAction,
        ISNULL(REG.ExportRestriction, 'Not Yet Classified') AS CurrentStatus
    FROM Project P
    INNER JOIN Institution I ON P.InstitutionID = I.InstitutionID
    INNER JOIN Researcher R ON P.PrincipalInvestigatorID = R.ResearcherID
    LEFT JOIN Regulatory REG ON P.ProtocolID = REG.ProjectID
    WHERE 
        R.VisaStatus NOT IN ('US Citizen', 'Permanent Resident')
        AND P.Status IN ('Active', 'On-Hold')
        AND (@IncludeResolved = 1 OR REG.ExportRestriction IS NULL OR REG.ExportRestriction = 'None');
    
    -- FLAG 4: Projects with corporate-government partnerships (potential technology transfer issues)
    INSERT INTO #ExportControlFlags
    SELECT DISTINCT
        P.ProtocolID AS ProjectID,
        P.ProjectTitle,
        I.LegalName AS InstitutionName,
        I.Type AS InstitutionType,
        R.FirstName + ' ' + R.LastName AS PIName,
        'Medium' AS RiskLevel,
        'Project funded by both corporate and government sources. Potential for controlled technology transfer. ' +
        'Funding sources: ' + STRING_AGG(F.FundingSource, ', ') AS FlagReason,
        'EAR99' AS ExportControlCategory,
        'Review all data sharing and IP agreements between partners. Ensure export control clauses in contracts. ' +
        'Classify all deliverables. Establish clear guidelines for international collaboration.' AS RecommendedAction,
        ISNULL(REG.ExportRestriction, 'Not Yet Classified') AS CurrentStatus
    FROM Project P
    INNER JOIN Institution I ON P.InstitutionID = I.InstitutionID
    INNER JOIN Researcher R ON P.PrincipalInvestigatorID = R.ResearcherID
    INNER JOIN ProjectFunding PF ON P.ProtocolID = PF.ProjectID
    INNER JOIN Funding F ON PF.FundingID = F.FundingID
    LEFT JOIN Regulatory REG ON P.ProtocolID = REG.ProjectID
    WHERE 
        P.Status IN ('Active', 'On-Hold')
        AND (@IncludeResolved = 1 OR REG.ExportRestriction IS NULL OR REG.ExportRestriction = 'None')
    GROUP BY 
        P.ProtocolID, P.ProjectTitle, I.LegalName, I.Type, R.FirstName, R.LastName, REG.ExportRestriction
    HAVING 
        -- Must have both corporate and government funding
        SUM(CASE WHEN F.FundingSource LIKE '%Industry%' OR F.FundingSource LIKE '%Corporate%' THEN 1 ELSE 0 END) > 0
        AND SUM(CASE WHEN F.FundingSource LIKE '%Government%' OR F.FundingSource LIKE '%NIH%' OR F.FundingSource LIKE '%DoD%' THEN 1 ELSE 0 END) > 0;
    
    -- FLAG 5: Projects with existing export restrictions that need renewal review
    INSERT INTO #ExportControlFlags
    SELECT DISTINCT
        P.ProtocolID AS ProjectID,
        P.ProjectTitle,
        I.LegalName AS InstitutionName,
        I.Type AS InstitutionType,
        R.FirstName + ' ' + R.LastName AS PIName,
        'Low' AS RiskLevel,
        'Project currently classified as ' + REG.ExportRestriction + '. ' +
        'IRB approval from ' + CONVERT(VARCHAR, REG.IRBApprovalDate, 101) + ' may require export control re-review.' AS FlagReason,
        REG.ExportRestriction AS ExportControlCategory,
        'Annual review of export control classification. Verify classification is still appropriate. ' +
        'Update Technology Control Plan if needed. Re-train staff on export control procedures.' AS RecommendedAction,
        REG.ExportRestriction AS CurrentStatus
    FROM Project P
    INNER JOIN Institution I ON P.InstitutionID = I.InstitutionID
    INNER JOIN Researcher R ON P.PrincipalInvestigatorID = R.ResearcherID
    INNER JOIN Regulatory REG ON P.ProtocolID = REG.ProjectID
    WHERE 
        REG.ExportRestriction IN ('ITAR', 'EAR')
        AND P.Status IN ('Active', 'On-Hold')
        AND DATEDIFF(MONTH, REG.IRBApprovalDate, GETDATE()) >= 12  -- Older than 12 months
        AND @IncludeResolved = 1;
    
    -- Return results ordered by risk level
    SELECT 
        ProjectID,
        ProjectTitle,
        InstitutionName,
        InstitutionType,
        PIName,
        RiskLevel,
        FlagReason,
        ExportControlCategory,
        RecommendedAction,
        CurrentStatus
    FROM #ExportControlFlags
    ORDER BY 
        CASE RiskLevel 
            WHEN 'High' THEN 1 
            WHEN 'Medium' THEN 2 
            WHEN 'Low' THEN 3 
        END,
        ProjectTitle;
    
    -- Summary statistics
    SELECT 
        COUNT(*) AS TotalProjectsFlagged,
        SUM(CASE WHEN RiskLevel = 'High' THEN 1 ELSE 0 END) AS HighRisk,
        SUM(CASE WHEN RiskLevel = 'Medium' THEN 1 ELSE 0 END) AS MediumRisk,
        SUM(CASE WHEN RiskLevel = 'Low' THEN 1 ELSE 0 END) AS LowRisk,
        SUM(CASE WHEN CurrentStatus = 'Not Yet Classified' THEN 1 ELSE 0 END) AS RequireInitialReview,
        SUM(CASE WHEN CurrentStatus IN ('ITAR', 'EAR') THEN 1 ELSE 0 END) AS RequireRenewalReview,
        COUNT(DISTINCT InstitutionName) AS InstitutionsAffected,
        GETDATE() AS ReportGeneratedDate
    FROM #ExportControlFlags;
    
    DROP TABLE #ExportControlFlags;
END;
GO

-- ============================================================================
-- USAGE EXAMPLES
-- ============================================================================

/*
-- Example 1: Run COI reconciliation for current year
EXEC annual_conflict_of_interest_reconciliation;

-- Example 2: Run COI reconciliation for specific year
EXEC annual_conflict_of_interest_reconciliation @ReviewYear = 2024;

-- Example 3: Flag projects needing export control review (exclude already resolved)
EXEC export_controlled_project_flagging;

-- Example 4: Flag all projects including those already resolved (for annual review)
EXEC export_controlled_project_flagging @IncludeResolved = 1;
*/
