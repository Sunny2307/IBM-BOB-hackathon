import asyncio
import contextlib
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

load_dotenv()

from app import db
from app.services import data_loader, live_simulator, keepalive, weather_live, alert_monitor
from app.routers import assets, maintenance, copilot, auth, operators


@asynccontextmanager
async def lifespan(app: FastAPI):
    count = data_loader.warm_up()
    print(f"[startup] Loaded {count} assets from generated synthetic data.")

    # The operator layer is optional infrastructure: if the database is absent
    # the dashboard, risk engine, copilot and MCP server all still work, and
    # only the operator routes report 503. Never let it block startup.
    print(f"[startup] Database: {'connected' if db.init() else db.status()}")

    live_simulator.tick()  # seed last_updated + one immediate nudge
    tasks = [
        asyncio.create_task(live_simulator.run_forever()),
        asyncio.create_task(keepalive.run_forever()),
        asyncio.create_task(weather_live.refresh_forever()),
        asyncio.create_task(alert_monitor.run_forever()),
    ]
    try:
        yield
    finally:
        for task in tasks:
            task.cancel()
        for task in tasks:
            with contextlib.suppress(asyncio.CancelledError):
                await task
        db.close()


app = FastAPI(
    title="Grid Failure Advisor API",
    description="Predicts outage-prone grid assets from sensor telemetry, weather forecasts, and historical incidents.",
    version="0.1.0",
    lifespan=lifespan,
)

frontend_origins = [
    origin.strip()
    for origin in os.getenv("FRONTEND_ORIGIN", "http://localhost:5173").split(",")
    if origin.strip()
]
allowed_origins = {*frontend_origins, "http://localhost:5173", "http://127.0.0.1:5173"}

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
app.include_router(auth.router)
app.include_router(operators.router)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "last_updated": live_simulator.get_last_updated(),
        "weather_source": data_loader.weather_source(),
        "database": db.status(),
        "alerts_last_checked": alert_monitor.get_last_run(),
    }
