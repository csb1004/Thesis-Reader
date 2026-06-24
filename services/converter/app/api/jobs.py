from fastapi import APIRouter, HTTPException, UploadFile

from services.converter.app.jobs.job_store import job_store
from services.converter.app.jobs.models import JobSnapshot

router = APIRouter()


@router.post("/jobs", response_model=JobSnapshot, status_code=201)
async def create_job(file: UploadFile) -> JobSnapshot:
    if file.content_type != "application/pdf":
        raise HTTPException(status_code=415, detail="Only PDF uploads are supported")

    data = await file.read()
    return job_store.create(data)


@router.get("/jobs/{job_id}", response_model=JobSnapshot)
def get_job(job_id: str) -> JobSnapshot:
    return job_store.get_or_404(job_id)
