#!/usr/bin/env python3
"""Claves de GBIF de las especies de la guía.

Lee `id` y `nombreCientifico` de lib/datos/datos_guia.dart, pregunta a
`https://api.gbif.org/v1/species/match` una vez por especie (en serie, una
petición cada 1,1 s) y escribe:
  - datos_fuente/claves_gbif.csv (revisable: tipo de coincidencia y nombre)
  - lib/datos/claves_gbif.dart (no editar a mano)

Solo hace falta volver a lanzarlo cuando cambian las especies de la guía.
Con `--solo-dart` regenera el .dart desde el CSV sin red.
"""
import csv, json, pathlib, re, sys, time, urllib.error, urllib.parse, urllib.request

raiz = pathlib.Path(__file__).resolve().parent.parent
ruta_csv = raiz / 'datos_fuente/claves_gbif.csv'
ruta_dart = raiz / 'lib/datos/claves_gbif.dart'
agente = 'naturaleza-flutter/1.0 (cuaderno de campo; https://github.com/JosuIru/cuadernos-de-campo)'


def especies_de_la_guia():
    texto = (raiz / 'lib/datos/datos_guia.dart').read_text(encoding='utf-8')
    patron = re.compile(r"EspecieGuia\(\s*id:\s*'([^']+)',\s*nombreCientifico:\s*'([^']+)'")
    return patron.findall(texto)


def consultar(nombre):
    url = 'https://api.gbif.org/v1/species/match?' + urllib.parse.urlencode({'name': nombre, 'strict': 'true'})
    peticion = urllib.request.Request(url, headers={'User-Agent': agente, 'Accept': 'application/json'})
    for intento in range(3):
        try:
            with urllib.request.urlopen(peticion, timeout=20) as respuesta:
                return json.loads(respuesta.read().decode('utf-8'))
        except urllib.error.HTTPError as error:
            if error.code == 429:
                time.sleep(10 * (intento + 1))
                continue
            raise
    raise RuntimeError(f'GBIF no responde para {nombre}')


def escribir_dart(filas):
    salida = [
        '// GENERADO por tool/generar_claves_gbif.py desde datos_fuente/claves_gbif.csv.',
        '// NO EDITAR A MANO.',
        '//',
        '// Clave de especie de GBIF (`speciesKey` de species/match) de cada especie',
        '// de la guía. Sirve para pedir los registros cercanos sin buscar el nombre',
        '// cada vez y para la vista «Especies vistas cerca».',
        '',
        'const Map<String, int> clavesGbifPorEspecie = {',
    ]
    for fila in filas:
        if fila['clave_gbif']:
            salida.append(f"  '{fila['especie_id']}': {fila['clave_gbif']},")
    salida.append('};')
    ruta_dart.write_text('\n'.join(salida) + '\n', encoding='utf-8')


def main():
    if '--solo-dart' in sys.argv:
        filas = list(csv.DictReader(ruta_csv.read_text(encoding='utf-8').splitlines()))
        escribir_dart(filas)
        print(f'{len(filas)} filas → {ruta_dart.relative_to(raiz)}')
        return
    filas = []
    for especie_id, nombre in especies_de_la_guia():
        datos = consultar(nombre)
        clave = datos.get('speciesKey') or (datos.get('usageKey') if datos.get('rank') == 'SPECIES' else None)
        filas.append({
            'especie_id': especie_id,
            'nombre_cientifico': nombre,
            'clave_gbif': clave or '',
            'tipo_coincidencia': datos.get('matchType', ''),
            'nombre_gbif': datos.get('canonicalName', ''),
            'estado_gbif': datos.get('status', ''),
        })
        print(especie_id, clave, datos.get('matchType'), datos.get('canonicalName'))
        time.sleep(1.1)
    with ruta_csv.open('w', encoding='utf-8', newline='') as fichero:
        escritor = csv.DictWriter(fichero, fieldnames=list(filas[0].keys()))
        escritor.writeheader()
        escritor.writerows(filas)
    escribir_dart(filas)
    print(f'{len(filas)} especies → {ruta_csv.relative_to(raiz)} y {ruta_dart.relative_to(raiz)}')


if __name__ == '__main__':
    main()
