from fastapi.testclient import TestClient
from services.converter.app.main import app

client = TestClient(app)

def test_health_returns_ok():
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json() == {'status': 'ok'}

def test_create_job_accepts_pdf_upload():
    response = client.post(
        '/jobs',
        files={'file': ('paper.pdf', b'%PDF-1.4\n%test\n', 'application/pdf')},
    )
    assert response.status_code == 201
    body = response.json()
    assert body['jobId']
    assert body['status'] in {'queued', 'processing'}

def test_rejects_non_pdf_upload():
    response = client.post(
        '/jobs',
        files={'file': ('paper.txt', b'not a pdf', 'text/plain')},
    )
    assert response.status_code == 415
