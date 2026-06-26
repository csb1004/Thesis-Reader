import shutil

from fastapi import FastAPI

from services.converter.app.api.jobs import router as jobs_router

app = FastAPI(title="Thesis Reader Converter")
app.include_router(jobs_router)


@app.get("/health")
def health() -> dict[str, bool | str]:
    return {
        "status": "ok",
        "pdflatexAvailable": shutil.which("pdflatex") is not None,
    }
