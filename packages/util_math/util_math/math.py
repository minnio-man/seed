from __future__ import annotations
from typing import Iterable

def add(a: float, b: float) -> float:
    return a + b

def mean(xs: Iterable[float]) -> float:
    xs_list = list(xs)
    if not xs_list:
        raise ValueError("mean() of empty sequence")
    return sum(xs_list) / len(xs_list)
