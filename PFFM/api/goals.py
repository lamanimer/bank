from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from api.utils import jsonable
from repositories.goal_repository import (
    create_goal,
    get_goals_by_user,
    get_active_goals_by_user,
    update_goal_status,
)

router = APIRouter(prefix="/goals", tags=["Goals"])


class GoalCreate(BaseModel):
    user_id: int
    name: str
    target_amt: float


class GoalStatusUpdate(BaseModel):
    status: str  # "ACTIVE" / "PAUSED" / "COMPLETED" / "CANCELLED"


@router.post("/")
def api_create_goal(body: GoalCreate):
    try:
        g = create_goal(body.user_id, body.name, body.target_amt)
        return jsonable(g)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/user/{user_id}")
def api_get_goals_user(user_id: int):
    return jsonable(get_goals_by_user(user_id))


@router.get("/user/{user_id}/active")
def api_get_active_goals_user(user_id: int):
    return jsonable(get_active_goals_by_user(user_id))


@router.put("/{goal_id}/status")
def api_update_goal_status(goal_id: str, body: GoalStatusUpdate):
    try:
        ok = update_goal_status(goal_id, body.status)
        return {"ok": bool(ok)}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))