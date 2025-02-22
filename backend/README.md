# Backend service

Simple FastAPI server

## Running the server

```
uv run start-server
```

## Trips API
All timestamps returned are ISO strings with timezone info.
When you send a timestamp to the software, use UTC. Internally everything is configured to adapt to the GTFS file's local timezone.

### Return next passage of a given leg
```
curl localhost:8000/api/trips/{leg_id}/next
```

### Return the first <count> passages occuring after <timestamp>
```
curl localhost:8000/api/trips/{leg_id}/{timestamp}/{count}
```

Example on fish shell:
`curl -u username:password localhost:8000/trips/1/(date +%s)/2`

### Registering legs

Legs you want to track are stored in a CSV file.
In order to be properly parsed this CSV file needs to have the following format:
- `id,from_stop_id,to_stop_id`
- explicit header line must be present in order to auto import all rows as dicts
Pass the path to this file as `LEGS_FILE` env variable. (via .env if you so wish)

Multi leg trips are not supported yet.
Additionally, trying to register a leg with stops that are not directly connected by a transport line will raise an exception.

## Dev

### Install pre-commit hooks

Mandatory to make sure you don't leak secrets...
```
pre-commit install
```

### Architecture

- Isolated domains in modules
- Public shared codes in well named folders at the root

## Infra

Plan to be hosting on a VPS.
Deploy code to the VPS via GitHub Actions.

Note: make sure to make your calls over HTTPS

### Setup the VPS

1. `cp backend/infra/inventory.tpl backend/infra/inventory.ini`
2. From the infra directory: `ansible-playbook -i inventory.ini setup-vps.yml`
3. Run `ssh-keyscan -H your-server-domain-or-ip` and save output as a secret: `SSH_KNOWN_HOSTS`
6. SSH into your VPS and copy the private key that was created by the playbook: `cat /home/deployer/.ssh/github_actions` and set it up as a GH secret: `SSH_PRIVATE_KEY`
