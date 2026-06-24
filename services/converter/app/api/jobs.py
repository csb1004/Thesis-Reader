from io import BytesIO
from zipfile import ZIP_DEFLATED, ZipFile

from fastapi import APIRouter, HTTPException, Response, UploadFile

from services.converter.app.jobs.job_store import job_store
from services.converter.app.jobs.models import JobSnapshot, JobStatus

router = APIRouter()

MAX_UPLOAD_BYTES = 50 * 1024 * 1024
UPLOAD_CHUNK_BYTES = 1024 * 1024


@router.post("/jobs", response_model=JobSnapshot, status_code=201)
async def create_job(file: UploadFile) -> JobSnapshot:
    if file.content_type != "application/pdf":
        raise HTTPException(status_code=415, detail="Only PDF uploads are supported")

    job_id, source_path = job_store.reserve()
    total_bytes = 0

    try:
        with source_path.open("wb") as output:
            while chunk := await file.read(UPLOAD_CHUNK_BYTES):
                total_bytes += len(chunk)
                if total_bytes > MAX_UPLOAD_BYTES:
                    raise HTTPException(status_code=413, detail="Upload exceeds maximum size")
                output.write(chunk)
    except Exception:
        job_store.discard(job_id)
        raise

    return job_store.commit(job_id)


@router.get("/jobs/{job_id}", response_model=JobSnapshot)
def get_job(job_id: str) -> JobSnapshot:
    return job_store.convert(job_id)


@router.get("/jobs/{job_id}/download")
def download_job(job_id: str) -> Response:
    snapshot = job_store.get_or_404(job_id)
    if snapshot.status not in {JobStatus.succeeded, JobStatus.failed}:
        snapshot = job_store.convert(job_id)
    if snapshot.status != JobStatus.succeeded:
        raise HTTPException(status_code=409, detail="Job package is not available")

    package_dir = job_store.package_dir(job_id)
    package_path = package_dir / "package.json"
    assets_dir = package_dir / "assets"
    if not package_path.exists() or not assets_dir.exists():
        raise HTTPException(status_code=409, detail="Job package is not available")

    archive_bytes = BytesIO()
    with ZipFile(archive_bytes, "w", ZIP_DEFLATED) as archive:
        archive.write(package_path, "package.json")
        archive.writestr("assets/", "")
        for asset_path in assets_dir.rglob("*"):
            if asset_path.is_file():
                archive.write(asset_path, asset_path.relative_to(package_dir).as_posix())

    return Response(
        content=archive_bytes.getvalue(),
        media_type="application/zip",
        headers={"Content-Disposition": f'attachment; filename="{job_id}.zip"'},
    )
