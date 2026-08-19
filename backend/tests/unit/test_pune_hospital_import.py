from app.operations.import_pune_hospitals import parse_facilities


def test_parses_named_hospital_without_claiming_verified_capabilities() -> None:
    result = parse_facilities(
        {
            "elements": [
                {
                    "type": "node",
                    "id": 42,
                    "lat": 18.52,
                    "lon": 73.85,
                    "tags": {
                        "amenity": "hospital",
                        "name": "Example Pune Hospital",
                        "addr:street": "Health Road",
                        "addr:city": "Pune",
                    },
                },
                {"type": "node", "id": 43, "lat": 18.5, "lon": 73.8, "tags": {}},
            ]
        }
    )
    assert len(result) == 1
    assert result[0].name == "Example Pune Hospital"
    assert result[0].address == "Health Road, Pune"
    assert result[0].source_url.endswith("/node/42")
