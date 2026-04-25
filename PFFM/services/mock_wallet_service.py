from __future__ import annotations
from services.categorization_service import categorize_transaction

"""
Mock wallet + transaction generator for demo mode.

Goal:
- Show 2 connected banks in Flutter (MockBank One / MockBank Two)
- Generate -25 transactions per bank (different per bank)
- Compute balance/income/expense from those transactions
- UAE-safe (AED currency, Dubai address, fictional banks)
"""

import hashlib
import random
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional


SALARY_DESCRIPTIONS = [
    "Salary",
    "Freelance Payment",
    "Refund",
]
BANK_ONE_MERCHANTS = [
    ("Carrefour", "Groceries"),
    ("Lulu Hypermarket", "Groceries"),
    ("Union Coop", "Groceries"),
    ("Talabat", "Food & Delivery"),
    ("Deliveroo", "Food & Delivery"),
    ("KFC", "Dining"),
    ("McDonald's", "Dining"),
    ("Costa Coffee", "Dining"),
    ("Starbucks", "Dining"),
    ("RTA", "Transport"),
    ("Careem", "Transport"),
    ("Uber", "Transport"),
    ("DEWA", "Utilities"),
    ("Etisalat", "Telecom"),
    ("Amazon", "Shopping"),
    ("Noon", "Shopping"),
    ("Zara", "Shopping"),
    ("H&M", "Shopping"),
    ("Vox Cinemas", "Entertainment"),
    ("Netflix", "Entertainment"),
]

BANK_TWO_MERCHANTS = [
    ("Spinneys", "Groceries"),
    ("Waitrose", "Groceries"),
    ("Choithrams", "Groceries"),
    ("Noon", "Shopping"),
    ("Namshi", "Shopping"),
    ("Amazon", "Shopping"),
    ("Apple Store", "Shopping"),
    ("Dubai Mall", "Shopping"),
    ("Careem", "Transport"),
    ("Uber", "Transport"),
    ("Emirates", "Travel"),
    ("Air Arabia", "Travel"),
    ("Booking.com", "Travel"),
    ("Etisalat", "Telecom"),
    ("du", "Telecom"),
    ("DEWA", "Utilities"),
    ("Deliveroo", "Food & Delivery"),
    ("Talabat", "Food & Delivery"),
    ("Shake Shack", "Dining"),
    ("Five Guys", "Dining"),
    ("Shein", "Shopping"),
]


def _seed_from_customer(customer_id: str) -> int:
    h = hashlib.sha256(customer_id.encode("utf-8")).hexdigest()
    return int(h[:8], 16)


def _rand_tx(
    *,
    rng: random.Random,
    bank_id: str,
    bank_name: str,
    account_id: str,
    i: int,
    start: datetime,
) -> Dict[str, Any]:
    if i < 6:
        tx_date = start + timedelta(days=i * 30 + rng.randint(0, 5))
    else:
        tx_date = start + timedelta(days=rng.randint(0, 365))

    is_credit = i < 6

    if is_credit:
        desc = rng.choice(SALARY_DESCRIPTIONS)
        amount = round(rng.uniform(1500, 5200), 2)
    else:
        merchant_pool = (
            BANK_ONE_MERCHANTS
            if "one" in bank_name.lower()
            else BANK_TWO_MERCHANTS
        )
        merchant, _old_category = rng.choice(merchant_pool)
        desc = merchant
        amount = -round(rng.uniform(15, 420), 2)

    ai_category = "Income"
    category_id = None
    ai_confidence = 1.0
    categorization_source = "system"

    if amount < 0:
        cat = categorize_transaction(desc)
        ai_category = cat.get("category_name", "Other")
        category_id = cat.get("category_id")
        ai_confidence = float(cat.get("confidence", 0.0))
        categorization_source = cat.get("source", "ai")

    return {
        "id": f"{bank_id}tx{i}",
        "bank_id": bank_id,
        "bank_name": bank_name,
        "account_id": account_id,
        "timestamp": tx_date.isoformat(),
        "date": tx_date.strftime("%Y-%m-%d"),
        "description": desc,
        "amount": amount,
        "currency": "AED",
        "ai_category": ai_category,
        "category": ai_category,
        "category_id": category_id,
        "ai_confidence": ai_confidence,
        "categorization_source": categorization_source,
    }
def build_connected_wallet_payload(
    customer_id: str,
    *,
    connected_banks: Optional[List[Dict[str, Any]]] = None,
    tx_per_bank: int = 25,
) -> Dict[str, Any]:
    now = datetime.utcnow()
    seed = _seed_from_customer(customer_id)

    banks = connected_banks or [
        {"id": "mockbank1", "name": "MockBank One", "connected_at": now.isoformat()},
        {"id": "mockbank2", "name": "MockBank Two", "connected_at": now.isoformat()},
    ]

    accounts: List[Dict[str, Any]] = []
    transactions: List[Dict[str, Any]] = []

    start_date = now - timedelta(days=365)

    for idx, bank in enumerate(banks):
        bank_id = str(bank["id"])
        bank_name = str(bank["name"])
        account_id = f"{bank_id}_acc_1"

        # bank-specific RNG so each bank has different transactions
        rng = random.Random(seed + (idx + 1) * 100_000)

        txs_bank = [
            _rand_tx(
                rng=rng,
                bank_id=bank_id,
                bank_name=bank_name,
                account_id=account_id,
                i=i,
                start=start_date,
            )
            for i in range(tx_per_bank)
        ]
        transactions.extend(txs_bank)

        bal = 5000.0 + sum(float(t["amount"]) for t in txs_bank)

        accounts.append(
            {
                "account_id": account_id,
                "bank_id": bank_id,
                "bank_name": bank_name,
                "currency": "AED",
                "balance": round(bal, 2),
                "type": "CURRENT",
                "last4": str((seed + idx + 17) % 10_000).zfill(4),
            }
        )

    income = sum(float(t["amount"]) for t in transactions if float(t["amount"]) > 0)
    expenses = -sum(float(t["amount"]) for t in transactions if float(t["amount"]) < 0)
    total_balance = sum(float(a["balance"]) for a in accounts)

    summary = {
        "currency": "AED",
        "balance": round(total_balance, 2),
        "income_month": round(income, 2),
        "expenses_month": round(expenses, 2),
        "is_user_override": False,
    }

    identity = {
        "name": "Demo User",
        "address": "Dubai, UAE",
    }

    transactions.sort(key=lambda t: t.get("timestamp", ""), reverse=True)

    return {
        "customer_id": customer_id,
        "connected": True,
        "banks": banks,
        "accounts": accounts,
        "transactions": transactions,
        "identity": identity,
        "summary": summary,
    }