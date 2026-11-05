import logging
from datetime import datetime, timezone

logger = logging.getLogger("request_audit")


class RequestAuditMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            method = scope.get("method", "")
            path = scope.get("path", "")
            if path.startswith("/v1/"):
                logger.info(
                    "model_request_received method=%s path=%s timestamp=%s",
                    method,
                    path,
                    datetime.now(timezone.utc).isoformat(),
                )
        await self.app(scope, receive, send)
