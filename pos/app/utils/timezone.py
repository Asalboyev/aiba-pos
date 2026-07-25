from datetime import date, datetime, time

import pytz

from app.core.config import settings

TZ = pytz.timezone(settings.TIMEZONE)


def now() -> datetime:
    return datetime.now(TZ)


def start_of_day(d: date | None = None) -> datetime:
    d = d or now().date()
    return TZ.localize(datetime.combine(d, time.min))


def end_of_day(d: date | None = None) -> datetime:
    d = d or now().date()
    return TZ.localize(datetime.combine(d, time.max))
