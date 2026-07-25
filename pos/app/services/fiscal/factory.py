from app.core.config import settings
from app.services.fiscal.base import FiscalProvider
from app.services.fiscal.epos import EposProvider
from app.services.fiscal.mock import MockFiscalProvider
from app.services.fiscal.multikassa import MultikassaProvider

_PROVIDERS = {
    "mock": MockFiscalProvider,
    "multikassa": MultikassaProvider,
    "epos": EposProvider,
}


def get_provider(name: str | None = None) -> FiscalProvider:
    key = (name or settings.FISCAL_PROVIDER or "mock").lower()
    cls = _PROVIDERS.get(key, MockFiscalProvider)
    return cls()
