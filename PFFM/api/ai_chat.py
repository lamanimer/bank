from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Any, List, Dict, Optional

from services.ai_chat_service import generate_finance_reply

router = APIRouter(prefix="/ai", tags=["AI"])


class AiChatRequest(BaseModel):
    user_id: str
    question: str
    transactions: Optional[List[Dict[str, Any]]] = []
    goals: Optional[List[Dict[str, Any]]] = []
    totals: Optional[Dict[str, Any]] = {}


@router.post("/chat")
def ai_chat(body: AiChatRequest):
    try:
        answer = generate_finance_reply(
            user_id=body.user_id,
            question=body.question,
            transactions=body.transactions or [],
            goals=body.goals or [],
            totals=body.totals or {},
        )
        return {"answer": answer}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))