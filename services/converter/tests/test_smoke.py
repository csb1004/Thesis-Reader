from fastapi.testclient import TestClient

from services.converter.app.main import app


def test_pytest_is_configured():
    assert 1 + 1 == 2


def test_health_reports_latex_renderer_availability():
    response = TestClient(app).get("/health")

    assert response.status_code == 200
    assert response.json()["status"] == "ok"
    assert isinstance(response.json()["pdflatexAvailable"], bool)
