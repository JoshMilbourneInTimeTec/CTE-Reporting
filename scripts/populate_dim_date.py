#!/usr/bin/env python3
"""
File: scripts/populate_dim_date.py
Purpose: Populate the dim_date time dimension table in SkillStack_DW
Date Range: 2000-01-01 to 2040-12-31 (14,976 rows)
Features: Calendar attributes, fiscal year (July 1 start), federal/Idaho holidays

Federal Holidays (11 total):
  - New Year's Day (Jan 1)
  - MLK Day (3rd Mon in Jan)
  - Presidents' Day (3rd Mon in Feb)
  - Memorial Day (last Mon in May)
  - Juneteenth (Jun 19) - only from 2021 onward
  - Independence Day (Jul 4)
  - Labor Day (1st Mon in Sep)
  - Columbus Day (2nd Mon in Oct)
  - Veterans Day (Nov 11)
  - Thanksgiving (4th Thu in Nov)
  - Christmas (Dec 25)

Idaho State Holidays (2 additional):
  - Human Rights Day (same as MLK Day - 3rd Mon in Jan)
  - Idaho Day (March 4, with observance rules for weekends)
"""

import sys
import os
from datetime import datetime, timedelta
import pyodbc
from dateutil.easter import easter
import calendar

# ============================================================================
# Configuration
# ============================================================================

# Database connection parameters (from environment variables)
SERVER = os.getenv('SQL_SERVER', '10.160.8.18')
USER = os.getenv('SQL_USER', 'ITT.josh.milbourne')
PASSWORD = os.getenv('SQL_PASSWORD', '')
DATABASE = 'SkillStack_DW'

# Date range for dimension
START_DATE = datetime(2000, 1, 1)
END_DATE = datetime(2040, 12, 31)

# Batch insert size for performance
BATCH_SIZE = 1000


# ============================================================================
# DateDimensionGenerator Class
# ============================================================================

class DateDimensionGenerator:
    """Generate date dimension records with all attributes and holidays."""

    def __init__(self, start_date, end_date):
        """Initialize date dimension generator."""
        self.start_date = start_date
        self.end_date = end_date
        self.current_date = start_date

    def get_nth_weekday(self, year, month, weekday, n):
        """
        Get the nth occurrence of a weekday in a given month.

        Args:
            year: Year
            month: Month (1-12)
            weekday: Weekday (0=Monday, 6=Sunday)
            n: Occurrence (1=first, 2=second, etc., -1=last)

        Returns:
            date object for the nth occurrence
        """
        if n > 0:
            # Find first occurrence
            first_day = datetime(year, month, 1)
            first_occurrence = first_day + timedelta(days=(weekday - first_day.weekday()) % 7)

            # Add weeks to get nth occurrence
            target_date = first_occurrence + timedelta(weeks=n - 1)

            # Make sure we're still in the target month
            if target_date.month == month:
                return target_date
            else:
                return None
        else:
            # Find last occurrence (n = -1)
            # Get first day of next month, then go back
            if month == 12:
                first_of_next_month = datetime(year + 1, 1, 1)
            else:
                first_of_next_month = datetime(year, month + 1, 1)

            # Go back one day
            last_day_of_month = first_of_next_month - timedelta(days=1)

            # Find the last occurrence of the weekday
            days_back = (last_day_of_month.weekday() - weekday) % 7
            target_date = last_day_of_month - timedelta(days=days_back)

            return target_date

    def is_federal_holiday(self, dt):
        """Determine if date is a federal holiday."""
        month = dt.month
        day = dt.day
        year = dt.year
        weekday_num = dt.weekday()  # 0=Monday, 6=Sunday

        # Fixed date holidays
        if month == 1 and day == 1:
            return 'New Year\'s Day'
        if month == 7 and day == 4:
            return 'Independence Day'
        if month == 11 and day == 11:
            return 'Veterans Day'
        if month == 12 and day == 25:
            return 'Christmas'

        # Juneteenth (June 19) - federal holiday only from 2021 onward
        if month == 6 and day == 19 and year >= 2021:
            return 'Juneteenth'

        # Floating holidays (nth weekday of month)

        # MLK Day: 3rd Monday in January (0=Monday, so weekday_num=0)
        if month == 1:
            mlk_date = self.get_nth_weekday(year, 1, 0, 3)  # 3rd Monday
            if mlk_date and mlk_date.day == day:
                return 'Martin Luther King Jr. Day'

        # Presidents' Day: 3rd Monday in February
        if month == 2:
            pres_date = self.get_nth_weekday(year, 2, 0, 3)  # 3rd Monday
            if pres_date and pres_date.day == day:
                return 'Presidents\' Day'

        # Memorial Day: Last Monday in May
        if month == 5:
            mem_date = self.get_nth_weekday(year, 5, 0, -1)  # Last Monday
            if mem_date and mem_date.day == day:
                return 'Memorial Day'

        # Labor Day: 1st Monday in September
        if month == 9:
            labor_date = self.get_nth_weekday(year, 9, 0, 1)  # 1st Monday
            if labor_date and labor_date.day == day:
                return 'Labor Day'

        # Columbus Day: 2nd Monday in October
        if month == 10:
            columbus_date = self.get_nth_weekday(year, 10, 0, 2)  # 2nd Monday
            if columbus_date and columbus_date.day == day:
                return 'Columbus Day'

        # Thanksgiving: 4th Thursday in November (3=Thursday)
        if month == 11:
            thanksgiving_date = self.get_nth_weekday(year, 11, 3, 4)  # 4th Thursday
            if thanksgiving_date and thanksgiving_date.day == day:
                return 'Thanksgiving'

        return None

    def is_idaho_state_holiday(self, dt):
        """Determine if date is an Idaho state holiday."""
        month = dt.month
        day = dt.day
        year = dt.year

        # Human Rights Day: 3rd Monday in January (same as MLK Day)
        if month == 1:
            human_rights_date = self.get_nth_weekday(year, 1, 0, 3)  # 3rd Monday
            if human_rights_date and human_rights_date.day == day:
                return 'Idaho Human Rights Day'

        # Idaho Day: March 4 with observance rules
        # If March 4 is Sunday, observe on Monday, March 5
        # If March 4 is Saturday, observe on Friday, March 3
        # Otherwise, observe on March 4
        march_4 = datetime(year, 3, 4)
        weekday = march_4.weekday()  # 0=Monday, 5=Saturday, 6=Sunday

        observed_date = march_4
        if weekday == 6:  # Sunday
            observed_date = datetime(year, 3, 5)  # Move to Monday
        elif weekday == 5:  # Saturday
            observed_date = datetime(year, 3, 3)  # Move to Friday

        if observed_date.day == day and observed_date.month == 3:
            return 'Idaho Day'

        return None

    def get_fiscal_year(self, dt):
        """Get fiscal year (FY starts July 1)."""
        if dt.month >= 7:
            return dt.year + 1
        else:
            return dt.year

    def get_fiscal_quarter(self, dt):
        """Get fiscal quarter (Q1: Jul-Sep, Q2: Oct-Dec, Q3: Jan-Mar, Q4: Apr-Jun)."""
        month = dt.month
        if 7 <= month <= 9:
            return 1
        elif 10 <= month <= 12:
            return 2
        elif 1 <= month <= 3:
            return 3
        else:  # Apr-Jun
            return 4

    def get_fiscal_month(self, dt):
        """Get fiscal month (1=July, 2=August, ..., 12=June)."""
        month = dt.month
        if month >= 7:
            return month - 6
        else:
            return month + 6

    def get_fiscal_week(self, dt):
        """Get fiscal week number within fiscal year."""
        # Get July 1 of the fiscal year start
        fy = self.get_fiscal_year(dt)
        fy_start = datetime(fy - 1, 7, 1)

        # Calculate days since start of fiscal year
        days_since_fy_start = (dt - fy_start).days

        # Calculate week number (1-based)
        week_num = (days_since_fy_start // 7) + 1

        return min(week_num, 53)  # Cap at 53 weeks

    def get_week_of_year_us(self, dt):
        """Get week of year (US standard: Sunday = first day of week)."""
        # ISO calendar uses Monday as first day, but we want Sunday
        # We'll use a manual calculation
        year_start = datetime(dt.year, 1, 1)

        # Find first Sunday of the year
        days_until_sunday = (6 - year_start.weekday()) % 7
        first_sunday = year_start + timedelta(days=days_until_sunday)

        if dt < first_sunday:
            # Part of week 0 (before first Sunday)
            return 1
        else:
            # Calculate weeks since first Sunday
            days_since_first_sunday = (dt - first_sunday).days
            week_num = (days_since_first_sunday // 7) + 1
            return min(week_num, 53)

    def get_iso_week(self, dt):
        """Get ISO 8601 week number."""
        iso_calendar = dt.isocalendar()
        return iso_calendar[1]

    def is_last_day_of_month(self, dt):
        """Check if date is the last day of the month."""
        next_day = dt + timedelta(days=1)
        return next_day.month != dt.month

    def is_last_day_of_calendar_quarter(self, dt):
        """Check if date is the last day of the calendar quarter."""
        quarter_end_months = [3, 6, 9, 12]  # Mar, Jun, Sep, Dec
        if dt.month not in quarter_end_months:
            return False
        return self.is_last_day_of_month(dt)

    def is_last_day_of_year(self, dt):
        """Check if date is the last day of the year."""
        return dt.month == 12 and dt.day == 31

    def generate_records(self):
        """Generate all date dimension records."""
        records = []
        current = self.start_date

        while current <= self.end_date:
            date_key = int(current.strftime('%Y%m%d'))
            date_value = current

            # Calendar attributes
            year = current.year
            quarter = (current.month - 1) // 3 + 1
            month = current.month
            month_name = current.strftime('%B')
            month_name_short = current.strftime('%b')
            day_of_month = current.day
            day_of_year = current.timetuple().tm_yday

            # Week attributes
            week_of_year = self.get_week_of_year_us(current)
            iso_week = self.get_iso_week(current)

            # Day attributes
            day_of_week = (current.weekday() + 1) % 7 + 1  # Convert to 1=Sun, 2=Mon, etc.
            day_name = current.strftime('%A')
            day_name_short = current.strftime('%a')

            # Weekend/weekday flags
            is_weekend = 1 if current.weekday() in [5, 6] else 0  # 5=Sat, 6=Sun
            is_weekday = 0 if is_weekend else 1

            # Fiscal year attributes
            fiscal_year = self.get_fiscal_year(current)
            fiscal_quarter = self.get_fiscal_quarter(current)
            fiscal_month = self.get_fiscal_month(current)
            fiscal_week = self.get_fiscal_week(current)

            # Holiday flags
            federal_holiday = self.is_federal_holiday(current)
            idaho_holiday = self.is_idaho_state_holiday(current)

            is_federal_holiday = 1 if federal_holiday else 0
            is_idaho_state_holiday = 1 if idaho_holiday else 0

            # Determine which holiday name to store (federal takes precedence)
            holiday_name = federal_holiday or idaho_holiday

            # Period end flags
            is_last_day_of_month_val = 1 if self.is_last_day_of_month(current) else 0
            is_last_day_of_quarter = 1 if self.is_last_day_of_calendar_quarter(current) else 0
            is_last_day_of_year = 1 if self.is_last_day_of_year(current) else 0

            # Create record tuple
            record = (
                date_key,
                date_value,
                year,
                quarter,
                month,
                month_name,
                month_name_short,
                day_of_month,
                day_of_year,
                week_of_year,
                iso_week,
                day_of_week,
                day_name,
                day_name_short,
                is_weekend,
                is_weekday,
                fiscal_year,
                fiscal_quarter,
                fiscal_month,
                fiscal_week,
                is_federal_holiday,
                is_idaho_state_holiday,
                holiday_name,
                is_last_day_of_month_val,
                is_last_day_of_quarter,
                is_last_day_of_year
            )

            records.append(record)
            current += timedelta(days=1)

        return records


# ============================================================================
# Database Operations
# ============================================================================

def insert_records_batch(cursor, records):
    """Insert records into dim_date table in batches."""
    insert_sql = """
    INSERT INTO dbo.dim_date (
        date_key, date_value, year, quarter, month, month_name, month_name_short,
        day_of_month, day_of_year, week_of_year, iso_week, day_of_week,
        day_name, day_name_short, is_weekend, is_weekday, fiscal_year,
        fiscal_quarter, fiscal_month, fiscal_week, is_federal_holiday,
        is_idaho_state_holiday, holiday_name, is_last_day_of_month,
        is_last_day_of_quarter, is_last_day_of_year
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """

    total_inserted = 0
    for i in range(0, len(records), BATCH_SIZE):
        batch = records[i:i + BATCH_SIZE]
        cursor.executemany(insert_sql, batch)
        cursor.commit()
        total_inserted += len(batch)
        print(f'  Inserted {total_inserted} records...', flush=True)

    return total_inserted


# ============================================================================
# Main Execution
# ============================================================================

def main():
    """Main execution function."""
    print('')
    print('=' * 80)
    print('Populating dim_date Time Dimension Table')
    print('=' * 80)
    print(f'Date Range: {START_DATE.strftime("%Y-%m-%d")} to {END_DATE.strftime("%Y-%m-%d")}')
    print('')

    try:
        # Generate records
        print('Generating date dimension records...')
        generator = DateDimensionGenerator(START_DATE, END_DATE)
        records = generator.generate_records()

        print(f'Generated {len(records)} date records')

        # Count holidays for reporting
        federal_holidays = sum(1 for r in records if r[20] == 1)  # is_federal_holiday
        idaho_holidays = sum(1 for r in records if r[21] == 1)    # is_idaho_state_holiday

        print(f'  Federal holidays: {federal_holidays}')
        print(f'  Idaho state holidays: {idaho_holidays}')
        print('')

        # Connect to database
        print('Connecting to database...')
        conn_string = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};UID={USER};PWD={PASSWORD};Encrypt=yes;TrustServerCertificate=yes'

        conn = pyodbc.connect(conn_string)
        cursor = conn.cursor()
        print(f'Connected to {SERVER}/{DATABASE}')
        print('')

        # Insert records
        print('Inserting records into dim_date table...')
        total = insert_records_batch(cursor, records)
        cursor.close()
        conn.close()

        print('')
        print('=' * 80)
        print('Dim_date Population Completed Successfully')
        print('=' * 80)
        print(f'Total records inserted: {total}')
        print(f'Expected records: {len(records)}')
        print(f'Status: {"✓ SUCCESS" if total == len(records) else "✗ MISMATCH"}')
        print('')

        return 0

    except Exception as e:
        print('')
        print('=' * 80)
        print('Error During Dim_date Population')
        print('=' * 80)
        print(f'Error: {str(e)}')
        print('')
        return 1


if __name__ == '__main__':
    sys.exit(main())
