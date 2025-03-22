from datetime import datetime, timedelta

from modules.trips.gtfs import Gtfs
from grand_lyon_data.grand_lyon_api import GrandLyonApi
from grand_lyon_data.sytral.incident_api import GrandLyonIncidentApi
from grand_lyon_data.sytral.next_passage_api import (
    GrandLyonNextPassageApi,
)


class SingleLeg:
    def __init__(
        self,
        *,
        from_stop: int,
        to_stop: int,
        id: int,
        gtfs: Gtfs | None = None,
        transport_incident_api: GrandLyonIncidentApi | None = None,
        delay_api: GrandLyonNextPassageApi | None = None,
    ):
        self.gtfs = gtfs if gtfs is not None else Gtfs()
        self.delay_api = (
            delay_api if delay_api else GrandLyonApi.tcl_delay_api()
        )
        self.incident_api = (
            transport_incident_api
            if transport_incident_api
            else GrandLyonApi.tcl_incident_api()
        )

        if not self.gtfs.on_same_transit_line(from_stop, to_stop):
            raise ValueError(
                f"Station {from_stop} and Station {to_stop} are on different transit lines"
            )

        from_stop_name, line_long_name, trip_direction, line_short_name = (
            self.gtfs.get_stop_info(from_stop)
        )
        to_stop_name, _, _, _ = self.gtfs.get_stop_info(to_stop)

        self.id = id
        self.from_stop = from_stop
        self.to_stop = to_stop
        self.from_stop_name = from_stop_name
        self.to_stop_name = to_stop_name
        self.line_name = line_long_name
        self.trip_direction = trip_direction
        self.line_short_name = line_short_name

    def to_dict(self):
        return {
            "id": self.id,
            "from_stop": self.from_stop,
            "to_stop": self.to_stop,
            "from_stop_name": self.from_stop_name,
            "to_stop_name": self.to_stop_name,
            "line_name": self.line_name,
            "trip_direction": self.trip_direction,
            "line_short_name": self.line_short_name,
        }

    def get_estimates(
        self,
        utc_timestamp: datetime | None = None,
        count: int = 3,
    ) -> list[tuple[str, datetime, datetime]]:
        """
        Returns list of tuple:
            - trip ID
            - datetime of departure from origin (using local TZ of the GTFS file)
            - datetime of corresponding arrival at destination (using local TZ of the GTFS file)
        """

        utc_timestamp = utc_timestamp if utc_timestamp else datetime.now()
        local_timestamp = utc_timestamp.astimezone(self.gtfs.tz)

        next_departures_from_origin = self.gtfs.next_departures_at_stop(
            self.from_stop,
            count=count,
            local_timestamp=local_timestamp,
        )

        if len(next_departures_from_origin) == 0:
            # No results possibly means we have no more trips today
            # Let's return tomorrow's first trips instead
            next_departures_from_origin = self.gtfs.next_departures_at_stop(
                self.from_stop,
                count=count,
                local_timestamp=(local_timestamp + timedelta(days=1)).replace(
                    hour=0, minute=0, second=0
                ),
            )

        estimates = []
        for trip_id, departure_time in next_departures_from_origin:
            _, arrival_time = self.gtfs.next_arrivals_at_stop(
                self.to_stop,
                trip_id=trip_id,
                count=1,
                local_timestamp=departure_time,
            )[0]

            estimates.append((trip_id, departure_time, arrival_time))

        return estimates

    def get_delays(self, trip_id: str, force_refetch: bool = False):
        # short line can be something like C8
        # While cannonical commercial name can be C8A
        delays = self.delay_api.get(
            trip_id=trip_id,
            force_refetch=force_refetch,
        )

        if len(delays) > 1:
            raise ValueError(
                f"More than one delay found for trip {trip_id}: {delays}. How is that possible ?"
            )

        return delays[0] if delays else None

    def get_incidents(self):
        return self.incident_api.get(line_ref=self.line_short_name)
