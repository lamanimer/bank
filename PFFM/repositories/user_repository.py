from db.firebase import get_db

# -------------------------
# Helpers
# -------------------------

def _users_col():
    return get_db().collection("users")


# -------------------------
# Repository functions
# -------------------------

def create_user(user_id: int, name: str, email: str):
    doc_ref = _users_col().document(str(user_id))
    data = {
        "user_id": user_id,
        "name": name,
        "email": email,
    }
    doc_ref.set(data)
    return data


def get_user_by_id(user_id: int):
    doc = _users_col().document(str(user_id)).get()
    if not doc.exists:
        return None
    return doc.to_dict()


def get_all_users():
    """
    Return all users.
    """
    users = []
    for doc in _users_col().stream():
        users.append(doc.to_dict())
    return users


def update_user(user_id: int, name: str = None, email: str = None):
    updates = {}
    if name is not None:
        updates["name"] = name
    if email is not None:
        updates["email"] = email

    if not updates:
        return None

    doc_ref = _users_col().document(str(user_id))
    doc_ref.update(updates)
    return get_user_by_id(user_id)


def delete_user(user_id: int):
    _users_col().document(str(user_id)).delete()
    return True
def get_user_by_email(email: str):
    email = email.lower().strip()

    qs = _users_col().where("email", "==", email).limit(1).stream()
    docs = list(qs)
    if not docs:
        return None

    return docs[0].to_dict()