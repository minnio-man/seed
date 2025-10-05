from __future__ import annotations
from pathlib import Path
from typing import List

def load_numbers(p: str | Path) -> List[float]:
    path = Path(p)
    return [float(line.strip()) for line in path.read_text().splitlines() if line.strip()]
