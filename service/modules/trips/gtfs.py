from apscheduler.util import ZoneInfo
import gtfs_kit as gk
import pandas as pd
from datetime import date, datetime, time, timedelta


class Gtfs:
    default_path = "assets/GTFS_TCL.ZIP"

    def __init__(self, path: str | None = None):
        self.file_path = path
        self.feed = gk.read_feed(
            self.file_path if self.file_path else Gtfs.default_path,
            dist_units="km",
        )

        self.stop_time_cache: dict[date, pd.DataFrame] = {}
        fields = self.feed.list_fields()
        all_tz_string = fields.loc[fields["column"] == "agency_timezone"]
        if len(all_tz_string) > 1:
            raise RuntimeError(
                "Too many agencies TZ to choose from, don't know what to do. Make me smarter !"
            )

        tz_string = fields.loc[
            fields["column"] == "agency_timezone", "max_value"
        ].iloc[0]
        self.tz = ZoneInfo(tz_string)
        now = datetime.now(self.tz)

        # Our use-case for trips is to get estimates for the next passage of a given line.
        # Naturally, we are interested in today's passages ...
        # It is useful to cache that in RAM.
        # Trams and buses run from about 4 am to 2 am next day
        # The feed actually has 26 hour days instead of 24,
        # therefore if we are very early in the morning it is more relevant to see data from yesterday
        self.date = (
            (now - timedelta(days=1)).date()
            if now.hour < 4
            else now.today().date()
        )

        self.stop_time_cache[self.date] = self.feed.get_stop_times(
            self.date.strftime("%Y%m%d")
        )
        self.trips = self.feed.get_trips()
        self.routes = self.feed.get_routes()
        self.stops = self.feed.get_stops()

    def on_same_transit_line(
        self, stop_a: int | str, stop_b: int | str
    ) -> bool:
        stop_a = str(stop_a)
        stop_b = str(stop_b)

        stop_times = self._get_stop_times()

        df_stop_a = stop_times.loc[(stop_times["stop_id"] == stop_a)]
        df_stop_b = stop_times.loc[(stop_times["stop_id"] == stop_b)]

        # To read: Is there a shared trip ID ?
        return df_stop_b["trip_id"].isin(df_stop_a["trip_id"].unique()).any()

    def get_stop_info(self, stop_id: int | str) -> tuple[str, str, str, str]:
        """
        Get information about a stop including its name, route long name, trip headsign, and route short name.

        Args:
            stop_id: The ID of the stop to look up

        Returns:
            tuple: (stop_name, route_long_name, trip_headsign, route_short_name)

        Raises:
            ValueError: If the stop ID is not found in the stops data
        """
        stop_id = str(stop_id)

        stop_times = self._get_stop_times()
        stop_to_trip = pd.merge(
            stop_times[["stop_id", "trip_id"]],
            self.trips[["trip_id", "route_id", "trip_headsign"]],
            on="trip_id",
        )
        stop_to_route = pd.merge(
            stop_to_trip,
            self.routes[["route_id", "route_long_name", "route_short_name"]],
            on="route_id",
        )
        stop_routes = stop_to_route[
            stop_to_route["stop_id"] == stop_id
        ].drop_duplicates(["route_id"])
        if self.stops[self.stops["stop_id"] == stop_id].empty:
            raise ValueError(f"Stop ID {stop_id} not found in stops data")

        stop_name = self.stops[self.stops["stop_id"] == stop_id][
            "stop_name"
        ].iloc[0]
        result = []
        for _, row in stop_routes.iterrows():
            result.append(
                (
                    stop_name,
                    row["route_long_name"],
                    row["trip_headsign"],
                    row["route_short_name"],
                )
            )
        # Assume simple stops belonging to a single line
        return result[0]

    def parse_gtfs_time(self, date: date, time_str: str) -> datetime:
        """
        Parse GTFS time format (which can exceed 24h) into a datetime object.
        """
        time_parts = time_str.split(":")
        hours = int(time_parts[0])
        minutes = int(time_parts[1])
        seconds = int(time_parts[2]) if len(time_parts) > 2 else 0

        days_to_add = hours // 24
        hours_normalized = hours % 24

        return datetime.combine(
            date, time(hours_normalized, minutes, seconds), tzinfo=self.tz
        ) + timedelta(days=days_to_add)

    def _get_stop_times(self, date: date | None = None) -> pd.DataFrame:
        """
        Return the cached stop times for date.
        If date is None, return any stop times which is useful when you just need a random one

        Side effects: wipe the cache when we reach 50 elems. If it grows infinitely one day we will run out of RAM...
        """

        if not date:
            return list(self.stop_time_cache.values())[0]

        if len(self.stop_time_cache) == 50:
            self.stop_time_cache.clear()

        stop_times = self.feed.get_stop_times(date.strftime("%Y%m%d"))

        self.stop_time_cache[self.date] = stop_times

        return stop_times

    def _next_stop_times_at_stop(
        self,
        *,
        stop_id: str | int,
        column_name: str,
        trip_id: str | None = None,
        count: int = -1,
        local_timestamp: datetime,
    ) -> list[tuple[str, datetime]]:
        stop_id = str(stop_id)
        if column_name not in ["departure_time", "arrival_time"]:
            raise ValueError(
                "Column name must be one of departure_time or arrival_time"
            )

        stop_times = self._get_stop_times(local_timestamp.date())

        df = stop_times.loc[(stop_times["stop_id"] == stop_id)]
        if trip_id:
            df = df.loc[df["trip_id"] == trip_id]
        df = df.loc[
            df[column_name] > local_timestamp.time().strftime("%H:%M:%S")
        ]
        sorted_df = df.sort_values(by=[column_name])
        list_of_tuples = [
            (
                next_stop["trip_id"],
                self.parse_gtfs_time(
                    local_timestamp.date(), next_stop[column_name]
                ),
            )
            for _, next_stop in sorted_df.iterrows()
        ]
        if count > -1:
            return list_of_tuples[:count]
        return list_of_tuples

    def next_departures_at_stop(
        self,
        stop_id: str | int,
        *,
        trip_id: str | None = None,
        count: int = -1,
        local_timestamp: datetime,
    ) -> list[tuple[str, datetime]]:
        """
        Return the count next departures at transport station stop_id, happening after timestamp.
        If trip_id is specified, filter such that only departures on trip trip_id are returned.

        Times are in the timezone local to the GTFS file.

        Returns list of tuples:
            - trip_id
            - departure datetime
        """
        return self._next_stop_times_at_stop(
            stop_id=stop_id,
            column_name="departure_time",
            trip_id=trip_id,
            count=count,
            local_timestamp=local_timestamp,
        )

    def next_arrivals_at_stop(
        self,
        stop_id: str | int,
        *,
        trip_id: str | None = None,
        count: int = -1,
        local_timestamp: datetime,
    ) -> list[tuple[str, datetime]]:
        """
        Return the count next arrivals at transport station stop_id, happening after timestamp.
        If trip_id is specified, filter such that only arrivals on trip trip_id are returned.

        Returns list of tuples:
            - trip_id
            - arrival datetime
        """
        return self._next_stop_times_at_stop(
            stop_id=stop_id,
            column_name="arrival_time",
            trip_id=trip_id,
            count=count,
            local_timestamp=local_timestamp,
        )
