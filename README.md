# Flask + Authlib OIDC + Hashicorp Vault

Quick example on how to set up a Flask app with OIDC authentication, using Hashicorp Vault as OIDC provider.

# Usage

1. Clone the repository
2. Set up environment variable with your local ip address
    ```bash
    export IP_ADDRESS=192.168.1.1
    ```
3. Run docker compose
    ```bash
    docker compose up --build
    ```
4. Go to [http://localhost:5000](), you can log in by selecting `userpass` from the dropdown menu in vault

There are two users created by the setup script:

- `alice` with password `alice123` and access to `/secret` endpoint
- `bob` with password `bob123` and without access to `/secret` endpoint
