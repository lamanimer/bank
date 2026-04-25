# repositories/goal_repository.py

from datetime import datetime
from db.firebase import get_db

COL = "goals"


def _col():
    return get_db().collection(COL)


def create_goal(user_id: int, name: str, target_amt: float):
    data = {
        "user_id": int(user_id),
        "name": name,
        "target_amt": float(target_amt),
        "status": "ACTIVE",
        "created_at": datetime.utcnow(),
    }

    doc_ref = _col().document()
    doc_ref.set(data)

    return {
        "goal_id": doc_ref.id,
        **data,
    }


def get_goals_by_user(user_id: int):
    qs = _col().where("user_id", "==", int(user_id))
    return [
        {
            "goal_id": d.id,
            **d.to_dict(),
        }
        for d in qs.stream()
    ]


def get_active_goals_by_user(user_id: int):
    qs = (
        _col()
        .where("user_id", "==", int(user_id))
        .where("status", "==", "ACTIVE")
    )
    return [
        {
            "goal_id": d.id,
            **d.to_dict(),
        }
        for d in qs.stream()
    ]


def update_goal_status(goal_id: str, status: str):
    _col().document(goal_id).update({"status": status})
    return True