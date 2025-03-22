# Backend service
Simple FastAPI server for the home dashboard project, providing real-time travel information via a clean API.

## Running the server
```
uv run start-server
```

## Trips API
All timestamps returned are ISO strings with timezone info.
When you send a timestamp to the software, use UTC. Internally everything is configured to adapt to the GTFS file's local timezone.

### Return next passage of a given leg
```
curl -u username:password localhost:8000/trips/{leg_id}/next
```

### Return the first <count> passages occuring after <timestamp>
```
curl -u username:password localhost:8000/trips/{leg_id}/{timestamp}/{count}
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
The service is hosted on a VPS with automated deployments via GitHub Actions.

### Infrastructure Overview
The setup consists of two main parts:

1. **Initial VPS Setup (one-time)**: 
   - Uses Ansible playbook to configure the server
   - Creates a dedicated `deployer` user with sudo permissions
   - Sets up SSH keys for secure deployments (generates keys on the server)
   - Installs Nginx as a reverse proxy with HTTPS (Let's Encrypt)
   - Installs UV package manager for Python dependencies
   - Sets up system dependencies and firewall rules

2. **Continuous Deployment (automated)**:
   - Triggered on pushes to main branch or manually
   - Uses SSH keys generated during VPS setup
   - Deploys code, installs dependencies, and manages the service
   - Updates environment variables and configuration files

This separation ensures the VPS is configured properly once, then all subsequent updates are handled automatically through CI.

### Required Secrets for GitHub Actions
Set up the following secrets in your GitHub repository:
- `DEPLOY_HOST`: Domain name of your VPS
- `SSH_PRIVATE_KEY`: Private key for SSH access
- `SSH_KNOWN_HOSTS`: SSH host keys for verification
- `USERNAME`: Username for API authentication
- `PASSWORD`: Password for API authentication
- `LEGS`: Contents of your CSV file with leg definitions (stored as a secret to avoid leaking your personal travel locations)

### Setup the VPS
1. `cp service/infra/inventory.tpl service/infra/inventory.ini` and update with your server details
2. From the infra directory: `ansible-playbook -i inventory.ini setup-vps.yml`
   - This will prompt for your domain name and email for Let's Encrypt
   - Sets up Nginx with HTTPS, creates a deployment user, and configures the environment
3. Run `ssh-keyscan -H <your-server-domain-or-ip>` and save output as a secret: `SSH_KNOWN_HOSTS`
4. SSH into your VPS and copy the private key that was created by the playbook: `cat /home/deployer/.ssh/github_actions` and set it up as a GH secret: `SSH_PRIVATE_KEY`

### Deployment
Deployment happens automatically when you push to the main branch or can be triggered manually from the GitHub Actions tab. The workflow:
1. Stops the existing service
2. Cleans up the deployment directory
3. Copies the new code
4. Sets up environment variables and service file
5. Installs dependencies in a virtual environment
6. Starts the service and verifies it's responding (with retries and timeout)

The deployment uses the SSH key created during VPS setup to securely connect and execute commands. It handles environment variables by injecting secrets at deployment time rather than storing them in the repository.

#### Accessing the API
The service is exposed at `https://<your-domain>/api/` with routes matching those shown in the API documentation above.

Note: All API calls must be made over HTTPS with proper authentication credentials.

### Security Considerations
The current setup implements basic security measures including HTTPS encryption, HTTP Basic Authentication, and secure SSH deployments. While sufficient for personal use, it's not hardened for public-facing production environments. The system uses a single set of credentials for all API access and does not implement rate limiting or advanced threat protection.
