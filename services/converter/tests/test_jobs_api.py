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

def test_get_job_returns_created_job_snapshot():
    create_response = client.post(
        '/jobs',
        files={'file': ('paper.pdf', b'%PDF-1.4\n%test\n', 'application/pdf')},
    )
    created = create_response.json()

    response = client.get(f"/jobs/{created['jobId']}")

    assert response.status_code == 200
    body = response.json()
    assert body['jobId'] == created['jobId']
    assert body['status'] == created['status']

def test_rejects_non_pdf_upload():
    response = client.post(
        '/jobs',
        files={'file': ('paper.txt', b'not a pdf', 'text/plain')},
    )
    assert response.status_code == 415

def test_rejects_oversized_pdf_upload(monkeypatch):
    from services.converter.app.api import jobs

    monkeypatch.setattr(jobs, 'MAX_UPLOAD_BYTES', 4)
    data_dir = jobs.job_store._data_dir
    before_job_dirs = set(data_dir.iterdir()) if data_dir.exists() else set()

    response = client.post(
        '/jobs',
        files={'file': ('paper.pdf', b'%PDF-1', 'application/pdf')},
    )

    assert response.status_code == 413
    after_job_dirs = set(data_dir.iterdir()) if data_dir.exists() else set()
    assert after_job_dirs == before_job_dirs
