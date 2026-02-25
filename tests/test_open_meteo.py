"""Unit tests for the weather extraction module."""

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest
import requests

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "extract"))

from open_meteo import CITIES, fetch_weather


def _api_response(date="2025-01-15"):
    """Build a realistic Open-Meteo API response."""
    return {
        "daily": {
            "time": [date],
            "temperature_2m_max": [8.2],
            "temperature_2m_min": [3.1],
            "precipitation_sum": [4.5],
            "wind_speed_10m_max": [22.7],
        }
    }


class TestFetchWeather:
    def test_returns_record_for_valid_response(self):
        city = CITIES[0]
        with patch("open_meteo.requests.get") as mock_get:
            mock_get.return_value = MagicMock(
                json=MagicMock(return_value=_api_response("2025-06-01")),
                raise_for_status=MagicMock(),
            )
            result = fetch_weather(city, "2025-06-01")

        assert result is not None
        assert result["city"] == "London"
        assert result["date"] == "2025-06-01"
        assert result["temperature_max"] == 8.2
        assert result["temperature_min"] == 3.1
        assert result["precipitation"] == 4.5
        assert result["wind_speed_max"] == 22.7

    def test_returns_none_when_api_returns_no_data(self):
        city = CITIES[0]
        with patch("open_meteo.requests.get") as mock_get:
            mock_get.return_value = MagicMock(
                json=MagicMock(return_value={"daily": {"time": []}}),
                raise_for_status=MagicMock(),
            )
            result = fetch_weather(city, "2025-06-01")

        assert result is None

    def test_includes_city_coordinates(self):
        city = {"city": "TestCity", "latitude": 52.0, "longitude": -1.5}
        with patch("open_meteo.requests.get") as mock_get:
            mock_get.return_value = MagicMock(
                json=MagicMock(return_value=_api_response()),
                raise_for_status=MagicMock(),
            )
            result = fetch_weather(city, "2025-01-15")

        assert result["latitude"] == 52.0
        assert result["longitude"] == -1.5

    def test_passes_correct_params_to_api(self):
        city = CITIES[2]  # Birmingham
        with patch("open_meteo.requests.get") as mock_get:
            mock_get.return_value = MagicMock(
                json=MagicMock(return_value=_api_response()),
                raise_for_status=MagicMock(),
            )
            fetch_weather(city, "2025-03-10")

        mock_get.assert_called_once()
        params = mock_get.call_args.kwargs["params"]
        assert params["latitude"] == city["latitude"]
        assert params["longitude"] == city["longitude"]
        assert params["start_date"] == "2025-03-10"
        assert params["end_date"] == "2025-03-10"

    def test_raises_on_http_error(self):
        city = CITIES[0]
        with patch("open_meteo.requests.get") as mock_get:
            mock_resp = MagicMock()
            mock_resp.raise_for_status.side_effect = requests.HTTPError("500 Server Error")
            mock_get.return_value = mock_resp

            with pytest.raises(requests.HTTPError):
                fetch_weather(city, "2025-01-15")


class TestCities:
    def test_has_ten_cities(self):
        assert len(CITIES) == 10

    def test_each_city_has_required_fields(self):
        for city in CITIES:
            assert "city" in city
            assert "latitude" in city
            assert "longitude" in city
