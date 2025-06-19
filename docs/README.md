# Project Statement
Project Name: National Biomedical Research Network (NBRN) Database System
Subtitle: A comprehensive biomedical research tracking platform with advanced analytics capabilities

Project Overview
This repository contains the implementation of a sophisticated database system for the National Biomedical Research Network (NBRN), supporting 300+ global institutions in infectious disease research. The system tracks complex biomedical research data while ensuring compliance with HIPAA, GDPR, FDA 21 CFR Part 11, and other regulatory requirements.

Key Features
Multi-faceted Data Model: Tracks institutions, researchers, clinical trials, biospecimens, intellectual property, and compliance documents

Regulatory Compliance: Built-in support for data anonymization, audit trails, and export control flagging

Advanced Analytics: Includes solutions for 10 complex analytical problems specified in the RFP

Real-time Monitoring: Kafka pipeline for anomaly detection in specimen storage and data access

Machine Learning Integration: Predictive models for trial delays using XGBoost and LSTM networks

Cost-Optimized Architecture: Snowflake data warehouse implementation with storage tiering

Technical Components
Database Design:

Complete EERD with all entities/relationships

SQL schema with constraints (PKs, FKs, CHECKs)

Stored procedures for complex operations

Analytical Solutions:

Institutional analytics and researcher workload monitoring

Compliance tracking and biospecimen chain-of-custody

Publication impact analysis and adverse event reporting

Funding efficiency metrics and conflict-of-interest detection

Advanced Features:

HIPAA-compliant data anonymization views

Geospatial logistics optimization

Machine learning-ready dataset preparation

Visualization:

Dynamic Tableau/PowerBI dashboards

Streamlit app for real-time monitoring

Automated PDF report generation

# Project Timeline
16 - 18 June 2025 = Created custom client problems into one big project and broke down the problem into manageable pieces to approach over like a year.

19 June 2025 - Created EERD Diagram and used help from Deepseek to describe the diagram in the database_design/README.md file
