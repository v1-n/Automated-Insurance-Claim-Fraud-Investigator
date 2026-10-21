import argparse
import asyncio
import json
import os
import sys
import httpx


async def run_photo_test(base_url: str, photo_url: str, api_key: str | None):
    endpoint = f"{base_url.rstrip('/')}/inspect-photo"

    payload = {
        "tenant_id": "TATA_AIG",
        "claim_id": 101,
        "photo_id": 72,
        "photo_url": photo_url,
        "incident_context": {
            "incident_date": "2026-10-19T12:00:00",
            "incident_city": "Bengaluru",
            "incident_state": "Karnataka",
            "incident_latitude": 12.9716,
            "incident_longitude": 77.5946,
        },
        "existing_hashes": [],
    }

    headers = {}
    if api_key:
        headers["X-Internal-Key"] = api_key

    print(f"🚀 Sending photo inspection request to: {endpoint}...")

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(endpoint, json=payload, headers=headers, timeout=30.0)
            print(f"\n📊 Status Code: {response.status_code}")
            print("📝 Response Body:")
            print(json.dumps(response.json(), indent=2))
        except httpx.ConnectError:
            print(f"\n❌ Connection Error: Could not connect to {base_url}.")
            print("💡 Ensure your Uvicorn server is running: uvicorn app.main:app --reload")
            sys.exit(1)
        except Exception as e:
            print(f"\n❌ Unexpected error: {e}")
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Test photo inspection endpoint with custom parameters.")
    parser.add_argument(
        "--url",
        default=os.getenv(
            "TEST_PHOTO_URL",
            "https://res.cloudinary.com/aafdcxyl/image/upload/v1792504507/insurance-fraud/TATA_AIG/TATA_AIG-2026-00001/e0uikapke5vylm54af1v.jpg",
        ),
        help="Photo URL to inspect",
    )
    parser.add_argument(
        "--base-url",
        default=os.getenv("AI_SERVICE_BASE_URL", "http://127.0.0.1:8000"),
        help="Base URL of FraudGuard AI service",
    )
    parser.add_argument(
        "--key",
        default=os.getenv("AI_INTERNAL_KEY"),
        help="Internal secret key (X-Internal-Key header)",
    )
    args = parser.parse_args()

    asyncio.run(run_photo_test(args.base_url, args.url, args.key))


if __name__ == "__main__":
    main()
