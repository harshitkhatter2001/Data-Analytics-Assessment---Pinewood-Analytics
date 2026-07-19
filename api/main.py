from fastapi import FastAPI
from .routes import router

app = FastAPI(
    title="Pinewood Analytics API",
    version="1.0.0",
    description="Analytics API for Pinewood Senior Living"
)

app.include_router(router)

@app.get("/")
def home():
    return {
        "status": "Running",
        "message": "Pinewood Analytics API"
    }