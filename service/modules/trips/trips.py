import os
import csv
from datetime import datetime, timezone
from modules.trips.leg import SingleLeg
from fastapi import APIRouter

trips_router = APIRouter()


class Trips:
    _instance: "Trips | None" = None

    def __init__(self, file_path: str = "assets/single_leg_trips.csv"):
        if Trips._instance is not None:
            raise RuntimeError("Trips singleton is already initialised")

        legs_file = os.getenv("LEGS_FILE", file_path)

        # CSV format must be as follows:
        #     id,from_stop_id,to_stop_id
        #     1,2,3
        with open(legs_file, "r") as file:
            csv_reader = csv.DictReader(file)
            self.tracked_legs = [
                SingleLeg(
                    id=int(row["id"]),
                    from_stop=int(row["from_stop_id"]),
                    to_stop=int(row["to_stop_id"]),
                )
                for row in csv_reader
            ]
        Trips._instance = self

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            raise RuntimeError("Trips singleton is not initialised")

        return cls._instance


@trips_router.get("/")
async def list_legs():
    return {
        "legs": [leg.to_dict() for leg in Trips.get_instance().tracked_legs]
    }


@trips_router.post("/force_refresh")
async def force_refresh():
    instance = Trips.get_instance()
    if len(instance.tracked_legs) < 1:
        raise RuntimeError("No legs currently tracked...")

    line = instance.tracked_legs[0]
    line.delay_api.refresh_cache()
    line.incident_api.refresh_cache()

    return {"updated_at": line.delay_api.cache_refreshed_at}


@trips_router.get("/{leg_id}")
async def get_legs(leg_id: int):
    return next(
        (
            leg.to_dict()
            for leg in Trips.get_instance().tracked_legs
            if leg.id == leg_id
        ),
        None,
    )


@trips_router.get("/{leg_id}/next")
async def get_next(leg_id: int):
    leg = next(
        (leg for leg in Trips.get_instance().tracked_legs if leg.id == leg_id),
        None,
    )

    if leg is None:
        return None

    estimates = []

    incidents = leg.get_incidents()
    for trip_id, departure_time, arrival_time in leg.get_estimates():
        delay = leg.get_delays(trip_id)

        delay_seconds = (
            int(delay.delaipassage.total_seconds()) if delay else None
        )

        estimates.append(
            {
                "transporter_trip_id": trip_id,
                "departure_time": departure_time,
                "arrival_time": arrival_time,
                "delay": delay_seconds,
            }
        )

    return {
        "leg": leg.to_dict(),
        "estimates": estimates,
        "incidents": [
            {
                "title": incident.titre,
                "message": incident.message,
                "type": incident.typeseverite,
                "severity": incident.niveauseverite,
            }
            for incident in incidents
        ],
        "sot_updated_at": leg.delay_api.cache_refreshed_at,
    }


@trips_router.get("/{leg_id}/{utc_time_string}/{count}")
async def get(leg_id: int, utc_time_string: str, count: int):
    leg = next(
        (leg for leg in Trips.get_instance().tracked_legs if leg.id == leg_id),
        None,
    )

    if leg is None:
        return None

    utc_timestamp = datetime.fromtimestamp(
        float(utc_time_string), tz=timezone.utc
    )

    estimates = [
        {
            "transporter_trip_id": trip_id,
            "departure_time": departure_time,
            "arrival_time": arrival_time,
        }
        for trip_id, departure_time, arrival_time in leg.get_estimates(
            utc_timestamp=utc_timestamp,
            count=count,
        )
    ]

    return {
        "leg": leg.to_dict(),
        "estimates": estimates,
        "sot_updated_at": leg.delay_api.cache_refreshed_at,
    }
