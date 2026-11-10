#!/usr/bin/env python3
"""datos_fuente/usos_tradicionales_ema.csv → lib/datos/usos_tradicionales.dart (no editar el .dart a mano)."""
import csv, pathlib
raiz = pathlib.Path(__file__).resolve().parent.parent
lineas = [l for l in (raiz / 'datos_fuente/usos_tradicionales_ema.csv').read_text(encoding='utf-8').splitlines() if not l.startswith('#')]
filas = list(csv.DictReader(lineas))
def lit(texto):
    return "'" + texto.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"
salida = ['// GENERADO por tool/generar_usos_tradicionales.py desde', '// datos_fuente/usos_tradicionales_ema.csv. NO EDITAR A MANO.', '//', '// Monografías de la Unión del HMPC (EMA), leídas el 2026-11-10. Resúmenes', '// pendientes de cotejo por una persona.', '', "import 'uso_tradicional.dart';", '', 'const List<UsoTradicional> usosTradicionalesEma = [']
for f in filas:
    salida.append('  UsoTradicional(')
    for campo, clave in [('especieId','especie_id'),('parte','parte'),('uso','uso_tradicional'),('contraindicaciones','contraindicaciones'),('precauciones','precauciones'),('tipoUso','tipo_uso'),('estadoMonografia','estado_monografia'),('url','url')]:
        salida.append(f'    {campo}: {lit(f[clave])},')
    salida.append('  ),')
salida.append('];')
(raiz / 'lib/datos/usos_tradicionales.dart').write_text('\n'.join(salida) + '\n', encoding='utf-8')
print(f'{len(filas)} usos → lib/datos/usos_tradicionales.dart')
