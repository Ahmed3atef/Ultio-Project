# Ultio Project

A reproducible development container and installer for running Ultio (Frappe/ERPNext) locally using pre-built images and automated scripts.

**Supported stack**

- Bench image: v5.27.0
- Frappe: version 15 (matching repo tags for this branch)
- MariaDB: 10.6
- Redis: alpine

Prerequisite: Docker and the VS Code Dev Containers extension are required for the recommended development workflow.

**Quick Start (recommended)**

1. Generate an SSH key and add it to your GitLab account (so container can access private repos if needed).
2. Clone this repository to your host machine:

    git clone <repo-url>
    cd ultio-project

3. Open the project in VS Code:

    code .

4. Install the VS Code extension "Dev Containers" if you haven't already: https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers
5. From the Command Palette (Ctrl+Shift+P) choose: "Dev Containers: Reopen in Container" — this will open the workspace inside the project's development container.
6. Inside the container terminal run the installer script:

    ./installer.sh

This will bootstrap the environment using the configured images and run the provisioning scripts located in the `development/` folder.

Project layout

- development/: top-level helper scripts and installer
    - installer.sh: main installer entrypoint (run inside container)
    - scripts/: small helper scripts used by the installer
    - setup-site.sh: creates and configures a site
    - get-apps/: utilities to download/prepare apps
        - apps.json: list of apps to fetch
        - get-apps.sh: fetches apps defined in apps.json
    - sites/: example site configuration files
        - site-name.json: example site config

Notes & tips

- Ensure Docker has enough resources (CPU, memory, disk) for Frappe/Bench.
- If you rely on private GitLab repositories, the container needs your SSH key added to the container or configured via SSH agent forwarding.
- If any service image tags need updating, change them in the installer or Docker compose files before running the installer.

Troubleshooting

- If the container build fails, check the Dev Containers output and rerun `./development/scripts/get-apps/get-apps.sh` if app downloads failed.
- For database connection issues, confirm the MariaDB image/tag matches `10.6` and is up before running bench commands.

Contributing

- Open issues or pull requests against the `develop` branch. Describe steps to reproduce and any logs.

License & contacts

- Describe your project license here (e.g., MIT) and add contact/maintainer info.

Files changed: updated README to provide clearer quickstart and structure.
