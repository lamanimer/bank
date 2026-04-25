import base64
import json
import os
from openai import OpenAI


def extract_receipt_data_from_image_bytes(image_bytes: bytes, mime_type: str = "image/jpeg") -> dict:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not set in .env")

    client = OpenAI(api_key=api_key)

    base64_image = base64.b64encode(image_bytes).decode("utf-8")
    image_url = f"data:{mime_type};base64,{base64_image}"

    prompt = """
You are extracting transaction data from a shopping receipt image.

Return ONLY valid JSON with this exact structure:
{
  "amount": number | null,
  "txn_date": "YYYY-MM-DD" | null,
  "category_name": string | null,
  "note": string | null,
  "merchant": string | null,
  "txn_type": "EXPENSE"
}

Rules:
- txn_type must always be "EXPENSE"
- amount = final total paid on the receipt
- txn_date = purchase date in YYYY-MM-DD format if visible
- merchant = store/business name
- note = short readable description like "Carrefour purchase"
- category_name must be one of:
  "Groceries", "Food & Drink", "Transport", "Shopping",
  "Bills", "Health", "Entertainment", "Education", "Other"
- If unsure, use "Other"
- If a field cannot be found, return null for that field
- Do not include markdown
- Do not include explanation text
"""

    response = client.chat.completions.create(
        model="gpt-4.1-mini",
        response_format={"type": "json_object"},
        messages=[
            {
                "role": "system",
                "content": "You extract structured transaction data from receipt images."
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": image_url
                        }
                    },
                ],
            },
        ],
    )

    content = response.choices[0].message.content
    data = json.loads(content)

    if "txn_type" not in data or not data["txn_type"]:
        data["txn_type"] = "EXPENSE"

    return data