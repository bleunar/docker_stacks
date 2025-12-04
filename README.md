# Docker Stacks

A collection of production-ready Docker stacks for various services to support Dockerized web applications, managed via Docker Compose and a management script.

## Available Stacks

| Stack | Directory | Services | Description |
| :--- | :--- | :--- | :--- |
| **Management** | `management_stack` | Portainer | Container management UI. Hosts the `main` network. |
| **MySQL** | `mysql_stack` | MySQL 8.0, PHPMyAdmin | Database stack with web administration. |
| **PostgreSQL** | `postgres_stack` | PostgreSQL 15, PGAdmin | Database stack with web administration. |
| **Monitoring** | `monitoring_stack` | Prometheus, Grafana | Metrics collection and visualization. |
| **Cloudflared** | `cloudflared_stack` | Cloudflared, Nginx Proxy Manager | Secure tunneling and reverse proxy management. |
| **N8N** | `n8n_stack` | N8N | Self-hosted N8N instance. |

## Installation and Setup

### Prerequisites
- Docker & Docker Compose
- `whiptail` (for the management TUI)
- `git`

### Setup and Initialization

1.  **Clone the repository**
    ```bash
    git clone <repository_url>
    cd docker_stacks
    ```

2.  **Configure Environment**
    Each stack has its own `.env` file. Copy the template and customize it:
    ```bash
    cd mysql_stack
    cp .env.template .env
    nano .env
    ```

3.  **Configure Secrets**
    Secrets are stored in the `secrets/` directory of each stack. Files starting with `_` are templates.
    ```bash
    # Example for MySQL
    cd mysql_stack/secrets
    cp _mysql_root_password mysql_root_password
    nano mysql_root_password
    ```
    *Repeat for all required secrets in the stack.*

4.  **Start the Stack**
    ```bash
    cd mysql_stack
    ./manage.sh
    ```

## Usage

Each stack comes with a `manage.sh` script for easy administration.

```bash
cd <stack_directory>
./manage.sh
```

### Features
The TUI provides the following options:
-   **Start Stack**: Launch services (`docker compose up -d`).
-   **Stop Stack**: Halt services.
-   **Restart Container**: Restart specific containers.
-   **View Network**: Inspect the stack's network and connected containers.
-   **Backup Volumes**: Create timestamped backups of persistent volumes to `./volume_backups/`.
-   **Restore Volume**: Restore data from existing backups.
-   **Logs**: View real-time container logs.

## Network Architecture

-   **Main Network**: The `management_stack` creates a `main` bridge network.
-   **Stack Isolation**: By default, other stacks run on their own isolated networks (e.g., `mysql_net`, `postgres_net`).
-   **Interconnectivity**: To connect services (e.g., connect Grafana to MySQL), you can attach containers to the `main` network via Portainer or by modifying the `docker-compose.yml` files.