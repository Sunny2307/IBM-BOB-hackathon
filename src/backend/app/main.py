import asyncio
import contextlib
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()

from app.services import data_loader, live_simulator
from app.routers import assets, maintenance, copilot


@asynccontextmanager
async def lifespan(app: FastAPI):
    count = data_loader.warm_up()
    print(f"[startup] Loaded {count} assets from generated synthetic data.")

    live_simulator.tick()  # seed last_updated + one immediate nudge
    nudger_task = asyncio.create_task(live_simulator.run_forever())
    try:
        yield
    finally:
        nudger_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await nudger_task


app = FastAPI(
    title="Grid Failure Advisor API",
    description="Predicts outage-prone grid assets from sensor telemetry, weather forecasts, and historical incidents.",
    version="0.1.0",
    lifespan=lifespan,
)

frontend_origin = os.getenv("FRONTEND_ORIGIN", "http://localhost:5173")
allowed_origins = {frontend_origin, "http://localhost:5173", "http://127.0.0.1:5173"}

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(allowed_origins),
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

app.include_router(assets.router)
app.include_router(maintenance.router)
app.include_router(copilot.router)


@app.get("/health")
def health():
    return {"status": "ok", "last_updated": live_simulator.get_last_updated()}
