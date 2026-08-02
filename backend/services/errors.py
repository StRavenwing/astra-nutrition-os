from __future__ import annotations


class DomainError(Exception):
    def __init__(self, message: str, status_code: int = 400, details: object | None = None):
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.details = details


class NotFoundError(DomainError):
    def __init__(self, message: str):
        super().__init__(message, 404)


class ConflictError(DomainError):
    def __init__(self, message: str):
        super().__init__(message, 409)


class UnauthorizedError(DomainError):
    def __init__(self, message: str = "Требуется вход"):
        super().__init__(message, 401)


class ForbiddenError(DomainError):
    def __init__(self, message: str = "Недостаточно прав"):
        super().__init__(message, 403)
