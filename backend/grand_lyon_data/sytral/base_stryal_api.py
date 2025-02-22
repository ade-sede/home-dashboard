import base64
from datetime import datetime
import re
import requests


class HashableDict:
    def __init__(self, dictionary):
        self.dict = dictionary
        self._hash = hash(HashableDict.make_dict_hashable(dictionary))

    def __hash__(self):
        return self._hash

    def __eq__(self, other):
        if isinstance(other, HashableDict):
            return self.dict == other.dict
        return False

    @classmethod
    def make_dict_hashable(cls, d):
        """Convert a dictionary to a hashable representation."""
        # Sort items by key and convert to tuple of tuples
        return tuple(
            sorted((k, cls.make_value_hashable(v)) for k, v in d.items())
        )

    @classmethod
    def make_value_hashable(cls, value):
        """Make a value hashable, handling nested dictionaries and lists."""
        if isinstance(value, dict):
            return cls.make_dict_hashable(value)
        elif isinstance(value, list):
            return tuple(cls.make_value_hashable(v) for v in value)
        elif isinstance(value, set):
            return tuple(sorted(cls.make_value_hashable(v) for v in value))
        else:
            return value


class SytralAPICache:
    def __init__(self):
        self.entries = set()

    def add(self, entry: dict):
        self.entries.add(HashableDict(entry))

    def clear(self):
        self.entries = set()

    def get_entry(self, key: str, value: str | re.Pattern[str]) -> set[dict]:
        """
        O(n) search through HashableDict entries
        """
        matches = set()

        for entry in self.entries:
            if key in entry.dict and re.search(value, str(entry.dict[key])):
                matches.add(entry.dict)

        return matches


class SytralAPI:
    def __init__(
        self,
        *,
        maxfeatures: int | None = 1000,
        username: str = "demo",
        password: str = "demo4dev",
        url_base: str,
        route: str,
        filename: str,
    ):
        auth_str = f"{username}:{password}"
        auth_bytes = base64.b64encode(auth_str.encode()).decode()
        self.auth_bytes = auth_bytes

        self.url_base = url_base
        self.route = route
        self.filename = filename
        self.cache = SytralAPICache()

        # Number of entries to query at once
        self.maxfeatures = maxfeatures

        self.cache_refreshed_at: datetime | None = None

    def refresh_cache(self):
        self.cache.clear()

        all_rows = self.get_all()
        for row in all_rows:
            self.cache.add(row)

        self.cache_refreshed_at = datetime.now()

    def query(
        self, start: int, maxfeatures: int | None = None
    ) -> requests.Response:
        maxfeatures = maxfeatures if maxfeatures else self.maxfeatures

        params = {
            "maxfeatures": maxfeatures,
            "start": start,
            "filename": self.filename,
        }

        headers = {"Authorization": f"Basic {self.auth_bytes}"}

        response = requests.get(
            f"{self.url_base}/{self.route}",
            params=params,
            headers=headers,
        )

        return response

    def get_all(self) -> list[dict[str, str]]:
        start = 1
        all: list[dict[str, str]] = []

        while True:
            response = self.query(start)

            if response.status_code != 200:
                raise RuntimeError(
                    f"Data GrandLyon returned {response.status_code}",
                    dict(response=response),
                )

            response = response.json()
            data = response.get("values", [])

            if len(data) == 0:
                break

            for row in data:
                all.append(row)

            start += len(data)

        return all
