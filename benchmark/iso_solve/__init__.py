# -*- coding: utf-8 -*-
"""
iso_solve — Isolated solving benchmark for evaluating LLMs on MATH dataset.

Two evaluation modes:
  - ``direct``:   prompt the LLM directly and check the answer
  - ``pipeline``: run through DeepTutor's full Plan → ReAct → Write pipeline
"""

from .answer_utils import check_answer, extract_answer, is_equiv
