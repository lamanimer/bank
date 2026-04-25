import os
import firebase_admin
from firebase_admin import credentials, firestore

_db = None

def get_db():
    global _db
    if _db is not None:
        print("DEBUG: returning cached db")
        return _db

    key_path = os.environ.get("FIREBASE_KEY_PATH")
    print("DEBUG: key_path =", key_path)

    if not key_path:
        raise RuntimeError("FIREBASE_KEY_PATH is not set")

    if not os.path.exists(key_path):
        raise RuntimeError(f"Firebase key file not found: {key_path}")

    print("DEBUG: before Certificate")
    cred = credentials.Certificate(key_path)
    print("DEBUG: after Certificate")

    if not firebase_admin._apps:
        print("DEBUG: before initialize_app")
        firebase_admin.initialize_app(cred)
        print("DEBUG: after initialize_app")

    print("DEBUG: before firestore.client()")
    _db = firestore.client()
    print("DEBUG: after firestore.client()")

    return _db