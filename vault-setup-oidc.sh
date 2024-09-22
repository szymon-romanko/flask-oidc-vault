#!/bin/sh
# vault package is required
# sudo apt-get install vault -y

# based on https://developer.hashicorp.com/vault/tutorials/auth-methods/oidc-identity-provider

# set the vault address
#export VAULT_ADDR=http://127.0.0.1:8200
# and login with root token
vault login -method=token token="${VAULT_TOKEN}"

# ===== setup users =====
# for this demo we will use userpass auth method (simple username/password)
# you can use any other auth method (ldap, github, etc.)
vault auth enable userpass
vault policy write oidc-auth - << EOF
path "identity/oidc/provider/default/authorize" {
capabilities = [ "read" ]
}
EOF
# auth method id (userpass accessor)
#AUTH_METHOD_ID=$(vault auth list -detailed -format json | jq -r '.["userpass/"].accessor')
AUTH_METHOD_ID=$(vault read -field=accessor sys/auth/userpass)


# ===== first user - alice =====
vault write auth/userpass/users/alice \
    password="alice123" \
    token_policies="oidc-auth" \
    token_ttl="1h"

vault write identity/entity \
    name="alice" \
    metadata="email=alice@test.com" \
    metadata="phone_number=123-456-7890" \
    disabled=false

USER_ENTITY_ID_1=$(vault read -field=id identity/entity/name/alice)

vault write identity/entity-alias \
    name="alice" \
    canonical_id="$USER_ENTITY_ID_1" \
    mount_accessor="$AUTH_METHOD_ID"


# ===== second user - bob =====
vault write auth/userpass/users/bob \
    password="bob123" \
    token_policies="oidc-auth" \
    token_ttl="1h"

vault write identity/entity \
    name="bob" \
    metadata="email=bob@test.com" \
    metadata="phone_number=098-765-4321" \
    disabled=false

USER_ENTITY_ID_2=$(vault read -field=id identity/entity/name/bob)

vault write identity/entity-alias \
    name="bob" \
    canonical_id="$USER_ENTITY_ID_2" \
    mount_accessor="$AUTH_METHOD_ID"


# ===== setup groups =====
# create empty group and add bob to it
vault write identity/group \
    name="test_group" \
    member_entity_ids="$USER_ENTITY_ID_2"
GROUP_ID=$(vault read -field=id identity/group/name/test_group)


# ===== assignment configuration =====
# (defines what users and groups can access the app)
vault write identity/oidc/assignment/my-assignment \
    entity_ids="${USER_ENTITY_ID_1}" \
    group_ids="${GROUP_ID}"


# ===== oidc client config =====
# (app that will use the oidc provider)
vault write identity/oidc/client/webapp \
  redirect_uris="http://localhost:5000/auth" \
  assignments="my-assignment"
#  assignments="allow_all"
CLIENT_ID=$(vault read -field=client_id identity/oidc/client/webapp)


# ===== scopes configuration =====
# (defines what information about user will be passed to the app (client))
# user scope
USER_SCOPE_TEMPLATE='{
    "username": {{identity.entity.name}},
    "current_time": {{time.now}},
    "contact": {
        "email": {{identity.entity.metadata.email}},
        "phone_number": {{identity.entity.metadata.phone_number}}
    }
}'
vault write identity/oidc/scope/users \
    description="The user scope provides claims using Vault identity entity metadata" \
    template="$(echo "${USER_SCOPE_TEMPLATE}" | base64 -)"
# group scope
GROUPS_SCOPE_TEMPLATE='{
    "groups": {{identity.entity.groups.names}}
}'
vault write identity/oidc/scope/groups \
    description="The groups scope provides the groups claim using Vault group membership" \
    template="$(echo "${GROUPS_SCOPE_TEMPLATE}" | base64 -)"


# ===== oidc provider =====
# (vault-side configuration) (there can be multiple providers with different configurations on a single vault)
vault write identity/oidc/provider/default \
    allowed_client_ids="${CLIENT_ID}" \
    scopes_supported="groups,users"


# read client_id and client_secret
#vault read identity/oidc/client/webapp
# read oidc provider configuration
#curl -sk "$VAULT_ADDR/v1/identity/oidc/provider/default/.well-known/openid-configuration" | jq
