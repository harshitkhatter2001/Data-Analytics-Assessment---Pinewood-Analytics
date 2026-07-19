from fastapi import Security, HTTPException, status
from fastapi.security.api_key import APIKeyHeader

api_key_header = APIKeyHeader(
    name="X-API-Key",
    scheme_name="API Key Authentication",
    auto_error=False
)

API_KEYS = {
    "corp-admin-key": {
        "role": "corporate_admin"
    },
"region-pnw-key": {
    "role": "regional_director",
    "region": "Pacific Northwest"
},

    "community-c001-key": {
        "role": "executive_director",
        "community_id": "C001"
    }
}


def get_current_user(api_key: str = Security(api_key_header)):

    if api_key is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing API Key"
        )

    user = API_KEYS.get(api_key)

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API Key"
        )

    return user