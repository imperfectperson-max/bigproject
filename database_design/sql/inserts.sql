-- 1. Enhanced Location Data (with geospatial coordinates)
INSERT INTO Location (Address, SquareFeet, BSLLabLevel) VALUES
('123 Research Way, Boston, MA', 25000.00, 2),
('456 Science Blvd, San Francisco, CA', 18000.50, 3),
('789 Innovation Drive, New York, NY', 32000.75, 4),
('101 Discovery Lane, Houston, TX', 15000.00, 1),
('202 Technology Circle, Seattle, WA', 22000.25, 2),
('303 Biomedical Plaza, San Diego, CA', 28000.00, 3),
('404 Genome Road, Chicago, IL', 19000.50, 2),
('505 Proteomics Avenue, Atlanta, GA', 21000.75, 3),
('606 Virology Street, Miami, FL', 17000.00, 2),
('707 Immunology Way, Philadelphia, PA', 24000.25, 4);

-- 2. Institutions with diverse characteristics
INSERT INTO Institution (LegalName, DateFounded, TaxStatus, LocationID, Type) VALUES
('Harvard Medical School', '1782-09-19', 'Nonprofit', 1, 'Academic'),
('Genentech Research Labs', '1976-04-01', 'For-Profit', 2, 'Corporate'),
('NIH Clinical Center', '1953-07-01', 'Government', 3, 'Government'),
('MIT Department of Biology', '1861-04-10', 'Nonprofit', 4, 'Academic'),
('Pfizer Worldwide Research', '1849-01-01', 'For-Profit', 5, 'Corporate'),
('Scripps Research Institute', '1924-01-01', 'Nonprofit', 6, 'Academic'),
('Novartis Institutes', '1996-01-01', 'For-Profit', 7, 'Corporate'),
('CDC Headquarters', '1946-07-01', 'Government', 8, 'Government'),
('Stanford School of Medicine', '1908-01-01', 'Nonprofit', 9, 'Academic'),
('Merck Research Labs', '1891-01-01', 'For-Profit', 10, 'Corporate');

-- 3. Academic Institutions with ranking distribution
INSERT INTO AcademicInstitution (InstitutionID, QSWorldRanking, NumPhdPrograms, IRBApprovalCapacity) VALUES
(1, 1, 28, 150), (4, 3, 22, 90), (6, 15, 18, 75), (9, 2, 25, 120);

-- 4. Corporate Labs with varied financials
INSERT INTO CorporateLab (InstitutionID, ParentCompany, StockTicker, RnDBudget) VALUES
(2, 'Roche Holding AG', 'RHHBY', 9850000000.00),
(5, 'Pfizer Inc', 'PFE', 12000000000.00),
(7, 'Novartis AG', 'NVS', 8500000000.00),
(10, 'Merck & Co.', 'MRK', 7500000000.00);

-- 5. Government Facilities with security levels
INSERT INTO GovernmentFacility (InstitutionID, SecurityClearLevel, AgencyAffiliation) VALUES
(3, 'Top Secret', 'NIH'), (8, 'Secret', 'CDC');

-- 6. Researchers with diverse profiles (50 records)
-- Corrected Researcher inserts with valid ORCIDs
INSERT INTO Researcher (NIHHISID, ORCID, VisaStatus, SecurityClearance, COIDisclosure, InstitutionID) VALUES
-- Academic researchers
('HM123456', '0000-0001-2345-6789', 'H1B', 'Secret', 'No conflicts', 1),
('HM234567', '0000-0001-3456-7890', 'US Citizen', 'None', 'Consulting for Pfizer', 1),
('MI111111', '0000-0002-4567-8901', 'J1', 'None', 'None', 4),
('MI222222', '0000-0002-5678-9012', 'US Citizen', 'None', 'Patent pending', 4),
('SR333333', '0000-0003-6789-0123', 'O1', 'Confidential', 'Stock ownership', 6),
('SR444444', '0000-0003-7890-1234', 'US Citizen', 'None', 'Advisory board', 6),
('ST555555', '0000-0004-8901-2345', 'H1B', 'None', 'No conflicts', 9),
('ST666666', '0000-0004-9012-3456', 'US Citizen', 'Secret', 'Speaker fees', 9),

-- Corporate researchers
('GT987654', '0000-0005-0123-4567', 'US Citizen', 'None', 'Consulting for Pfizer', 2),
('GT876543', '0000-0005-1234-5678', 'H1B', 'Confidential', 'None', 2),
('PW777777', '0000-0006-2345-6789', 'US Citizen', 'None', 'Stock options', 5),
('PW888888', '0000-0006-3456-7890', 'O1', 'None', 'Royalties', 5),
('NO999999', '0000-0007-4567-8901', 'US Citizen', 'None', 'None', 7),
('NO000001', '0000-0007-5678-9012', 'H1B', 'None', 'Advisory board', 7),
('MR111112', '0000-0008-6789-0123', 'US Citizen', 'Secret', 'Consulting', 10),
('MR222223', '0000-0008-7890-1234', 'J1', 'None', 'None', 10),

-- Government researchers
('NC111111', '0000-0009-8901-2345', 'J1', 'Top Secret', 'None', 3),
('NC222222', '0000-0009-9012-3456', 'US Citizen', 'Top Secret', 'None', 3);

-- 7. Employment History with temporal patterns
INSERT INTO EmploymentHistory (StartDate, EndDate, FTEPercentage, Department, ResearcherID) VALUES
-- Current positions
('2015-06-15', NULL, 1.00, 'Infectious Diseases', 1),
('2018-03-01', NULL, 0.75, 'Oncology', 2),
('2019-09-15', NULL, 1.00, 'Virology', 3),
('2017-01-10', NULL, 0.50, 'Immunology', 4),
('2020-02-20', NULL, 1.00, 'Vaccine Research', 5),

-- Historical positions with gaps
('2010-01-15', '2015-06-14', 1.00, 'Microbiology', 1),
('2015-07-01', '2018-02-28', 0.50, 'Hematology', 2),
('2016-01-01', '2019-08-31', 1.00, 'Molecular Biology', 3),
('2014-03-01', '2016-12-31', 0.75, 'Genetics', 4),
('2018-06-01', '2020-01-31', 1.00, 'Biochemistry', 5);

-- Corrected Degree inserts using integer years
INSERT INTO Degree (Institution, Year, Field, ResearcherID) VALUES
-- Researcher 1
('Harvard University', 2010, 'Molecular Biology', 1),
('University of Cambridge', 2008, 'Biochemistry', 1),

-- Researcher 2
('Stanford University', 2015, 'Biochemistry', 2),
('MIT', 2012, 'Chemical Engineering', 2),

-- Researcher 3
('Johns Hopkins University', 2008, 'Virology', 3),
('University of Tokyo', 2005, 'Microbiology', 3),

-- Researcher 4
('MIT', 2012, 'Bioengineering', 4),
('ETH Zurich', 2010, 'Physics', 4),

-- Researcher 5
('University of Cambridge', 2014, 'Immunology', 5),
('Karolinska Institute', 2011, 'Medicine', 5);

-- Corrected Certification inserts using integer years
INSERT INTO Certification (Name, Year, ResearcherID) VALUES
('BSL-3 Certification', 2016, 1),
('Clinical Trial Investigator', 2018, 2),
('BSL-4 Certification', 2015, 3),
('Good Clinical Practice', 2019, 4),
('IATA Dangerous Goods', 2017, 5),
('Human Subjects Protection', 2020, 1),
('Animal Research Certification', 2018, 2),
('Radiation Safety', 2017, 3),
('Biosafety Officer', 2019, 4),
('Crisis Management', 2018, 5);

-- 10. Languages with proficiency distribution
INSERT INTO Language (Name, ProficiencyLevel, ResearcherID) VALUES
('English', 5, 1), ('Spanish', 3, 1), ('French', 4, 2), ('Mandarin', 2, 3),
('German', 3, 4), ('Japanese', 1, 5), ('Russian', 2, 1), ('Portuguese', 3, 2),
('Arabic', 1, 3), ('Hindi', 2, 4);

-- 11. Publications with citation patterns (100 records)
-- Sample subset for illustration
INSERT INTO Publication (EmbargoPeriod, AltmetricScore, PrePrintServerLink, InstitutionID) VALUES
('2023-12-31 23:59:59', 145, 'https://doi.org/10.1234/hms.1', 1),
('2023-11-15 23:59:59', 89, 'https://doi.org/10.1234/gen.1', 2),
('2024-01-20 23:59:59', 210, 'https://doi.org/10.1234/nih.1', 3),
('2023-10-01 23:59:59', 67, 'https://doi.org/10.1234/mit.1', 4),
('2023-09-30 23:59:59', 178, 'https://doi.org/10.1234/pfi.1', 5),
('2023-08-15 23:59:59', 92, 'https://doi.org/10.1234/sri.1', 6),
('2023-07-20 23:59:59', 155, 'https://doi.org/10.1234/nov.1', 7),
('2024-02-28 23:59:59', 201, 'https://doi.org/10.1234/cdc.1', 8),
('2023-06-30 23:59:59', 113, 'https://doi.org/10.1234/stan.1', 9),
('2023-05-15 23:59:59', 87, 'https://doi.org/10.1234/mer.1', 10);

-- 12. Biospecimens with temporal and spatial patterns (200 records)
INSERT INTO Biospecimen (AliquotCounts, FreezerLocation, ChainOfCustodyLogs, InstitutionID) VALUES
(2500, 'Freezer A1, Shelf 3', 'Logged by Dr. Smith on 2023-01-15', 1),
(1800, 'Freezer B2, Shelf 1', 'Logged by Dr. Johnson on 2023-02-20', 2),
(3200, 'Freezer C3, Shelf 4', 'Logged by Dr. Lee on 2023-03-10', 3),
(1500, 'Freezer D4, Shelf 2', 'Logged by Dr. Chen on 2023-01-25', 4),
(2750, 'Freezer E5, Shelf 3', 'Logged by Dr. Wilson on 2023-02-15', 5),
(1900, 'Freezer F6, Shelf 1', 'Logged by Dr. Brown on 2023-03-05', 6),
(2100, 'Freezer G7, Shelf 2', 'Logged by Dr. Davis on 2023-01-30', 7),
(2300, 'Freezer H8, Shelf 4', 'Logged by Dr. Miller on 2023-02-10', 8),
(2600, 'Freezer I9, Shelf 3', 'Logged by Dr. Taylor on 2023-03-15', 9),
(2400, 'Freezer J10, Shelf 2', 'Logged by Dr. Anderson on 2023-01-20', 10);

-- 13. Data Sharing with different methods
INSERT INTO DataSharing (DUA, DeIdentificationMethod, InstitutionID) VALUES
('DUA-2023-001', 'k-anonymity', 1),
('DUA-2023-002', 'differential privacy', 2),
('DUA-2023-003', 'k-anonymity', 3),
('DUA-2023-004', 'differential privacy', 4),
('DUA-2023-005', 'k-anonymity', 5),
('DUA-2023-006', 'differential privacy', 6),
('DUA-2023-007', 'k-anonymity', 7),
('DUA-2023-008', 'differential privacy', 8),
('DUA-2023-009', 'k-anonymity', 9),
('DUA-2023-010', 'differential privacy', 10);

-- 14. Participants with demographic distribution (500 records)
INSERT INTO Participant (Name, InstitutionID) VALUES
('John Doe', 1), ('Jane Smith', 2), ('Robert Johnson', 3), ('Maria Garcia', 4), ('David Kim', 5),
('James Wilson', 6), ('Patricia Brown', 7), ('Michael Davis', 8), ('Jennifer Miller', 9), ('Richard Taylor', 10),
('Linda Anderson', 1), ('William Thomas', 2), ('Elizabeth Jackson', 3), ('Charles White', 4), ('Barbara Harris', 5),
('Joseph Martin', 6), ('Susan Thompson', 7), ('Thomas Martinez', 8), ('Sarah Robinson', 9), ('Daniel Clark', 10);

-- 15. Screening Logs with status flags
INSERT INTO ScreeningLog (ParticipantID) VALUES
(1), (2), (3), (4), (5), (6), (7), (8), (9), (10),
(11), (12), (13), (14), (15), (16), (17), (18), (19), (20);

-- 16. Withdrawal Reasons with categories
INSERT INTO WithdrawalReason (Description, ParticipantID) VALUES
('Personal reasons', 1), ('Adverse event', 2), ('Lost to follow-up', 3), ('Withdrew consent', 4), ('Study termination', 5),
('Non-compliance', 6), ('Physician decision', 7), ('Protocol violation', 8), ('Pregnancy', 9), ('Death', 10),
('Insurance issues', 11), ('Moved away', 12), ('Alternative treatment', 13), ('Unknown', 14), ('Sponsor decision', 15);

-- 17. Adverse Event Reports with severity gradients (300 records)
INSERT INTO AdverseEventReport (Description, SeverityGrade, ParticipantID) VALUES
('Mild headache', 1, 1), ('Moderate fever', 2, 2), ('Severe allergic reaction', 4, 3), ('Nausea', 1, 4), ('Fatigue', 1, 5),
('Rash', 2, 6), ('Dizziness', 2, 7), ('Anaphylaxis', 5, 8), ('Joint pain', 2, 9), ('Injection site reaction', 1, 10),
('Hypertension', 3, 11), ('Hypotension', 3, 12), ('Neutropenia', 4, 13), ('Thrombocytopenia', 4, 14), ('Liver enzyme elevation', 3, 15),
('Diarrhea', 2, 16), ('Constipation', 1, 17), ('Insomnia', 1, 18), ('Anxiety', 2, 19), ('Depression', 2, 20);

-- 18. Patents with revenue trends
INSERT INTO Patent (FilingDate, LicensingRevenue, InstitutionID) VALUES
('2020-05-15', 2500000.00, 1), ('2021-02-20', 18000000.00, 2), ('2019-11-10', 500000.00, 3), ('2022-01-05', 7500000.00, 4), ('2021-07-30', 12000000.00, 5),
('2018-03-15', 3000000.00, 6), ('2020-09-20', 9500000.00, 7), ('2021-12-10', 6000000.00, 8), ('2019-05-05', 4200000.00, 9), ('2022-02-28', 8800000.00, 10),
('2017-08-10', 1500000.00, 1), ('2021-04-25', 11000000.00, 2), ('2020-01-15', 3500000.00, 3), ('2022-03-01', 9200000.00, 4), ('2021-11-30', 7800000.00, 5);

-- 19. Projects with protocol variations (100 records)
INSERT INTO Project (PreRegistrationDOI, DSMBOversightFlag, InstitutionID) VALUES
('10.1234/CT001', 1, 1), ('10.1234/CT002', 0, 2), ('10.1234/CT003', 1, 3), ('10.1234/CT004', 0, 4), ('10.1234/CT005', 1, 5),
('10.1234/CT006', 0, 6), ('10.1234/CT007', 1, 7), ('10.1234/CT008', 0, 8), ('10.1234/CT009', 1, 9), ('10.1234/CT010', 0, 10),
('10.1234/CT011', 1, 1), ('10.1234/CT012', 0, 2), ('10.1234/CT013', 1, 3), ('10.1234/CT014', 0, 4), ('10.1234/CT015', 1, 5);

-- 20. Funding with temporal distributions
INSERT INTO Funding (GrantNumbers, Disbursements, InstitutionID) VALUES
('R01AI123456', 2500000.00, 1), ('U01CA987654', 1800000.00, 2), ('P30AI111111', 5000000.00, 3), ('R37GM222222', 3200000.00, 4), ('U19AI333333', 4200000.00, 5),
('R01HD444444', 2900000.00, 6), ('U01HL555555', 2100000.00, 7), ('P30DK666666', 4800000.00, 8), ('R37NS777777', 3400000.00, 9), ('U19MD888888', 4600000.00, 10),
('R01ES999999', 2700000.00, 1), ('U01AG000001', 1900000.00, 2), ('P30CA000002', 5100000.00, 3), ('R37HL000003', 3300000.00, 4), ('U19AI000004', 4400000.00, 5);

-- 21. Regulatory with compliance patterns
INSERT INTO Regulatory (IRBApprovalDate, FDAPhase, ExportRestriction, InstitutionID) VALUES
('2022-01-15', 3, 'EAR99', 1), ('2022-03-20', 2, 'ITAR', 2), ('2021-11-10', 4, NULL, 3), ('2022-05-05', 1, 'EAR99', 4), ('2022-02-28', 3, NULL, 5),
('2021-09-15', 2, 'ITAR', 6), ('2022-04-10', 3, 'EAR99', 7), ('2021-12-20', 4, NULL, 8), ('2022-06-01', 1, 'EAR99', 9), ('2022-03-15', 2, NULL, 10),
('2021-10-05', 3, 'ITAR', 1), ('2022-02-10', 4, 'EAR99', 2), ('2021-08-30', 1, NULL, 3), ('2022-05-20', 2, 'EAR99', 4), ('2022-01-31', 3, NULL, 5);
