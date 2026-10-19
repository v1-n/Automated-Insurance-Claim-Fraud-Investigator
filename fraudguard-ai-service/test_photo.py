import asyncio
import json
import httpx


async def run_photo_test():
    base_url = "http://127.0.0.1:8000"
    endpoint = f"{base_url}/inspect-photo"

    payload = {
        "tenant_id": "TATA_AIG",
        "claim_id": 101,
        "photo_id": 72,
        "photo_url": "https://res.cloudinary.com/aafdcxyl/image/upload/v1792243937/Screenshot_from_2026-10-17_19-01-38_bpmjva.png",
        "incident_context": {
            "incident_date": "2026-10-19T12:00:00",
            "incident_city": "Bengaluru",
            "incident_state": "Karnataka"
        }
    }

    print(f"🚀 Sending photo inspection request to: {endpoint}...")

    async with httpx.AsyncClient() as client:
        try:
            response = await client.post(endpoint, json=payload, timeout=30.0)
            print(f"\n📊 Status Code: {response.status_code}")
            print("📝 Response Body:")
            print(json.dumps(response.json(), indent=2))
        except httpx.ConnectError:
            print(f"\n❌ Connection Error: Could not connect to {base_url}.")
            print("💡 Ensure your Uvicorn server is running: uvicorn app.main:app --reload")
        except Exception as e:
            print(f"\n❌ Unexpected error: {e}")


if __name__ == "__main__":
    asyncio.run(run_photo_test())
