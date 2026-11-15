#!/usr/bin/env python3
"""Test serveur hors jeu des lettres, avec deux « joueurs » :
   - VRAI elyzea_inventory/server/main.lua (inventaires, don, coffres, sauvegarde dans players.inventory)
   - VRAI elyzea_lettres (config, shared/text.lua, server/main.lua, server/admin.lua)
   - VRAIE base MariaDB (tables players, elyzea_stashes, elyzea_letters)
   Chaque ressource tourne dans son propre environnement Lua, comme dans FiveM.
   Le « redémarrage » recrée l'état Lua des deux ressources (comme « restart ») : seules la base et les KVP restent.

   python3 tests/run_server_sim.py [socket MariaDB] [base]      (pip install lupa pymysql)
   La base de test (par défaut « lettres_test ») est vidée au début."""
import os, sys, json, decimal, datetime
import pymysql
from lupa import lua54
from lupa.lua54 import lua_type

here = os.path.dirname(os.path.abspath(__file__))
base = os.path.dirname(os.path.dirname(here))               # dossier « Elyzea Base »
sock = sys.argv[1] if len(sys.argv) > 1 else '/run/mysqld/mysqld.sock'
dbname = sys.argv[2] if len(sys.argv) > 2 else 'lettres_test'
boot = pymysql.connect(unix_socket=sock, user='root', autocommit=True, charset='utf8mb4')
boot.cursor().execute(f'DROP DATABASE IF EXISTS `{dbname}`')
boot.cursor().execute(f'CREATE DATABASE `{dbname}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci')
db = pymysql.connect(unix_socket=sock, user='root', database=dbname, autocommit=True, charset='utf8mb4')
db.cursor().execute('CREATE TABLE `players` (`citizenid` VARCHAR(50) PRIMARY KEY, `inventory` LONGTEXT NULL) DEFAULT CHARSET=utf8mb4')
for cid in ('CIT001', 'CIT002'):
    db.cursor().execute('INSERT INTO `players` (`citizenid`, `inventory`) VALUES (%s, NULL)', (cid,))

KVP = {}   # stockage KVP par ressource : survit au « redémarrage »

def val(v):
    if isinstance(v, decimal.Decimal): return int(v) if v == int(v) else float(v)
    if isinstance(v, (datetime.datetime, datetime.date)): return str(v)
    if isinstance(v, bytes): return v.decode('utf-8')
    return v

def make_runtime():
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    def to_py(t):
        if lua_type(t) != 'table': return t
        keys = list(t.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [to_py(t[k]) for k in sorted(keys)]
        return {str(k): to_py(v) for k, v in t.items()} if keys else []
    def to_lua(o):
        if isinstance(o, dict): return lua.table_from({k: to_lua(v) for k, v in o.items()})
        if isinstance(o, list): return lua.table_from([to_lua(v) for v in o])
        return o
    def args(a):
        if a is None: return ()
        n = len(a)
        return tuple(to_py(a[i]) if lua_type(a[i]) == 'table' else a[i] for i in range(1, n + 1))
    def run(sql, a):
        p = args(a)
        if p: sql = sql.replace('%', '%%').replace('?', '%s')
        c = db.cursor(pymysql.cursors.DictCursor)
        c.execute(sql, p if p else None)
        return c
    def row(r): return lua.table_from({k: val(v) for k, v in r.items() if v is not None})
    G = lua.globals()
    G.py_query = lambda s, a=None: lua.table_from([row(r) for r in (run(s, a).fetchall() or [])])
    G.py_single = lambda s, a=None: (lambda r: row(r) if r else None)(run(s, a).fetchone())
    G.py_scalar = lambda s, a=None: (lambda r: None if not r else val(list(r.values())[0]))(run(s, a).fetchone())
    G.py_update = lambda s, a=None: run(s, a).rowcount
    G.py_insert = lambda s, a=None: run(s, a).lastrowid
    G.py_json_encode = lambda t: json.dumps(to_py(t), ensure_ascii=False)
    G.py_json_decode = lambda s: to_lua(json.loads(s))
    G.py_kvp_get = lambda res, k: KVP.get((res, k))
    G.py_kvp_set = lambda res, k, v: KVP.__setitem__((res, k), v)
    G.py_kvp_del = lambda res, k: KVP.pop((res, k), None)
    G.py_read = lambda res, path: (lambda p: open(p, encoding='utf-8').read() if os.path.isfile(p) else None)(os.path.join(base, res, path))
    lua.execute(open(os.path.join(here, 'server_mocks.lua'), encoding='utf-8').read())
    return lua

G = make_runtime().globals()
fails = G.RUN_SCENARIO(open(os.path.join(here, 'server_sim.lua'), encoding='utf-8').read())
sys.exit(1 if fails else 0)
