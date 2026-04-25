from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from api.users import router as users_router
from api.transactions import router as transactions_router

load_dotenv()

app = FastAPI(title="PFFM API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users_router)
app.include_router(transactions_router)

@app.get("/")
def root():
    return {"ok": True, "message": "PFFM API is running. Open /docs"}