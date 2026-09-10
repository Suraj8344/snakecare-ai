from datetime import UTC, datetime, timedelta

import pytest
from test_auth import auth_client, exchange


@pytest.mark.asyncio
async def test_hospital_approval_assignment_private_gps_and_end_trip():
    async with auth_client() as client:
        admin = await exchange(client, "admin-token-with-valid-length")
        manager = await exchange(client, "manager-token-with-valid-length")
        driver = await exchange(client, "driver-token-with-valid-length")
        patient = await exchange(client, "patient-token-with-valid-length")
        stranger = await exchange(client, "stranger-token-with-valid-length")

        def headers(account):
            return {"Authorization": f"Bearer {account['access_token']}"}

        result = await client.patch(
            f"/api/v1/auth/users/{manager['user']['id']}/role",
            headers=headers(admin),
            json={"role": "hospital_admin", "hospital_employee_id": "TEST-HOSP-123"},
        )
        assert result.status_code == 200, result.text
        manager = await exchange(client, "manager-token-with-valid-length")
        now = datetime.now(UTC).isoformat()
        response = await client.post(
            "/api/v1/hospital-coordination/facilities",
            headers=headers(manager),
            json={
                "name": "Test hospital",
                "address": "Synthetic street 123",
                "city": "Pune",
                "latitude": 18.5,
                "longitude": 73.8,
                "data_source": "hospital_reported",
                "source_updated_at": now,
                "capabilities": {"data_source": "hospital_reported", "verified_at": now},
            },
        )
        assert response.status_code == 201, response.text
        hospital_id = response.json()["id"]
        base = "/api/v1/ambulance-tracking"
        response = await client.post(
            f"{base}/drivers",
            headers=headers(driver),
            json={
                "hospital_id": hospital_id,
                "driver_name": "Synthetic Driver",
                "vehicle_number": "TEST123",
                "verification_reference": "EMP-123",
            },
        )
        assert response.status_code == 201, response.text
        driver_id = response.json()["id"]
        assert response.json()["status"] == "pending"
        assert (
            await client.post(
                f"{base}/drivers/{driver_id}/review",
                headers=headers(driver),
                json={"status": "approved"},
            )
        ).status_code == 403
        response = await client.post(
            f"{base}/trips",
            headers=headers(patient),
            json={
                "hospital_id": hospital_id,
                "latitude": 18.5,
                "longitude": 73.8,
                "share_pickup_consent": True,
            },
        )
        assert response.status_code == 201, response.text
        trip = response.json()["id"]
        assign = f"{base}/trips/{trip}/assign"
        assert (
            await client.post(assign, headers=headers(manager), json={"driver_id": driver_id})
        ).status_code == 409
        assert (
            await client.post(
                f"{base}/drivers/{driver_id}/review",
                headers=headers(manager),
                json={"status": "approved"},
            )
        ).status_code == 200
        assert (
            await client.post(assign, headers=headers(patient), json={"driver_id": driver_id})
        ).status_code == 403
        assert (
            await client.post(assign, headers=headers(manager), json={"driver_id": driver_id})
        ).status_code == 200
        assert (await client.get(f"{base}/workspace", headers=headers(stranger))).json()[
            "trips"
        ] == []
        payload = {"latitude": 18.51, "longitude": 73.81, "accuracy_m": 10, "captured_at": now}
        location = f"{base}/trips/{trip}/location"
        assert (
            await client.post(location, headers=headers(patient), json=payload)
        ).status_code == 403
        assert (
            await client.post(location, headers=headers(driver), json=payload)
        ).status_code == 409
        status = f"{base}/trips/{trip}/status"
        assert (
            await client.post(status, headers=headers(driver), json={"status": "completed"})
        ).status_code == 409
        assert (
            await client.post(status, headers=headers(driver), json={"status": "en_route"})
        ).status_code == 200
        old = {**payload, "captured_at": (datetime.now(UTC) - timedelta(minutes=5)).isoformat()}
        assert (await client.post(location, headers=headers(driver), json=old)).status_code == 422
        assert (
            await client.post(location, headers=headers(driver), json=payload)
        ).status_code == 200
        seen = (await client.get(f"{base}/workspace", headers=headers(patient))).json()["trips"][0]
        assert seen["latitude"] == 18.51 and seen["location_stale"] is False
        assert (
            await client.post(status, headers=headers(driver), json={"status": "onboard"})
        ).status_code == 200
        assert (
            await client.post(status, headers=headers(driver), json={"status": "completed"})
        ).status_code == 200
        assert (
            await client.post(location, headers=headers(driver), json=payload)
        ).status_code == 409
        seen = (await client.get(f"{base}/workspace", headers=headers(patient))).json()["trips"][0]
        assert seen["latitude"] is None and seen["pickup_latitude"] is None
        assert (
            await client.post(
                f"{base}/drivers/{driver_id}/review",
                headers=headers(manager),
                json={"status": "revoked"},
            )
        ).status_code == 200
