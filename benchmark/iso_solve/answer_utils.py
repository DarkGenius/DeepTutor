# -*- coding: utf-8 -*-
"""
Answer extraction and mathematical equivalence utilities for MATH benchmark.

Wraps the upstream `math_equivalence.is_equiv` with extra extraction helpers
so callers can go straight from raw LLM output to a boolean verdict.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# Make the upstream math_equivalence importable
_MODELING_DIR = Path(__file__).resolve().parent / "math" / "modeling"
if str(_MODELING_DIR) not in sys.path:
    sys.path.insert(0, str(_MODELING_DIR))

from math_equivalence import is_equiv  # noqa: E402


def last_boxed_only_string(string: str) -> str | None:
    """Return the last ``\\boxed{...}`` or ``\\fbox{...}`` substring (inclusive)."""
    idx = string.rfind("\\boxed")
    if idx < 0:
        idx = string.rfind("\\fbox")
        if idx < 0:
            return None

    i = idx
    num_open = 0
    right = None
    while i < len(string):
        if string[i] == "{":
            num_open += 1
        if string[i] == "}":
            num_open -= 1
            if num_open == 0:
                right = i
                break
        i += 1

    return string[idx : right + 1] if right is not None else None


def remove_boxed(s: str | None) -> str | None:
    """Strip the ``\\boxed{`` prefix and trailing ``}``."""
    if s is None:
        return None
    left = "\\boxed{"
    if s.startswith(left) and s.endswith("}"):
        return s[len(left) : -1]
    left2 = "\\fbox{"
    if s.startswith(left2) and s.endswith("}"):
        return s[len(left2) : -1]
    return s


_BOXED_RE = re.compile(r"\\boxed\{(.+?)\}", re.DOTALL)


def extract_answer(text: str) -> str | None:
    """Best-effort answer extraction from arbitrary LLM output.

    Strategy (in order):
    1. Last ``\\boxed{...}`` in the text (handles nested braces).
    2. Regex fallback for simple ``\\boxed{X}`` patterns.
    3. If the text contains ``the answer is`` / ``答案是``, grab the trailing part.
    4. Return ``None`` if nothing found.
    """
    boxed = last_boxed_only_string(text)
    if boxed is not None:
        return remove_boxed(boxed)

    m = _BOXED_RE.findall(text)
    if m:
        return m[-1].strip()

    for marker in ("the answer is", "the final answer is", "答案是", "最终答案"):
        low = text.lower()
        pos = low.rfind(marker)
        if pos >= 0:
            tail = text[pos + len(marker) :].strip().rstrip(".")
            if tail:
                return tail

    return None


def check_answer(model_output: str, ground_truth: str) -> bool:
    """Return *True* if the model's extracted answer is equivalent to the ground truth."""
    predicted = extract_answer(model_output)
    if predicted is None:
        return False

    gt = extract_answer(ground_truth)
    if gt is None:
        gt = ground_truth.strip()

    try:
        return is_equiv(predicted, gt)
    except Exception:
        return predicted.strip() == gt.strip()
