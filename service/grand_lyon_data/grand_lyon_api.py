from grand_lyon_data.sytral.next_passage_api import (
    GrandLyonNextPassageApi,
)
from grand_lyon_data.sytral.incident_api import GrandLyonIncidentApi


class GrandLyonApi:
    """
    API for `GrandLyonData`.

    https://data.grandlyon.com
    """

    base = "https://data.grandlyon.com/fr/datapusher/ws/rdata"

    @classmethod
    def tcl_delay_api(cls, **kwargs):
        instance = GrandLyonNextPassageApi.get_instance()

        if instance:
            return instance

        return GrandLyonNextPassageApi(url_base=GrandLyonApi.base, **kwargs)

    @classmethod
    def tcl_incident_api(cls, **kwargs):
        instance = GrandLyonIncidentApi.get_instance()

        if instance:
            return instance

        return GrandLyonIncidentApi(url_base=GrandLyonApi.base, **kwargs)
