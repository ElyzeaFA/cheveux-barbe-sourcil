#!/usr/bin/env python3
"""Simulation serveur (vrai elyzea_inventory + elyzea_cachettes) : python3 tests/run_server_sim.py  (pip install lupa)"""
import os, sys
from lupa import lua54
here = os.path.dirname(os.path.abspath(__file__))
base = os.path.dirname(os.path.dirname(here))          # dossier « Elyzea Base »
lua = lua54.LuaRuntime(unpack_returned_tuples=True)
lua.globals().BASE = base
fails = lua.execute(open(os.path.join(here, 'server_sim.lua'), encoding='utf-8').read())
sys.exit(1 if fails else 0)
