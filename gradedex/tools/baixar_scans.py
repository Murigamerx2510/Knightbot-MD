#!/usr/bin/env python3
"""Baixa os scans oficiais das cartas do pokemontcg.io para img/cards/.

Uso, a partir da pasta gradedex/:
    python3 tools/baixar_scans.py            # baixa só o que falta
    python3 tools/baixar_scans.py --refazer  # baixa tudo de novo

Para cada carta do mapa PTCG em js/data.js: consulta a API, confere nome e
número, baixa a imagem em alta, gera <id>.webp (600 px) e <id>-sm.webp
(260 px) e reescreve js/scans.js com as cartas que têm scan.
POKEMONTCG_API_KEY (opcional) aumenta o limite de consultas da API.
"""
import io
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, 'js', 'data.js')
OUT = os.path.join(ROOT, 'img', 'cards')
MANIFEST = os.path.join(ROOT, 'js', 'scans.js')
API = 'https://api.pokemontcg.io/v2/cards/'
SIZES = {'': 600, '-sm': 260}


def parse_data():
    src = open(DATA, encoding='utf-8').read()
    block = re.search(r'const PTCG = \{(.*?)\};', src, re.S).group(1)
    ptcg = dict(re.findall(r"'([\w-]+)':\s*'([\w.-]+)'", block))
    cards = {}
    for m in re.finditer(r"\{ id: '([\w-]+)',\s*name: '([^']+)'.*?num: '([^']+)'", src):
        cards[m.group(1)] = {'name': m.group(2), 'num': m.group(3)}
    return ptcg, cards


def get(url, binary=False):
    headers = {'User-Agent': 'GradeDex/1.0'}
    if os.environ.get('POKEMONTCG_API_KEY'):
        headers['X-Api-Key'] = os.environ['POKEMONTCG_API_KEY']
    for attempt in range(4):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as r:
                body = r.read()
                return body if binary else json.loads(body)
        except urllib.error.HTTPError as e:
            if e.code not in (429, 500, 502, 503, 504) or attempt == 3:
                raise
        except urllib.error.URLError as e:
            # Proxy recusando o domínio: não adianta tentar de novo.
            raise SystemExit('Sem acesso a %s (%s). Libere api.pokemontcg.io e images.pokemontcg.io '
                             'no acesso de rede do ambiente e rode de novo.' % (url.split('/')[2], e.reason))
        time.sleep(2 ** (attempt + 1))


def same_name(ours, theirs):
    key = lambda s: re.sub(r'[^a-z0-9★]', '', s.lower())
    return key(ours) == key(theirs)


def same_number(ours, theirs):
    return ours.split('/')[0].lstrip('0').upper() == str(theirs).lstrip('0').upper()


def save_webp(png, card_id):
    img = Image.open(io.BytesIO(png))
    img = img.convert('RGBA') if img.mode in ('P', 'LA', 'RGBA') else img.convert('RGB')
    for suffix, width in SIZES.items():
        height = round(img.height * width / img.width)
        img.resize((width, height), Image.LANCZOS).save(
            os.path.join(OUT, card_id + suffix + '.webp'), 'WEBP', quality=82, method=6)


def write_manifest(card_ids):
    have = sorted(c for c in card_ids if all(
        os.path.exists(os.path.join(OUT, c + s + '.webp')) for s in SIZES))
    body = ',\n'.join('  "%s": 1' % c for c in have)
    with open(MANIFEST, 'w', encoding='utf-8') as f:
        f.write('/* Gerado por tools/baixar_scans.py: cartas com scan oficial salvo em img/cards/. */\n')
        f.write('window.GD = window.GD || {};\n')
        f.write('window.GD.SCANS = {' + ('\n' + body + '\n' if body else '') + '};\n')
    return have


def main():
    redo = '--refazer' in sys.argv
    os.makedirs(OUT, exist_ok=True)
    ptcg, cards = parse_data()
    problems, cache = [], {}
    for card_id, pid in ptcg.items():
        ours = cards.get(card_id)
        if not ours:
            problems.append('%s: não encontrada em CARDS' % card_id)
            continue
        if not redo and all(os.path.exists(os.path.join(OUT, card_id + s + '.webp')) for s in SIZES):
            print('ok   %-22s (já baixado)' % card_id)
            continue
        try:
            if pid not in cache:
                info = get(API + pid)['data']
                cache[pid] = (info, get(info['images']['large'], binary=True))
            info, png = cache[pid]
        except Exception as e:  # rede bloqueada, id errado, etc.
            problems.append('%s (%s): %s' % (card_id, pid, e))
            continue
        if not same_name(ours['name'], info['name']) or not same_number(ours['num'], info['number']):
            problems.append('%s: data.js diz "%s %s", a API diz "%s %s" (%s)' % (
                card_id, ours['name'], ours['num'], info['name'], info['number'], info['set']['name']))
            continue
        save_webp(png, card_id)
        print('novo %-22s %s %s · %s' % (card_id, info['name'], info['number'], info['set']['name']))
    have = write_manifest(cards.keys())
    print('\n%d de %d cartas com scan; js/scans.js atualizado.' % (len(have), len(ptcg)))
    if problems:
        print('\nProblemas:\n  ' + '\n  '.join(problems))
        sys.exit(1)


if __name__ == '__main__':
    main()
