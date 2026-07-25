from __future__ import annotations

import contextvars
import uuid

from tortoise import fields, models
from tortoise.manager import Manager
from tortoise.queryset import QuerySet

from app.utils.timezone import now

show_deleted_var: contextvars.ContextVar[bool] = contextvars.ContextVar("show_deleted", default=False)


class SoftDeleteQuerySet(QuerySet):
    def delete(self):
        return self.update(is_deleted=True, deleted_at=now(), updated_at=now())

    def hard_delete(self):
        return super().delete()


class BaseManager(Manager):
    def get_queryset(self):
        if show_deleted_var.get(False):
            return SoftDeleteQuerySet(model=self._model)
        return SoftDeleteQuerySet(model=self._model).filter(is_deleted=False)


class BaseModel(models.Model):
    id = fields.UUIDField(pk=True, default=uuid.uuid4)

    deleted_at = fields.DatetimeField(null=True, index=True)
    is_deleted = fields.BooleanField(default=False, index=True)

    created_at = fields.DatetimeField(auto_now_add=True)
    updated_at = fields.DatetimeField(auto_now=True)

    class Meta:
        abstract = True

    def __init_subclass__(cls, **kwargs):
        super().__init_subclass__(**kwargs)
        if getattr(cls._meta, "abstract", False):
            return
        if getattr(cls, "_soft_delete", True):
            cls._meta.manager = BaseManager(model=cls)
            cls.objects = cls._meta.manager
            cls.all_objects = Manager(model=cls)
        else:
            cls._meta.manager = Manager(model=cls)
            cls.objects = cls._meta.manager
            cls.all_objects = cls._meta.manager

    async def delete(self, using_db=None) -> None:
        if self.is_deleted:
            return
        self.deleted_at = now()
        self.is_deleted = True
        await self.save(update_fields=["deleted_at", "is_deleted", "updated_at"], using_db=using_db)

    async def force_delete(self, using_db=None) -> None:
        await super().delete(using_db=using_db)
