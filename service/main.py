import os
import threading

from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
import uvicorn
import secrets
from grand_lyon_data.grand_lyon_api import GrandLyonApi
from modules.trips.trips import trips_router, Trips
from dotenv import load_dotenv

load_dotenv()

security = HTTPBasic()
USERNAME = os.environ.get("AUTH_USERNAME", "dashboard")
PASSWORD = os.environ.get("AUTH_PASSWORD", "raspberry")


def verify_credentials(credentials: HTTPBasicCredentials = Depends(security)):
    is_username_correct = secrets.compare_digest(credentials.username, USERNAME)
    is_password_correct = secrets.compare_digest(credentials.password, PASSWORD)

    if not (is_username_correct and is_password_correct):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username


scheduler = BackgroundScheduler()


def refresh_tcl_api_cache():
    print("Refreshing TCL API caches...")
    GrandLyonApi.tcl_delay_api().refresh_cache()
    GrandLyonApi.tcl_incident_api().refresh_cache()
    print("Done refreshing caches !")


@asynccontextmanager
async def lifespan(app: FastAPI):
    Trips()  # init singleton
    scheduler.add_job(
        refresh_tcl_api_cache,
        CronTrigger.from_crontab("0 * * * *"),  # every hour
    )
    scheduler.start()

    # Don't want to block server startup while we initialise cache
    thread = threading.Thread(target=refresh_tcl_api_cache)
    thread.daemon = True
    thread.start()

    yield
    scheduler.shutdown()


app = FastAPI(lifespan=lifespan)

app.include_router(
    trips_router,
    prefix="/trips",
    tags=["trips"],
    dependencies=[Depends(verify_credentials)],
)


@app.get("/", dependencies=[Depends(verify_credentials)])
def read_root():
    return {"Hello": "World", "status": "ok"}


def start_server():
    uvicorn.run(app, host="0.0.0.0", port=8000, root_path="/api")


if __name__ == "__main__":
    start_server()
