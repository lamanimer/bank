import os
from typing import Any, Dict, List, Optional

import httpx

from services.mock_wallet_service import build_connected_wallet_payload


class LeanError(Exception):
    pass


def _get_env(name: str, default: Optional[str] = None) -> Optional[str]:
    value = os.getenv(name, default)
    return value.strip() if isinstance(value, str) else value


def _use_mock_wallet() -> bool:
    return _get_env("USE_MOCK_WALLET", "1") != "0"


def _lean_auth_base_url() -> str:
    return _get_env("LEAN_AUTH_BASE_URL", "https://auth.sandbox.leantech.me") or "https://auth.sandbox.leantech.me"


def _lean_api_base_url() -> str:
    return _get_env("LEAN_API_BASE_URL", "https://sandbox.leantech.me") or "https://sandbox.leantech.me"


def _lean_data_base_url() -> str:
    return _get_env("LEAN_DATA_BASE_URL", "https://sandbox.leantech.me") or "https://sandbox.leantech.me"


def _lean_client_id() -> str:
    value = _get_env("LEAN_CLIENT_ID")
    if not value:
        raise LeanError("Missing LEAN_CLIENT_ID or LEAN_CLIENT_SECRET in .env")
    return value


def _lean_client_secret() -> str:
    value = _get_env("LEAN_CLIENT_SECRET")
    if not value:
        raise LeanError("Missing LEAN_CLIENT_ID or LEAN_CLIENT_SECRET in .env")
    return value


def _lean_app_token() -> str:
    value = _get_env("LEAN_APP_TOKEN")
    if not value:
        raise LeanError("Missing LEAN_APP_TOKEN in .env")
    return value


def _lean_redirect_url() -> str:
    return _get_env("LEAN_REDIRECT_URL", "http://localhost:5173/lean-callback") or "http://localhost:5173/lean-callback"


async def get_access_token() -> dict:
    url = f"{_lean_auth_base_url()}/oauth2/token"
    data = {
        "grant_type": "client_credentials",
        "scope": "api",
        "client_id": _lean_client_id(),
        "client_secret": _lean_client_secret(),
    }

    async with httpx.AsyncClient(timeout=25) as client:
        r = await client.post(
            url,
            data=data,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

    if r.status_code != 200:
        raise LeanError(f"Lean token error {r.status_code}: {r.text}")

    return r.json()


async def create_customer(app_user_id: str) -> dict:
    if _use_mock_wallet():
        return {
            "status": "CUSTOMER_CREATED",
            "customer_id": f"mock-customer-{app_user_id}",
        }

    token_data = await get_access_token()
    access_token = token_data["access_token"]

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    url_create = f"{_lean_api_base_url()}/customers/v1"
    payload = {"app_user_id": app_user_id}

    async with httpx.AsyncClient(timeout=25) as client:
        r = await client.post(url_create, json=payload, headers=headers)

    if r.status_code == 409:
        url_get = f"{_lean_api_base_url()}/customers/v1/app-user-id/{app_user_id}"
        async with httpx.AsyncClient(timeout=25) as client:
            r2 = await client.get(url_get, headers=headers)

        if r2.status_code != 200:
            raise LeanError(
                f"Customer exists but lookup failed {r2.status_code}: {r2.text}"
            )

        existing = r2.json()
        customer_id = existing.get("customer_id") or (existing.get("customer") or {}).get("customer_id")
        if not customer_id:
            raise LeanError(f"Customer exists but no customer_id in lookup response: {existing}")

        return {"status": "CUSTOMER_ALREADY_EXISTS", "customer_id": customer_id}

    if r.status_code not in (200, 201):
        raise LeanError(f"Customer creation failed {r.status_code}: {r.text}")

    created = r.json()
    customer_id = created.get("customer_id") or (created.get("customer") or {}).get("customer_id")
    if not customer_id:
        raise LeanError(f"Create succeeded but no customer_id returned: {created}")

    return {"status": "CUSTOMER_CREATED", "customer_id": customer_id}


async def get_customer_token(customer_id: str) -> dict:
    if _use_mock_wallet():
        return {
            "access_token": "mock-customer-access-token",
            "token_type": "Bearer",
            "expires_in": 3600,
            "customer_id": customer_id,
        }

    url = f"{_lean_auth_base_url()}/oauth2/token"
    data = {
        "grant_type": "client_credentials",
        "scope": f"customer.{customer_id}",
        "client_id": _lean_client_id(),
        "client_secret": _lean_client_secret(),
        "audience": "https://sandbox.leantech.me",
    }

    async with httpx.AsyncClient(timeout=25) as client:
        r = await client.post(
            url,
            data=data,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )

    if r.status_code != 200:
        raise LeanError(f"Customer token failed {r.status_code}: {r.text}")

    return r.json()


async def create_link_session(customer_id: str) -> dict:
    if _use_mock_wallet():
        return {
            "status": "LINK_SESSION_CREATED",
            "customer_id": customer_id,
            "link_url": "http://localhost:3000/mock-lean-link",
            "mock": True,
        }

    token_data = await get_access_token()
    access_token = token_data["access_token"]

    url = f"{_lean_api_base_url()}/connect/v1/customers/{customer_id}/link"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }
    data = {"redirect_url": _lean_redirect_url()}

    async with httpx.AsyncClient(timeout=25) as client:
        r = await client.post(url, json=data, headers=headers)

    if r.status_code != 200:
        raise LeanError(f"Link session failed {r.status_code}: {r.text}")

    return r.json()


async def get_link_config(customer_id: str) -> dict:
    if _use_mock_wallet():
        return {
            "customer_id": customer_id,
            "access_token": "mock-access-token",
            "token_type": "Bearer",
            "expires_in": 3600,
            "app_token": "mock-app-token",
            "sandbox": True,
            "mock": True,
        }

    customer_token = await get_customer_token(customer_id)
    app_token = _lean_app_token()

    return {
        "customer_id": customer_id,
        "access_token": customer_token["access_token"],
        "token_type": customer_token.get("token_type", "Bearer"),
        "expires_in": customer_token.get("expires_in"),
        "app_token": app_token,
        "sandbox": True,
    }


async def get_entities_for_customer(customer_id: str) -> List[Dict[str, Any]]:
    if _use_mock_wallet():
        return [
            {
                "entity_id": f"mock-entity-{customer_id}",
                "bank_name": "Mock National Bank",
                "created_at": "2026-03-25T00:00:00Z",
                "updated_at": "2026-03-25T00:00:00Z",
            }
        ]

    token_data = await get_access_token()
    access_token = token_data["access_token"]

    url = f"{_lean_api_base_url()}/customers/v1/{customer_id}/entities"
    headers = {"Authorization": f"Bearer {access_token}"}

    async with httpx.AsyncClient(timeout=25, trust_env=False) as client:
        r = await client.get(url, headers=headers)

    if r.status_code != 200:
        raise LeanError(f"Get entities failed {r.status_code}: {r.text}")

    data = r.json()
    if isinstance(data, dict) and "entities" in data:
        return data["entities"] or []
    if isinstance(data, list):
        return data
    return []


def _pick_latest_entity(entities: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not entities:
        return None

    def key_fn(e: Dict[str, Any]) -> str:
        return str(e.get("updated_at") or e.get("created_at") or "")

    return sorted(entities, key=key_fn, reverse=True)[0]


def _data_headers(customer_token: str, entity_id: str) -> Dict[str, str]:
    if _use_mock_wallet():
        return {
            "Authorization": f"Bearer {customer_token}",
            "x-lean-app-token": "mock-app-token",
            "x-lean-entity-id": entity_id,
            "accept": "application/json",
        }

    app_token = _lean_app_token()
    return {
        "Authorization": f"Bearer {customer_token}",
        "x-lean-app-token": app_token,
        "x-lean-entity-id": entity_id,
        "accept": "application/json",
    }


async def get_accounts(entity_id: str):
    if _use_mock_wallet():
        payload = build_connected_wallet_payload(entity_id, tx_per_bank=10)
        return payload.get("accounts", payload)

    token_data = await get_access_token()
    api_token = token_data["access_token"]

    url = f"{_lean_data_base_url()}/data/v2/accounts"
    headers = {
        "Authorization": f"Bearer {api_token}",
        "accept": "application/json",
    }
    params = {"entity_id": entity_id}

    async with httpx.AsyncClient(timeout=25, trust_env=False) as client:
        r = await client.get(url, headers=headers, params=params)

    if r.status_code != 200:
        raise LeanError(f"Get accounts failed {r.status_code}: {r.text}")

    return r.json()


async def get_balance(customer_token: str, entity_id: str, account_id: str) -> List[Dict[str, Any]]:
    if _use_mock_wallet():
        return [
            {
                "account_id": account_id,
                "available_balance": 8420.55,
                "current_balance": 8420.55,
                "currency": "AED",
            }
        ]

    url = f"{_lean_data_base_url()}/data/v2/accounts/{account_id}/balances"
    headers = _data_headers(customer_token, entity_id)

    async with httpx.AsyncClient(timeout=25, trust_env=False) as client:
        r = await client.get(url, headers=headers)

    if r.status_code != 200:
        raise LeanError(f"Get balances failed {r.status_code}: {r.text}")

    data = r.json()
    return data.get("balances", data) if isinstance(data, dict) else data


async def get_transactions(customer_token: str, entity_id: str, account_id: str) -> List[Dict[str, Any]]:
    if _use_mock_wallet():
        payload = build_connected_wallet_payload(account_id, tx_per_bank=25)
        return payload.get("transactions", [])

    url = f"{_lean_data_base_url()}/data/v2/accounts/{account_id}/transactions"
    headers = _data_headers(customer_token, entity_id)

    async with httpx.AsyncClient(timeout=25, trust_env=False) as client:
        r = await client.get(url, headers=headers)

    if r.status_code != 200:
        raise LeanError(f"Get transactions failed {r.status_code}: {r.text}")

    data = r.json()
    return data.get("transactions", data) if isinstance(data, dict) else data


async def get_identity(customer_token: str, entity_id: str, account_id: str) -> Dict[str, Any]:
    if _use_mock_wallet():
        return {
            "account_id": account_id,
            "full_name": "Lama Hasan",
            "bank_name": "Mock National Bank",
            "iban": "AE070331234567890123456",
        }

    url = f"{_lean_data_base_url()}/data/v2/accounts/{account_id}/identity"
    headers = _data_headers(customer_token, entity_id)

    async with httpx.AsyncClient(timeout=25, trust_env=False) as client:
        r = await client.get(url, headers=headers)

    if r.status_code != 200:
        raise LeanError(f"Get identity failed {r.status_code}: {r.text}")

    return r.json()


async def fetch_all_bank_data(customer_id: str) -> Dict[str, Any]:
    """
    Demo mode (default): returns fake banks + transactions locally.
    Real Lean mode: set USE_MOCK_WALLET=0 in your .env
    """
    if _use_mock_wallet():
        return build_connected_wallet_payload(customer_id, tx_per_bank=25)

    # Real Lean flow can be added later.
    return build_connected_wallet_payload(customer_id, tx_per_bank=25)