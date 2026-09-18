"""Seeds a demo company with an admin and two field crew, and assigns each crew
member some regions — so there is something to sign into.

Idempotent: re-running updates passwords and re-asserts assignments rather than
erroring or duplicating. Safe to run against the live database repeatedly.

Run: python scripts/seed_operators.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dotenv import load_dotenv

load_dotenv()

from app import db  # noqa: E402
from app.services import auth, data_loader  # noqa: E402

COMPANY = "Gujarat Grid Operations"

# Demo passwords, printed on completion. Fine for a hackathon demo account with
# no real data behind it; they are still stored only as scrypt digests.
USERS = [
    {"email": "admin@grid.demo", "full_name": "Priya Desai", "role": "admin", "password": "AdminDemo2026"},
    {"email": "ravi@grid.demo", "full_name": "Ravi Mehta", "role": "field", "password": "FieldDemo2026"},
    {"email": "anita@grid.demo", "full_name": "Anita Shah", "role": "field", "password": "FieldDemo2026"},
]


def main() -> None:
    if not db.init():
        raise SystemExit(f"Database not available: {db.status()}")

    company = db.execute(
        "INSERT INTO companies (name) VALUES (%s) ON CONFLICT (name) DO UPDATE "
        "SET name = EXCLUDED.name RETURNING id",
        (COMPANY,),
    )
    company_id = company["id"]
    print(f"Company: {COMPANY} (id={company_id})")

    user_ids = {}
    for spec in USERS:
        password_hash, password_salt = auth.hash_password(spec["password"])
        row = db.execute(
            """
            INSERT INTO users (company_id, email, full_name, password_hash, password_salt, role)
            VALUES (%s, %s, %s, %s, %s, %s)
            ON CONFLICT (email) DO UPDATE
                SET password_hash = EXCLUDED.password_hash,
                    password_salt = EXCLUDED.password_salt,
                    full_name = EXCLUDED.full_name,
                    role = EXCLUDED.role,
                    is_active = TRUE
            RETURNING id
            """,
            (company_id, spec["email"], spec["full_name"], password_hash, password_salt, spec["role"]),
        )
        user_ids[spec["email"]] = row["id"]
        print(f"  {spec['role']:6} {spec['email']:20} {spec['full_name']}")

    # Split the real regions between the two field users so each has a
    # meaningful, non-overlapping inbox to demo.
    regions = data_loader.get_regions()
    field_emails = [u["email"] for u in USERS if u["role"] == "field"]
    for index, region in enumerate(regions):
        email = field_emails[index % len(field_emails)]
        db.execute(
            """
            INSERT INTO assignments (company_id, user_id, scope_type, scope_value)
            VALUES (%s, %s, 'region', %s)
            ON CONFLICT (user_id, scope_type, scope_value) DO NOTHING
            """,
            (company_id, user_ids[email], region),
        )
        print(f"  assign {region:14} -> {email}")

    print("\nSign in with:")
    for spec in USERS:
        print(f"  {spec['email']:20} / {spec['password']}   ({spec['role']})")

    db.close()


if __name__ == "__main__":
    main()
