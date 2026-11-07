#!/usr/bin/env python3
import os, shutil, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
cfg  = os.path.join(here, '..', 'cfg', 'macros.def')
orig = open(cfg).read()
i = orig.index('[mist|sidi]')
he = open(os.path.join(here, 'macros_he.def')).read()
try:
    open(cfg, 'w').write(orig[:i] + '[mist|sidi]\n' + he)
    work = os.path.join(here, '_gen')
    os.makedirs(work, exist_ok=True)
    subprocess.run(['jtframe', 'mem', 'harier', '--target', 'mist', '-l'], cwd=work, check=True)
    for f in ('jtharier_game_sdram.v', 'mem_ports.inc'):
        shutil.move(os.path.join(work, f), os.path.join(here, f))
    shutil.rmtree(work)
finally:
    open(cfg, 'w').write(orig)
print('mist_he wrapper regenerated')
