from data_io import load_numbers
from pathlib import Path

def test_load_numbers(tmp_path: Path):
    p = tmp_path / "nums.txt"
    p.write_text("1\n2\n3\n")
    assert load_numbers(p) == [1.0, 2.0, 3.0]
