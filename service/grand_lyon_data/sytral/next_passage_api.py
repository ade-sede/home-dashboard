from datetime import datetime, timedelta
from dataclasses import dataclass
import re

from grand_lyon_data.sytral.base_stryal_api import SytralAPI


@dataclass(frozen=True, eq=True)
class NextPassageLine:
    id: int
    type: str

    ligne: str
    coursetheorique: str

    # Have been spotted to be None for some reason...
    direction: str | None
    idtarretdestination: int | None

    last_update_fme: datetime

    # str formats that have been spotted so far:
    # - "Proche"
    # - "2 min"
    # - "06h03"
    delaipassage: timedelta
    heurepassage: datetime

    @classmethod
    def parse_delaipassage(cls, delta_str: str) -> timedelta:
        if delta_str == "Proche":
            return timedelta(seconds=0)
        elif delta_str.endswith("min"):
            return timedelta(minutes=int(delta_str[:-4]))
        return timedelta(hours=int(delta_str[:2]), minutes=int(delta_str[3:]))

    @classmethod
    def from_dict(cls, data: dict):
        return NextPassageLine(
            id=int(data["id"]),
            type=data["type"],
            ligne=data["ligne"],
            direction=data["direction"],
            idtarretdestination=int(data["idtarretdestination"])
            if data["idtarretdestination"]
            else None,
            coursetheorique=data["coursetheorique"],
            last_update_fme=datetime.fromisoformat(data["last_update_fme"]),
            heurepassage=datetime.fromisoformat(data["heurepassage"]),
            delaipassage=cls.parse_delaipassage(data["delaipassage"]),
        )


class GrandLyonNextPassageApi(SytralAPI):
    """
    API to access next passage of transports in Lyon.
    It seems a line only shows if there is a known delay, although this is not documented clearly anywhere...

    https://data.grandlyon.com/portail/fr/jeux-de-donnees/prochains-passages-reseau-transports-commun-lyonnais-rhonexpress-disponibilites-temps-reel/donnees
    """

    _instance: "GrandLyonNextPassageApi | None" = None

    route = "tcl_sytral.tclpassagearret/all.json"
    filename = "prochains-passages-reseau-transports-commun-lyonnais-rhonexpress-disponibilites-temps-reel"

    def __init__(
        self,
        **kwargs,
    ):
        if GrandLyonNextPassageApi._instance:
            raise RuntimeError(
                "GrandLyonNextPassageApi is already instantiated, cannot instantiate a new one"
            )

        super().__init__(
            route=GrandLyonNextPassageApi.route,
            filename=GrandLyonNextPassageApi.filename,
            **kwargs,
        )

        GrandLyonNextPassageApi._instance = self

    @classmethod
    def get_instance(cls):
        return cls._instance

    def get(
        self,
        *,
        line_ref: re.Pattern[str] | str | None = None,
        destination: re.Pattern[str] | str | None = None,
        trip_id: str | None = None,
        force_refetch: bool = False,
    ) -> list[NextPassageLine]:
        """
        Returns next passage info for all specified lines.
        Uses built-in cache by default.

        If this is your first call or if you need to refresh info either:
        - pass force_refetch=True
        - call refresh_cache before calling get
        """
        if line_ref is None and destination is None and trip_id is None:
            raise RuntimeError(
                "At least one of line_ref, destination or trip_id must be provided"
            )

        if force_refetch:
            self.refresh_cache()

        if trip_id:
            return [
                NextPassageLine.from_dict(entry)
                for entry in self.cache.get_entry("coursetheorique", trip_id)
            ]

        if line_ref and destination:
            all_by_line_ref = self.cache.get_entry("line_ref", line_ref)
            all_by_destination = self.cache.get_entry("direction", destination)

            return [
                NextPassageLine.from_dict(entry)
                for entry in all_by_line_ref.intersection(all_by_destination)
            ]

        if line_ref:
            return [
                NextPassageLine.from_dict(entry)
                for entry in self.cache.get_entry("line_ref", line_ref)
            ]

        if destination:
            return [
                NextPassageLine.from_dict(entry)
                for entry in self.cache.get_entry("direction", destination)
            ]

        raise RuntimeError("Unreachable")
