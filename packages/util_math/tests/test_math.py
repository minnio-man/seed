from util_math import add, mean
import pytest

def test_add():
    assert add(2, 3) == 5

def test_mean_ok():
    assert mean([2, 4]) == 3

def test_mean_empty():
    with pytest.raises(ValueError):
        mean([])
