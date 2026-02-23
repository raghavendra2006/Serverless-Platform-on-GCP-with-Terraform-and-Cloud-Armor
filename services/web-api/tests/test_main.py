"""
Unit tests for the Web API service.
"""

import os
import json
from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient


# Set environment variables before importing main
os.environ["ENVIRONMENT"] = "test"
os.environ["DB_HOST"] = "localhost"
os.environ["DB_NAME"] = "test_db"
os.environ["DB_USER"] = "test_user"
os.environ["DB_PASSWORD"] = "test_password"


class TestHealthEndpoint:
    """Tests for the /health endpoint."""

    def test_health_returns_200(self):
        """Health check should always return 200."""
        from main import app
        client = TestClient(app)
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "web-api"
        assert "timestamp" in data

    def test_health_includes_db_status(self):
        """Health check should include database status."""
        from main import app
        client = TestClient(app)
        response = client.get("/health")
        data = response.json()
        assert "database" in data
        assert data["database"] in ["connected", "disconnected"]


class TestItemsEndpoint:
    """Tests for the /items endpoint."""

    def test_items_returns_list(self):
        """GET /items should return a JSON array."""
        from main import app, SessionLocal

        # Mock database session
        if SessionLocal is None:
            pytest.skip("Database not available in test environment")

        client = TestClient(app)
        response = client.get("/items")
        assert response.status_code in [200, 503]

        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)

    def test_items_returns_503_without_db(self):
        """GET /items should return 503 when DB is unavailable."""
        from main import app
        import main
        original = main.SessionLocal
        main.SessionLocal = None

        client = TestClient(app)
        response = client.get("/items")
        assert response.status_code == 503

        main.SessionLocal = original


class TestStructuredLogging:
    """Tests for structured logging output."""

    def test_log_format_is_json(self, capsys):
        """Log output should be valid JSON."""
        from main import logger
        logger.info("Test log message")
        captured = capsys.readouterr()
        # Should be parseable JSON
        for line in captured.out.strip().split("\n"):
            if line:
                data = json.loads(line)
                assert "severity" in data
                assert "message" in data
                assert "service_context" in data
                assert data["service_context"]["service"] == "web-api"
