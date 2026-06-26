import json
from io import BytesIO
from zipfile import ZipFile

from fastapi.testclient import TestClient

from services.converter.app.main import app
from services.converter.tests.fixtures import write_simple_paper_pdf

client = TestClient(app)

def test_health_returns_ok():
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json()['status'] == 'ok'
    assert isinstance(response.json()['pdflatexAvailable'], bool)

def test_create_job_accepts_pdf_upload():
    response = client.post(
        '/jobs',
        files={'file': ('paper.pdf', b'%PDF-1.4\n%test\n', 'application/pdf')},
    )
    assert response.status_code == 201
    body = response.json()
    assert body['jobId']
    assert body['status'] in {'queued', 'processing'}

def test_create_job_accepts_pdf_filename_with_generic_content_type():
    response = client.post(
        '/jobs',
        files={'file': ('paper.pdf', b'%PDF-1.4\n%test\n', 'application/octet-stream')},
    )
    assert response.status_code == 201

def test_get_job_runs_conversion_for_uploaded_pdf(tmp_path):
    pdf_path = write_simple_paper_pdf(tmp_path / 'paper.pdf')
    create_response = client.post(
        '/jobs',
        files={'file': ('paper.pdf', pdf_path.read_bytes(), 'application/pdf')},
    )
    created = create_response.json()

    response = client.get(f"/jobs/{created['jobId']}")

    assert response.status_code == 200
    body = response.json()
    assert body['jobId'] == created['jobId']
    assert body['status'] == 'succeeded'

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

def test_download_returns_package_zip_after_conversion():
    create = client.post('/jobs', files={'file': ('paper.pdf', b'%PDF-1.4\n%test\n', 'application/pdf')})
    job_id = create.json()['jobId']
    status = client.get(f'/jobs/{job_id}')
    assert status.status_code == 200
    download = client.get(f'/jobs/{job_id}/download')
    assert download.status_code in {200, 409}

def test_download_returns_valid_package_zip_after_fixture_conversion(tmp_path):
    pdf_path = write_simple_paper_pdf(tmp_path / 'paper.pdf')
    create = client.post(
        '/jobs',
        files={'file': ('paper.pdf', pdf_path.read_bytes(), 'application/pdf')},
    )
    job_id = create.json()['jobId']

    status = client.get(f'/jobs/{job_id}')
    download = client.get(f'/jobs/{job_id}/download')

    assert status.status_code == 200
    assert status.json()['status'] == 'succeeded'
    assert download.status_code == 200
    with ZipFile(BytesIO(download.content)) as archive:
        names = archive.namelist()
        assert 'package.json' in names
        assert 'assets/' in archive.namelist() or any(
            name.startswith('assets/') for name in names
        )
        package = json.loads(archive.read('package.json'))
        assert package['assets']
        for asset in package['assets']:
            assert asset['relativePath'] in names
