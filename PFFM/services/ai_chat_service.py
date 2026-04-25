import os
from typing import Any, Dict, List
from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


def _summarize_categories(transactions: List[Dict[str, Any]]):
    categories = {}

    for t in transactions:
        try:
            amount = float(t.get("amount", 0))
        except Exception:
            amount = 0.0

        if amount >= 0:
            continue

        category = str(t.get("category") or t.get("ai_category") or "Other")
        categories[category] = categories.get(category, 0.0) + abs(amount)

    sorted_categories = sorted(
        categories.items(),
        key=lambda x: x[1],
        reverse=True,
    )
    return sorted_categories[:5]


def _recent_transactions(transactions: List[Dict[str, Any]]):
    return transactions[:5]


def generate_finance_reply(
    user_id: str,
    question: str,
    transactions: List[Dict[str, Any]],
    goals: List[Dict[str, Any]],
    totals: Dict[str, Any],
) -> str:
    balance = totals.get("balance", 0)
    income = totals.get("income", 0)
    expenses = totals.get("expenses", 0)

    top_categories = _summarize_categories(transactions)
    recent_tx = _recent_transactions(transactions)

    categories_text = "\n".join(
        [f"- {name}: {amount:.2f} AED" for name, amount in top_categories]
    ) or "- No category data"

    recent_tx_text = "\n".join(
        [
            f"- {t.get('description', 'Transaction')} | {t.get('amount', 0)} AED | {t.get('date', '')}"
            for t in recent_tx
        ]
    ) or "- No recent transactions"

    goals_text = "\n".join(
        [
            f"- {g.get('name', 'Goal')} | target: {g.get('targetAmount', 0)} | saved: {g.get('savedAmount', 0)}"
            for g in goals
        ]
    ) or "- No goals found"

    user_context = f"""
User account data:
- Balance: {balance} AED
- Income: {income} AED
- Expenses: {expenses} AED

Top spending categories:
{categories_text}

Recent transactions:
{recent_tx_text}

Goals:
{goals_text}
"""

    system_prompt = """
You are Pocket Assistant, a smart personal finance assistant inside a finance app.
Use the user's real account data only.
Be practical, concise, and helpful.
Keep answers easy to understand.
When possible, mention spending patterns, goals, and next actions.
"""

    user_prompt = f"""
{user_context}

User question:
{question}
"""

    response = client.chat.completions.create(
        model="gpt-4.1-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
    )

    return response.choices[0].message.content or "No response."