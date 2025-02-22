from dataclasses import dataclass
from datetime import datetime
import re

from grand_lyon_data.sytral.base_stryal_api import SytralAPI


@dataclass
class Incident:
    type: str
    cause: str
    debut: str
    fin: str
    mode: str
    ligne_com: str
    ligne_cli: str
    titre: str
    message: str
    last_update_fme: datetime
    n: str
    typeseverite: str
    niveauseverite: str
    typeobjet: str
    listeobjet: str

    @classmethod
    def from_dict(cls, data: dict):
        return Incident(
            type=data["type"],
            cause=data["cause"],
            debut=data["debut"],
            fin=data["fin"],
            mode=data["mode"],
            ligne_com=data["ligne_com"],
            ligne_cli=data["ligne_cli"],
            titre=data["titre"],
            message=data["message"],
            last_update_fme=datetime.fromisoformat(data["last_update_fme"]),
            n=data["n"],
            typeseverite=data["typeseverite"],
            niveauseverite=data["niveauseverite"],
            typeobjet=data["typeobjet"],
            listeobjet=data["listeobjet"],
        )


class GrandLyonIncidentApi(SytralAPI):
    route = "tcl_sytral.tclalertetrafic_2/all.json"
    filename = "alertes-trafic-reseau-transports-commun-lyonnais-v2"

    _instance: "GrandLyonIncidentApi | None" = None

    def __init__(self, **kwargs):
        if GrandLyonIncidentApi._instance:
            raise RuntimeError(
                "GrandLyonNextPassageApi is already instantiated, cannot instantiate a new one"
            )

        super().__init__(
            route=GrandLyonIncidentApi.route,
            filename=GrandLyonIncidentApi.filename,
            **kwargs,
        )

        GrandLyonIncidentApi._instance = self

    @classmethod
    def get_instance(cls):
        return cls._instance

    def get(
        self, *, line_ref: str | re.Pattern[str], force_refetch: bool = False
    ) -> list[Incident]:
        """
        Returns incident info for specified line.
        Uses built-in cache by default.

        If this is your first call or if you need to refresh info either:
        - pass force_refetch=True
        - call refresh_cache before calling get
        """

        if force_refetch:
            self.refresh_cache()

        return [
            Incident.from_dict(entry)
            for entry in self.cache.get_entry("line_com", line_ref)
        ]
