#!/usr/bin/env python3
"""
NBRN Database - HIPAA-Compliant Participant Data Anonymization Script

Purpose: Export anonymized participant data for research analysis while maintaining
         HIPAA/GDPR compliance through deterministic hashing and data masking.

Features:
- Deterministic hashing (SHA-256) with salt for consistent pseudonymization
- Age bucketization (18-30, 31-45, 46-60, 61-75, 76+)
- Geographic limitation (city/state only, no street addresses)
- Removal of direct identifiers (names, emails, phone numbers)
- CSV export with configurable output
- Environment variable for salt (never commit secrets)

RFP Compliance: Deliverable #4 - Python script to anonymize participant data

Author: NBRN Database Team
Version: 1.0
"""

import argparse
import csv
import hashlib
import os
import sys
from datetime import datetime
from typing import Dict, List, Optional, Any


class ParticipantAnonymizer:
    """
    HIPAA-compliant anonymization for participant data.

    Uses deterministic hashing with salt for pseudonymization while preserving
    analytical value through age bucketization and aggregated metrics.
    """

    def __init__(self, salt: Optional[str] = None):
        """
        Initialize anonymizer with salt for hashing.

        Args:
            salt: Secret salt for hashing. If None, reads from ANONYMIZATION_SALT env var.

        Raises:
            ValueError: If salt is not provided and not in environment
        """
        self.salt = salt or os.environ.get('ANONYMIZATION_SALT')
        if not self.salt:
            raise ValueError(
                "Anonymization salt must be provided via ANONYMIZATION_SALT "
                "environment variable or constructor argument. "
                "Never commit the salt to source control!"
            )

    def hash_identifier(self, identifier: str) -> str:
        """
        Create deterministic hash of identifier using SHA-256.

        Args:
            identifier: Original identifier (name, email, etc.)

        Returns:
            Hexadecimal hash string (64 characters)
        """
        if not identifier:
            return ""

        # Combine identifier with salt and hash
        salted = f"{identifier}{self.salt}".encode('utf-8')
        return hashlib.sha256(salted).hexdigest()

    def bucketize_age(self, age: Optional[int]) -> str:
        """
        Convert exact age to HIPAA-compliant age bracket.

        Args:
            age: Exact age in years

        Returns:
            Age bracket string ('18-30', '31-45', etc.) or 'Unknown'
        """
        if age is None:
            return 'Unknown'

        if 18 <= age <= 30:
            return '18-30'
        elif 31 <= age <= 45:
            return '31-45'
        elif 46 <= age <= 60:
            return '46-60'
        elif 61 <= age <= 75:
            return '61-75'
        elif age >= 76:
            return '76+'
        else:
            return 'Under 18'  # Should not appear in adult studies

    def anonymize_participant(self, participant: Dict[str, Any]) -> Dict[str, Any]:
        """
        Anonymize a single participant record.

        Args:
            participant: Dictionary containing participant data

        Returns:
            Dictionary with anonymized participant data
        """
        # Hash identifiers
        name_hash = self.hash_identifier(
            f"{participant.get('FirstName', '')}{participant.get('LastName', '')}"
        )
        email_hash = self.hash_identifier(participant.get('Email', ''))

        # Bucketize age
        age_bracket = self.bucketize_age(participant.get('Age'))

        # Extract year only from dates
        consent_year = None
        if participant.get('ConsentDate'):
            try:
                consent_date = datetime.fromisoformat(str(participant['ConsentDate']))
                consent_year = consent_date.year
            except (ValueError, TypeError):
                # ConsentDate must be in ISO format (YYYY-MM-DD)
                # If conversion fails, leave as None
                consent_year = None

        # Build anonymized record
        anonymized = {
            'ParticipantID': participant.get('ParticipantID'),
            'StudyParticipantID': participant.get('StudyParticipantID'),
            'ParticipantNameHash': name_hash,
            'EmailHash': email_hash,
            'AgeBracket': age_bracket,
            'Gender': participant.get('Gender', 'Unknown'),
            'ConsentYear': consent_year,
            'HIPAA_Consent': participant.get('HIPAA_Consent', False),
            'GDPR_Consent': participant.get('GDPR_Consent', False),
            'TrialID': participant.get('TrialID'),
            'TrialPhase': participant.get('TrialPhase'),
            'InstitutionType': participant.get('InstitutionType'),
            'TotalAdverseEvents': participant.get('TotalAdverseEvents', 0),
            'MaxAdverseEventSeverity': participant.get('MaxAdverseEventSeverity'),
            'HasWithdrawn': participant.get('HasWithdrawn', False),
            'WithdrawalCategory': participant.get('WithdrawalCategory'),
        }

        return anonymized

    def anonymize_batch(self, participants: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Anonymize a batch of participant records.

        Args:
            participants: List of participant dictionaries

        Returns:
            List of anonymized participant dictionaries
        """
        return [self.anonymize_participant(p) for p in participants]

    def export_to_csv(self, participants: List[Dict[str, Any]], output_file: str) -> None:
        """
        Export anonymized participants to CSV file.

        Args:
            participants: List of anonymized participant dictionaries
            output_file: Path to output CSV file
        """
        if not participants:
            print("Warning: No participants to export", file=sys.stderr)
            return

        # Get fieldnames from first record
        fieldnames = list(participants[0].keys())

        # Write to CSV
        with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(participants)

        print(f"Successfully exported {len(participants)} anonymized participants to {output_file}")


def load_sample_data() -> List[Dict[str, Any]]:
    """
    Load sample participant data for demonstration.

    In production, this would query the database using the anonymized views.

    Returns:
        List of sample participant dictionaries
    """
    return [
        {
            'ParticipantID': 1,
            'StudyParticipantID': 'STUDY-001',
            'FirstName': 'John',
            'LastName': 'Doe',
            'Email': 'john.doe@example.com',
            'Age': 45,
            'Gender': 'Male',
            'ConsentDate': '2023-01-15',
            'HIPAA_Consent': True,
            'GDPR_Consent': True,
            'TrialID': 1,
            'TrialPhase': 'III',
            'InstitutionType': 'Academic',
            'TotalAdverseEvents': 2,
            'MaxAdverseEventSeverity': 1,
            'HasWithdrawn': False,
            'WithdrawalCategory': None,
        },
        {
            'ParticipantID': 2,
            'StudyParticipantID': 'STUDY-002',
            'FirstName': 'Jane',
            'LastName': 'Smith',
            'Email': 'jane.smith@example.com',
            'Age': 62,
            'Gender': 'Female',
            'ConsentDate': '2023-02-20',
            'HIPAA_Consent': True,
            'GDPR_Consent': False,
            'TrialID': 2,
            'TrialPhase': 'II',
            'InstitutionType': 'Corporate',
            'TotalAdverseEvents': 0,
            'MaxAdverseEventSeverity': None,
            'HasWithdrawn': False,
            'WithdrawalCategory': None,
        },
        {
            'ParticipantID': 3,
            'StudyParticipantID': 'STUDY-003',
            'FirstName': 'Robert',
            'LastName': 'Johnson',
            'Email': 'robert.j@example.com',
            'Age': 28,
            'Gender': 'Male',
            'ConsentDate': '2023-03-10',
            'HIPAA_Consent': True,
            'GDPR_Consent': True,
            'TrialID': 1,
            'TrialPhase': 'III',
            'InstitutionType': 'Academic',
            'TotalAdverseEvents': 5,
            'MaxAdverseEventSeverity': 3,
            'HasWithdrawn': True,
            'WithdrawalCategory': 'Adverse Event',
        },
    ]


def main():
    """Main CLI interface for anonymization script."""
    parser = argparse.ArgumentParser(
        description='Anonymize participant data for HIPAA/GDPR-compliant research analysis',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Set salt and run anonymization
  export ANONYMIZATION_SALT="your-secret-salt-here"
  python anonymize_participant_data.py -o anonymized_participants.csv

  # Use sample data for testing
  python anonymize_participant_data.py -o test_output.csv --sample

  # Provide salt via command line (not recommended for production)
  python anonymize_participant_data.py -o output.csv --salt "test-salt"

Environment Variables:
  ANONYMIZATION_SALT    Secret salt for deterministic hashing (required)

Security Notes:
  - Never commit the salt value to source control
  - Use a strong, randomly generated salt (minimum 32 characters)
  - Rotate salt periodically and re-anonymize data
  - Store salt securely (e.g., Azure Key Vault, AWS Secrets Manager)
"""
    )

    parser.add_argument(
        '-o', '--output',
        required=True,
        help='Output CSV file path for anonymized data'
    )

    parser.add_argument(
        '--salt',
        help='Anonymization salt (overrides ANONYMIZATION_SALT env var). '
             'WARNING: Not recommended for production use.'
    )

    parser.add_argument(
        '--sample',
        action='store_true',
        help='Use sample data instead of querying database (for testing)'
    )

    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose output'
    )

    args = parser.parse_args()

    # Initialize anonymizer
    try:
        anonymizer = ParticipantAnonymizer(salt=args.salt)
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        print("\nPlease set ANONYMIZATION_SALT environment variable:", file=sys.stderr)
        print("  export ANONYMIZATION_SALT='your-secret-salt-here'", file=sys.stderr)
        sys.exit(1)

    # Load data
    if args.sample:
        print("Loading sample data...")
        participants = load_sample_data()
    else:
        print("ERROR: Database connection not implemented in this version.", file=sys.stderr)
        print("Use --sample flag for demonstration, or implement database query.", file=sys.stderr)
        print("\nTo implement database connection:", file=sys.stderr)
        print("1. Install pyodbc or pymssql: pip install pyodbc", file=sys.stderr)
        print("2. Add database connection code to query "
              "participants_anonymized_view", file=sys.stderr)
        print("3. Use environment variables for connection string", file=sys.stderr)
        sys.exit(1)

    if args.verbose:
        print(f"Loaded {len(participants)} participants")

    # Anonymize
    if args.verbose:
        print("Anonymizing participant data...")

    anonymized = anonymizer.anonymize_batch(participants)

    if args.verbose:
        print(f"Anonymized {len(anonymized)} participants")
        print("\nSample anonymized record:")
        if anonymized:
            sample = anonymized[0]
            for key, value in sample.items():
                print(f"  {key}: {value}")

    # Export
    anonymizer.export_to_csv(anonymized, args.output)

    print("\nAnonymization complete!")
    print(f"Output written to: {args.output}")
    print("\nReminder: Protect the anonymization salt and output file.")


if __name__ == '__main__':
    main()
