"""Base class for async workers."""

import logging
from abc import ABC, abstractmethod
from typing import Any

logger = logging.getLogger(__name__)


class BaseWorker(ABC):
    """Abstract base for all async workers.

    Subclasses implement `execute` with business logic.
    The `run` method handles logging and error propagation.
    """

    name: str = "worker"

    async def run(self, payload: dict[str, Any]) -> dict[str, Any]:
        logger.info("worker.start", extra={"worker": self.name, "payload_keys": list(payload.keys())})
        try:
            result = await self.execute(payload)
            logger.info("worker.success", extra={"worker": self.name})
            return result
        except Exception as exc:
            logger.error("worker.error", extra={"worker": self.name, "error": str(exc)})
            raise

    @abstractmethod
    async def execute(self, payload: dict[str, Any]) -> dict[str, Any]:
        """Implement business logic here. Pure async function, no side effects in __init__."""
