from __future__ import annotations

from urllib.parse import urlparse

from mcp.server.auth.settings import AuthSettings
from mcp.server.fastmcp import FastMCP
from mcp.server.fastmcp.server import TransportSecuritySettings

from backend.config import Settings
from backend.mcp.auth import AstraMCPTokenVerifier
from backend.mcp.tools.recipes import register_recipe_tools
from backend.services.oauth import mcp_resource_url


class MCPRootProxy:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send) -> None:
        proxied_scope = dict(scope)
        proxied_scope["path"] = "/"
        proxied_scope["root_path"] = scope.get("root_path", "") + "/mcp"
        await self.app(proxied_scope, receive, send)


def _transport_security(settings: Settings) -> TransportSecuritySettings:
    parsed = urlparse(settings.public_base_url)
    allowed_hosts = {"127.0.0.1:*", "localhost:*", "[::1]:*", "testserver"}
    allowed_origins = {"http://127.0.0.1:*", "http://localhost:*", "http://[::1]:*"}
    if parsed.netloc:
        allowed_hosts.add(parsed.netloc)
        if parsed.hostname:
            allowed_hosts.add(f"{parsed.hostname}:*")
        allowed_origins.add(f"{parsed.scheme}://{parsed.netloc}")
    return TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=sorted(allowed_hosts),
        allowed_origins=sorted(allowed_origins),
    )


def create_mcp_app(settings: Settings):
    server = FastMCP(
        "Astra Nutrition OS",
        instructions="MCP tools for the Astra Nutrition OS recipe catalog.",
        token_verifier=AstraMCPTokenVerifier(settings),
        streamable_http_path="/",
        stateless_http=True,
        json_response=True,
        auth=AuthSettings(
            issuer_url=settings.public_base_url,
            resource_server_url=mcp_resource_url(settings),
            required_scopes=["recipes:read"],
        ),
        transport_security=_transport_security(settings),
    )
    register_recipe_tools(server)
    return server.streamable_http_app()
