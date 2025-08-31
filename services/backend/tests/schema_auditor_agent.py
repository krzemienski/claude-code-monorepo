#!/usr/bin/env python3
"""
Schema Auditor Agent

Automated database schema validation and compliance checking for backend systems.
Validates documented schemas against actual database implementation.
"""

import asyncio
import json
import os
from typing import Dict, List, Optional, Set
from datetime import datetime
from dataclasses import dataclass, field
from enum import Enum
import asyncpg
from sqlalchemy import create_engine, inspect, MetaData
from sqlalchemy.engine import Engine
from sqlalchemy.schema import Table


class SchemaComplianceLevel(Enum):
    """Schema compliance levels"""
    COMPLIANT = "✅ COMPLIANT"
    MINOR_DEVIATION = "⚠️ MINOR_DEVIATION"
    MAJOR_DEVIATION = "❌ MAJOR_DEVIATION"
    MISSING = "🔴 MISSING"
    UNDOCUMENTED = "📝 UNDOCUMENTED"


@dataclass
class ColumnValidation:
    """Column validation result"""
    column_name: str
    documented_type: Optional[str]
    actual_type: Optional[str]
    nullable: Optional[bool]
    has_default: Optional[bool]
    is_primary_key: bool
    is_foreign_key: bool
    compliance: SchemaComplianceLevel
    notes: List[str] = field(default_factory=list)


@dataclass
class TableValidation:
    """Table validation result"""
    table_name: str
    exists: bool
    documented: bool
    columns: List[ColumnValidation]
    indexes: List[Dict]
    foreign_keys: List[Dict]
    compliance: SchemaComplianceLevel
    missing_columns: List[str] = field(default_factory=list)
    extra_columns: List[str] = field(default_factory=list)


@dataclass
class SchemaAuditReport:
    """Complete schema audit report"""
    timestamp: datetime
    database_url: str
    tables: List[TableValidation]
    compliance_summary: Dict
    recommendations: List[str]
    migration_scripts: List[str]


class SchemaAuditor:
    """
    Database schema auditor for validating:
    - Table existence and structure
    - Column types and constraints
    - Indexes and performance optimizations
    - Foreign key relationships
    - Migration compliance
    """
    
    # Documented schema based on backend models
    DOCUMENTED_SCHEMA = {
        "users": {
            "columns": {
                "id": {"type": "UUID", "nullable": False, "primary_key": True},
                "email": {"type": "VARCHAR(255)", "nullable": False, "unique": True},
                "username": {"type": "VARCHAR(100)", "nullable": True, "unique": True},
                "password_hash": {"type": "VARCHAR(255)", "nullable": False},
                "api_key": {"type": "VARCHAR(255)", "nullable": False, "unique": True},
                "roles": {"type": "JSON", "nullable": True, "default": ["user"]},
                "permissions": {"type": "JSON", "nullable": True, "default": []},
                "last_login": {"type": "TIMESTAMP", "nullable": True},
                "last_password_change": {"type": "TIMESTAMP", "nullable": True},
                "failed_login_attempts": {"type": "INTEGER", "nullable": False, "default": 0},
                "locked_until": {"type": "TIMESTAMP", "nullable": True},
                "is_active": {"type": "BOOLEAN", "nullable": False, "default": True},
                "is_superuser": {"type": "BOOLEAN", "nullable": False, "default": False},
                "preferences": {"type": "TEXT", "nullable": True},
                "created_at": {"type": "TIMESTAMP", "nullable": False},
                "updated_at": {"type": "TIMESTAMP", "nullable": False}
            },
            "indexes": ["email", "username", "api_key"],
            "foreign_keys": []
        },
        "sessions": {
            "columns": {
                "id": {"type": "UUID", "nullable": False, "primary_key": True},
                "user_id": {"type": "UUID", "nullable": False, "foreign_key": "users.id"},
                "name": {"type": "VARCHAR(255)", "nullable": False},
                "model": {"type": "VARCHAR(100)", "nullable": False},
                "messages": {"type": "JSON", "nullable": True},
                "context": {"type": "TEXT", "nullable": True},
                "is_active": {"type": "BOOLEAN", "nullable": False, "default": True},
                "is_archived": {"type": "BOOLEAN", "nullable": False, "default": False},
                "token_count": {"type": "INTEGER", "nullable": False, "default": 0},
                "created_at": {"type": "TIMESTAMP", "nullable": False},
                "updated_at": {"type": "TIMESTAMP", "nullable": False},
                "last_activity": {"type": "TIMESTAMP", "nullable": True}
            },
            "indexes": ["user_id", "is_active", "created_at"],
            "foreign_keys": ["user_id"]
        },
        "messages": {
            "columns": {
                "id": {"type": "UUID", "nullable": False, "primary_key": True},
                "session_id": {"type": "UUID", "nullable": False, "foreign_key": "sessions.id"},
                "role": {"type": "VARCHAR(50)", "nullable": False},
                "content": {"type": "TEXT", "nullable": False},
                "tokens": {"type": "INTEGER", "nullable": True},
                "created_at": {"type": "TIMESTAMP", "nullable": False}
            },
            "indexes": ["session_id", "created_at"],
            "foreign_keys": ["session_id"]
        },
        "projects": {
            "columns": {
                "id": {"type": "UUID", "nullable": False, "primary_key": True},
                "owner_id": {"type": "UUID", "nullable": False, "foreign_key": "users.id"},
                "name": {"type": "VARCHAR(255)", "nullable": False},
                "description": {"type": "TEXT", "nullable": True},
                "path": {"type": "TEXT", "nullable": True},
                "settings": {"type": "JSON", "nullable": True},
                "is_active": {"type": "BOOLEAN", "nullable": False, "default": True},
                "created_at": {"type": "TIMESTAMP", "nullable": False},
                "updated_at": {"type": "TIMESTAMP", "nullable": False}
            },
            "indexes": ["owner_id", "name"],
            "foreign_keys": ["owner_id"]
        },
        "mcp_configs": {
            "columns": {
                "id": {"type": "UUID", "nullable": False, "primary_key": True},
                "user_id": {"type": "UUID", "nullable": False, "foreign_key": "users.id"},
                "server_name": {"type": "VARCHAR(100)", "nullable": False},
                "config": {"type": "JSON", "nullable": False},
                "is_enabled": {"type": "BOOLEAN", "nullable": False, "default": True},
                "created_at": {"type": "TIMESTAMP", "nullable": False},
                "updated_at": {"type": "TIMESTAMP", "nullable": False}
            },
            "indexes": ["user_id", "server_name"],
            "foreign_keys": ["user_id"]
        }
    }
    
    def __init__(self, database_url: Optional[str] = None):
        self.database_url = database_url or os.getenv(
            "DATABASE_URL", 
            "postgresql://postgres:postgres@localhost:5432/claudecode"
        )
        self.engine: Optional[Engine] = None
        self.validations: List[TableValidation] = []
    
    async def run_audit(self) -> SchemaAuditReport:
        """
        Run complete schema audit
        """
        print("🔍 Starting Database Schema Audit")
        print("=" * 60)
        
        # Connect to database
        if not await self._connect_database():
            return self._generate_connection_error_report()
        
        # Audit each documented table
        for table_name, schema in self.DOCUMENTED_SCHEMA.items():
            validation = await self._audit_table(table_name, schema)
            self.validations.append(validation)
        
        # Check for undocumented tables
        await self._check_undocumented_tables()
        
        # Generate recommendations
        recommendations = self._generate_recommendations()
        
        # Generate migration scripts
        migration_scripts = self._generate_migration_scripts()
        
        # Create report
        report = SchemaAuditReport(
            timestamp=datetime.utcnow(),
            database_url=self._sanitize_db_url(),
            tables=self.validations,
            compliance_summary=self._calculate_compliance_summary(),
            recommendations=recommendations,
            migration_scripts=migration_scripts
        )
        
        # Print summary
        self._print_summary(report)
        
        # Save report
        self._save_report(report)
        
        return report
    
    async def _connect_database(self) -> bool:
        """Connect to database"""
        try:
            # Parse and sanitize connection string
            db_url = self.database_url
            if db_url.startswith("postgresql://"):
                db_url = db_url.replace("postgresql://", "postgresql+psycopg2://")
            elif not db_url.startswith("postgresql+"):
                db_url = f"postgresql+psycopg2://{db_url}"
            
            self.engine = create_engine(db_url)
            
            # Test connection
            with self.engine.connect() as conn:
                print(f"✅ Connected to database")
                return True
                
        except Exception as e:
            print(f"❌ Failed to connect to database: {str(e)}")
            return False
    
    async def _audit_table(self, table_name: str, documented_schema: Dict) -> TableValidation:
        """Audit a single table"""
        print(f"\n📋 Auditing table: {table_name}")
        print("-" * 40)
        
        validation = TableValidation(
            table_name=table_name,
            exists=False,
            documented=True,
            columns=[],
            indexes=[],
            foreign_keys=[],
            compliance=SchemaComplianceLevel.MISSING
        )
        
        try:
            inspector = inspect(self.engine)
            
            # Check if table exists
            if table_name not in inspector.get_table_names():
                print(f"  ❌ Table does not exist")
                validation.compliance = SchemaComplianceLevel.MISSING
                return validation
            
            validation.exists = True
            print(f"  ✅ Table exists")
            
            # Get actual columns
            actual_columns = inspector.get_columns(table_name)
            actual_column_names = {col['name'] for col in actual_columns}
            
            # Get documented columns
            documented_columns = documented_schema['columns']
            documented_column_names = set(documented_columns.keys())
            
            # Check for missing columns
            missing = documented_column_names - actual_column_names
            if missing:
                validation.missing_columns = list(missing)
                print(f"  ⚠️ Missing columns: {', '.join(missing)}")
            
            # Check for extra columns
            extra = actual_column_names - documented_column_names
            if extra:
                validation.extra_columns = list(extra)
                print(f"  📝 Undocumented columns: {', '.join(extra)}")
            
            # Validate each column
            for col_name, col_spec in documented_columns.items():
                col_validation = self._validate_column(
                    col_name, 
                    col_spec,
                    actual_columns
                )
                validation.columns.append(col_validation)
            
            # Get indexes
            validation.indexes = inspector.get_indexes(table_name)
            if validation.indexes:
                print(f"  📊 Indexes: {len(validation.indexes)}")
            
            # Get foreign keys
            validation.foreign_keys = inspector.get_foreign_keys(table_name)
            if validation.foreign_keys:
                print(f"  🔗 Foreign keys: {len(validation.foreign_keys)}")
            
            # Determine compliance level
            if missing:
                validation.compliance = SchemaComplianceLevel.MAJOR_DEVIATION
            elif extra:
                validation.compliance = SchemaComplianceLevel.MINOR_DEVIATION
            else:
                validation.compliance = SchemaComplianceLevel.COMPLIANT
                print(f"  ✅ Schema compliant")
            
        except Exception as e:
            print(f"  🔴 Error auditing table: {str(e)}")
            validation.compliance = SchemaComplianceLevel.MISSING
        
        return validation
    
    def _validate_column(
        self, 
        col_name: str, 
        documented: Dict,
        actual_columns: List[Dict]
    ) -> ColumnValidation:
        """Validate a single column"""
        actual_col = next((c for c in actual_columns if c['name'] == col_name), None)
        
        if not actual_col:
            return ColumnValidation(
                column_name=col_name,
                documented_type=documented.get('type'),
                actual_type=None,
                nullable=documented.get('nullable'),
                has_default=documented.get('default') is not None,
                is_primary_key=documented.get('primary_key', False),
                is_foreign_key='foreign_key' in documented,
                compliance=SchemaComplianceLevel.MISSING,
                notes=["Column not found in database"]
            )
        
        # Compare types
        actual_type = str(actual_col['type'])
        documented_type = documented.get('type', '')
        
        # Normalize type names for comparison
        type_match = self._types_match(documented_type, actual_type)
        
        validation = ColumnValidation(
            column_name=col_name,
            documented_type=documented_type,
            actual_type=actual_type,
            nullable=actual_col.get('nullable'),
            has_default=actual_col.get('default') is not None,
            is_primary_key=documented.get('primary_key', False),
            is_foreign_key='foreign_key' in documented,
            compliance=SchemaComplianceLevel.COMPLIANT if type_match else SchemaComplianceLevel.MINOR_DEVIATION,
            notes=[]
        )
        
        # Check nullable mismatch
        if documented.get('nullable') != actual_col.get('nullable'):
            validation.notes.append(
                f"Nullable mismatch: documented={documented.get('nullable')}, "
                f"actual={actual_col.get('nullable')}"
            )
            validation.compliance = SchemaComplianceLevel.MINOR_DEVIATION
        
        return validation
    
    def _types_match(self, documented: str, actual: str) -> bool:
        """Check if types match (with normalization)"""
        # Normalize types for comparison
        type_mappings = {
            "UUID": ["UUID", "CHAR(36)"],
            "VARCHAR": ["VARCHAR", "CHARACTER VARYING", "TEXT"],
            "BOOLEAN": ["BOOLEAN", "BOOL"],
            "INTEGER": ["INTEGER", "INT", "INT4"],
            "TIMESTAMP": ["TIMESTAMP", "DATETIME"],
            "JSON": ["JSON", "JSONB"],
            "TEXT": ["TEXT", "VARCHAR", "CHARACTER VARYING"]
        }
        
        documented_upper = documented.upper().split('(')[0]
        actual_upper = actual.upper().split('(')[0]
        
        for key, variants in type_mappings.items():
            if documented_upper in variants and actual_upper in variants:
                return True
        
        return documented_upper == actual_upper
    
    async def _check_undocumented_tables(self):
        """Check for tables not in documentation"""
        try:
            inspector = inspect(self.engine)
            actual_tables = set(inspector.get_table_names())
            documented_tables = set(self.DOCUMENTED_SCHEMA.keys())
            
            # Skip system tables
            system_tables = {'alembic_version', 'spatial_ref_sys'}
            actual_tables = actual_tables - system_tables
            
            undocumented = actual_tables - documented_tables
            
            for table_name in undocumented:
                columns = inspector.get_columns(table_name)
                validation = TableValidation(
                    table_name=table_name,
                    exists=True,
                    documented=False,
                    columns=[],
                    indexes=inspector.get_indexes(table_name),
                    foreign_keys=inspector.get_foreign_keys(table_name),
                    compliance=SchemaComplianceLevel.UNDOCUMENTED,
                    extra_columns=[col['name'] for col in columns]
                )
                self.validations.append(validation)
                print(f"\n📝 Found undocumented table: {table_name}")
                
        except Exception as e:
            print(f"❌ Error checking undocumented tables: {str(e)}")
    
    def _calculate_compliance_summary(self) -> Dict:
        """Calculate compliance summary"""
        summary = {
            "total_tables": len(self.validations),
            "compliant": 0,
            "minor_deviations": 0,
            "major_deviations": 0,
            "missing": 0,
            "undocumented": 0
        }
        
        for validation in self.validations:
            if validation.compliance == SchemaComplianceLevel.COMPLIANT:
                summary["compliant"] += 1
            elif validation.compliance == SchemaComplianceLevel.MINOR_DEVIATION:
                summary["minor_deviations"] += 1
            elif validation.compliance == SchemaComplianceLevel.MAJOR_DEVIATION:
                summary["major_deviations"] += 1
            elif validation.compliance == SchemaComplianceLevel.MISSING:
                summary["missing"] += 1
            elif validation.compliance == SchemaComplianceLevel.UNDOCUMENTED:
                summary["undocumented"] += 1
        
        # Calculate compliance score
        if summary["total_tables"] > 0:
            summary["compliance_score"] = (
                summary["compliant"] / summary["total_tables"] * 100
            )
        else:
            summary["compliance_score"] = 0
        
        return summary
    
    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations based on audit"""
        recommendations = []
        
        for validation in self.validations:
            if validation.compliance == SchemaComplianceLevel.MISSING:
                recommendations.append(
                    f"CREATE TABLE: {validation.table_name} - Table is documented but missing from database"
                )
            
            elif validation.compliance == SchemaComplianceLevel.MAJOR_DEVIATION:
                if validation.missing_columns:
                    recommendations.append(
                        f"ADD COLUMNS to {validation.table_name}: {', '.join(validation.missing_columns)}"
                    )
            
            elif validation.compliance == SchemaComplianceLevel.UNDOCUMENTED:
                recommendations.append(
                    f"DOCUMENT TABLE: {validation.table_name} - Table exists but not documented"
                )
            
            # Check for missing indexes
            if validation.exists and validation.documented:
                documented_indexes = self.DOCUMENTED_SCHEMA.get(
                    validation.table_name, {}
                ).get('indexes', [])
                
                if documented_indexes and not validation.indexes:
                    recommendations.append(
                        f"CREATE INDEXES for {validation.table_name}: Performance may be impacted"
                    )
        
        # Add general recommendations
        if not recommendations:
            recommendations.append("Schema is fully compliant - no immediate actions required")
        else:
            recommendations.insert(0, "⚠️ Schema deviations detected - review and apply migrations")
        
        return recommendations
    
    def _generate_migration_scripts(self) -> List[str]:
        """Generate SQL migration scripts"""
        scripts = []
        
        for validation in self.validations:
            if validation.compliance == SchemaComplianceLevel.MISSING:
                # Generate CREATE TABLE script
                script = self._generate_create_table_script(validation.table_name)
                if script:
                    scripts.append(script)
            
            elif validation.missing_columns:
                # Generate ALTER TABLE scripts
                for col_name in validation.missing_columns:
                    script = self._generate_add_column_script(
                        validation.table_name, 
                        col_name
                    )
                    if script:
                        scripts.append(script)
        
        return scripts
    
    def _generate_create_table_script(self, table_name: str) -> Optional[str]:
        """Generate CREATE TABLE script"""
        if table_name not in self.DOCUMENTED_SCHEMA:
            return None
        
        schema = self.DOCUMENTED_SCHEMA[table_name]
        columns = []
        
        for col_name, col_spec in schema['columns'].items():
            col_def = f"{col_name} {col_spec['type']}"
            
            if not col_spec.get('nullable', True):
                col_def += " NOT NULL"
            
            if col_spec.get('primary_key'):
                col_def += " PRIMARY KEY"
            
            if col_spec.get('unique'):
                col_def += " UNIQUE"
            
            if 'default' in col_spec:
                default = col_spec['default']
                if isinstance(default, str):
                    col_def += f" DEFAULT '{default}'"
                elif isinstance(default, bool):
                    col_def += f" DEFAULT {str(default).upper()}"
                else:
                    col_def += f" DEFAULT {default}"
            
            columns.append(col_def)
        
        # Add foreign keys
        for col_name, col_spec in schema['columns'].items():
            if 'foreign_key' in col_spec:
                fk_ref = col_spec['foreign_key']
                columns.append(
                    f"FOREIGN KEY ({col_name}) REFERENCES {fk_ref}"
                )
        
        script = f"""-- Create table {table_name}
CREATE TABLE IF NOT EXISTS {table_name} (
    {',\n    '.join(columns)}
);

-- Create indexes
"""
        
        # Add indexes
        for index_col in schema.get('indexes', []):
            script += f"CREATE INDEX IF NOT EXISTS idx_{table_name}_{index_col} ON {table_name}({index_col});\n"
        
        return script
    
    def _generate_add_column_script(self, table_name: str, column_name: str) -> Optional[str]:
        """Generate ALTER TABLE ADD COLUMN script"""
        if table_name not in self.DOCUMENTED_SCHEMA:
            return None
        
        schema = self.DOCUMENTED_SCHEMA[table_name]
        if column_name not in schema['columns']:
            return None
        
        col_spec = schema['columns'][column_name]
        
        script = f"ALTER TABLE {table_name} ADD COLUMN IF NOT EXISTS {column_name} {col_spec['type']}"
        
        if not col_spec.get('nullable', True):
            script += " NOT NULL"
        
        if 'default' in col_spec:
            default = col_spec['default']
            if isinstance(default, str):
                script += f" DEFAULT '{default}'"
            elif isinstance(default, bool):
                script += f" DEFAULT {str(default).upper()}"
            else:
                script += f" DEFAULT {default}"
        
        script += ";"
        
        return script
    
    def _sanitize_db_url(self) -> str:
        """Sanitize database URL for reporting"""
        # Remove password from URL
        import re
        return re.sub(r'://[^:]+:[^@]+@', '://***:***@', self.database_url)
    
    def _print_summary(self, report: SchemaAuditReport):
        """Print audit summary"""
        print("\n" + "=" * 60)
        print("📊 SCHEMA AUDIT SUMMARY")
        print("=" * 60)
        
        summary = report.compliance_summary
        
        print(f"\nCompliance Score: {summary['compliance_score']:.1f}%")
        print(f"Total Tables: {summary['total_tables']}")
        print(f"  ✅ Compliant: {summary['compliant']}")
        print(f"  ⚠️ Minor Deviations: {summary['minor_deviations']}")
        print(f"  ❌ Major Deviations: {summary['major_deviations']}")
        print(f"  🔴 Missing: {summary['missing']}")
        print(f"  📝 Undocumented: {summary['undocumented']}")
        
        if report.recommendations:
            print("\n📋 Recommendations:")
            for i, rec in enumerate(report.recommendations[:5], 1):
                print(f"  {i}. {rec}")
        
        if report.migration_scripts:
            print(f"\n🔧 Generated {len(report.migration_scripts)} migration scripts")
    
    def _save_report(self, report: SchemaAuditReport):
        """Save audit report to file"""
        filename = f"schema_audit_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        
        report_dict = {
            "timestamp": report.timestamp.isoformat(),
            "database_url": report.database_url,
            "compliance_summary": report.compliance_summary,
            "tables": [
                {
                    "table_name": t.table_name,
                    "exists": t.exists,
                    "documented": t.documented,
                    "compliance": t.compliance.value,
                    "missing_columns": t.missing_columns,
                    "extra_columns": t.extra_columns,
                    "column_count": len(t.columns),
                    "index_count": len(t.indexes),
                    "foreign_key_count": len(t.foreign_keys)
                }
                for t in report.tables
            ],
            "recommendations": report.recommendations,
            "migration_scripts": report.migration_scripts
        }
        
        with open(filename, 'w') as f:
            json.dump(report_dict, f, indent=2)
        
        print(f"\n📄 Full report saved to: {filename}")
        
        # Also save migration scripts if any
        if report.migration_scripts:
            migration_file = f"migrations_{datetime.now().strftime('%Y%m%d_%H%M%S')}.sql"
            with open(migration_file, 'w') as f:
                f.write("-- Auto-generated migration scripts\n")
                f.write("-- Review before applying to production\n\n")
                f.write("\n\n".join(report.migration_scripts))
            print(f"📝 Migration scripts saved to: {migration_file}")
    
    def _generate_connection_error_report(self) -> SchemaAuditReport:
        """Generate report when database connection fails"""
        return SchemaAuditReport(
            timestamp=datetime.utcnow(),
            database_url=self._sanitize_db_url(),
            tables=[],
            compliance_summary={
                "total_tables": 0,
                "compliant": 0,
                "minor_deviations": 0,
                "major_deviations": 0,
                "missing": 0,
                "undocumented": 0,
                "compliance_score": 0,
                "error": "Failed to connect to database"
            },
            recommendations=[
                "Ensure PostgreSQL is running",
                "Verify DATABASE_URL environment variable",
                "Check network connectivity to database server",
                "Verify database credentials"
            ],
            migration_scripts=[]
        )


async def main():
    """Run the schema auditor"""
    auditor = SchemaAuditor()
    report = await auditor.run_audit()
    
    # Exit with appropriate code
    if report.compliance_summary.get('compliance_score', 0) < 80:
        print("\n⚠️ SCHEMA AUDIT COMPLETED WITH ISSUES")
        exit(1)
    else:
        print("\n✅ SCHEMA AUDIT COMPLETED SUCCESSFULLY")
        exit(0)


if __name__ == "__main__":
    asyncio.run(main())