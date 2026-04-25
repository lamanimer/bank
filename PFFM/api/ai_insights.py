import traceback
from typing import Optional
from fastapi import APIRouter, HTTPException, Query
from services.ai_insight_service import generate_ai_spending_insight

router = APIRouter(prefix="/ai", tags=["AI Insights"])


@router.get("/spending-insight")
async def api_spending_insight(
    customer_id: str = Query(...),
    bank_id: Optional[str] = Query(None),
):
    try:
        return await generate_ai_spending_insight(customer_id, bank_id)
    except Exception as e:
        print("AI spending insight route error:", str(e))
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))