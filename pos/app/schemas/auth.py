from pydantic import BaseModel


class TerminalLoginIn(BaseModel):
    terminal_code: str
    staff_code: str
    pin: str
    # Optionally open/attach a shift on login.
    open_shift: bool = False
    opening_cash: float = 0
