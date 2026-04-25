from fastapi import APIRouter, HTTPException, Query
from services.lean_service import (
    get_access_token,
    create_customer,
    create_link_session,
    get_customer_token,
    get_link_config,
    fetch_all_bank_data,
    get_entities_for_customer,
    get_accounts,
    get_balance,
    get_transactions,
    LeanError,
)

router = APIRouter(prefix="/lean", tags=["Lean"])


@router.get("/token")
async def api_get_lean_token():
    try:
        return await get_access_token()
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/customer")
async def api_create_customer(app_user_id: str = Query(...)):
    try:
        return await create_customer(app_user_id)
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/customer-token")
async def api_get_customer_token(customer_id: str = Query(...)):
    try:
        return await get_customer_token(customer_id)
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/link-session")
async def api_create_link_session(customer_id: str = Query(...)):
    try:
        return await create_link_session(customer_id)
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/link-config")
async def api_get_link_config(customer_id: str = Query(...)):
    try:
        return await get_link_config(customer_id)
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/data")
async def lean_data(customer_id: str = Query(...)):
    try:
        return await fetch_all_bank_data(customer_id)
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {e}")
    
@router.get("/entities")
async def api_get_entities(customer_id: str = Query(...)):
    try:
        return await get_entities_for_customer(customer_id)
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))
    
@router.get("/accounts")
async def api_accounts(customer_id: str = Query(...), entity_id: str = Query(...)):
    try:
        cust = await get_customer_token(customer_id)
        customer_token = cust["access_token"]

        accounts = await get_accounts(customer_token, entity_id)
        return {"entity_id": entity_id, "accounts": accounts}
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/balance")
async def api_balance(customer_id: str = Query(...), entity_id: str = Query(...), account_id: str = Query(...)):
    try:
        cust = await get_customer_token(customer_id)
        customer_token = cust["access_token"]

        balances = await get_balance(customer_token, entity_id, account_id)
        return {"entity_id": entity_id, "account_id": account_id, "balances": balances}
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/transactions")
async def api_transactions(customer_id: str = Query(...), entity_id: str = Query(...), account_id: str = Query(...)):
    try:
        cust = await get_customer_token(customer_id)
        customer_token = cust["access_token"]

        tx = await get_transactions(customer_token, entity_id, account_id)
        return {"entity_id": entity_id, "account_id": account_id, "transactions": tx}
    except LeanError as e:
        raise HTTPException(status_code=400, detail=str(e))


