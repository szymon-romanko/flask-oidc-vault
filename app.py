import json
import logging
import os
import random

import requests
from authlib.integrations.flask_client import OAuth
from flask import Flask, url_for, session, make_response, redirect

logging.basicConfig(level=logging.DEBUG)

app = Flask(__name__)
app.secret_key = str(random.randbytes(32))

# vault address - use "vault" when running in docker (container name dns), otherwise localhost
VAULT_ADDR = os.environ.get("VAULT_ADDR")
if VAULT_ADDR is None:
    VAULT_ADDR = "http://vault:8200" if os.environ.get("DOCKER") == "1" else "http://localhost:8200"
app.logger.info(f"VAULT_ADDR: {VAULT_ADDR}")

# vault token - used only during startup for configuration
VAULT_TOKEN = os.environ.get("VAULT_TOKEN")
if VAULT_TOKEN is None:
    raise Exception("VAULT_TOKEN env var not set")

# read client_id and client_secret from vault
client_config = requests.get(f"{VAULT_ADDR}/v1/identity/oidc/client/webapp", headers={"X-Vault-Token": VAULT_TOKEN}).json()

# url used for automatic configuration of OIDC client
oidc_config_url = f"{VAULT_ADDR}/v1/identity/oidc/provider/default/.well-known/openid-configuration"

# OIDC client configuration
oauth = OAuth(app)
oauth.register(
    name='vault',
    client_id=client_config["data"]["client_id"],
    client_secret=client_config["data"]["client_secret"],
    server_metadata_url=oidc_config_url,
    client_kwargs={
        'scope': 'openid users groups'
    }
)


@app.route('/')
def homepage():
    user = session.get('user')
    if user is None:
        return "Not logged in<br><a href='/login'>Login</a>"
    return f"Logged in as {user["username"]}<br><pre id=\"json\">{json.dumps(user, indent=4)}</pre><br><a href='/secret'>Secret</a><br><a href='/logout'>Logout</a>"


@app.route('/login')
def login():
    redirect_uri = url_for('auth', _external=True)
    return oauth.vault.authorize_redirect(redirect_uri)


@app.route('/auth')
def auth():
    token = oauth.vault.authorize_access_token()
    session['user'] = token['userinfo']
    return redirect('/')


@app.route('/logout')
def logout():
    session.pop('user', None)
    return redirect('/')


@app.route('/secret')
def secret():
    user = session.get('user')
    if user is None:
        return make_response("Not logged in, can't read secret", 403)
    return f"Logged in as {user["username"]}<br>{"very_secret_data_123" if user["username"] == "alice" else "user logged in but not authorized to view this data"}<br><a href='/'>Back</a>"
