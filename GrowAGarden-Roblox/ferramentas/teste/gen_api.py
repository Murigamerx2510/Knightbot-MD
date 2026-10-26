# Gera um resumo compacto da API do Roblox para o simulador (mock) em Luau.
import json, sys
full = json.load(open(sys.argv[1]))
out = []
def sec_ok(sec):
    if isinstance(sec, str):
        return sec == 'None', sec == 'None'
    return sec.get('Read') == 'None', sec.get('Write') == 'None'
for c in full['Classes']:
    tags = c.get('Tags') or []
    flags = ''
    if 'NotCreatable' in tags: flags += 'n'
    if 'Service' in tags: flags += 's'
    if 'Deprecated' in tags: flags += 'd'
    out.append(f"C {c['Name']} {c['Superclass']} {flags or '-'}")
    for m in c['Members']:
        mt = m['MemberType']
        mtags = m.get('Tags') or []
        r_ok, w_ok = sec_ok(m.get('Security', 'None'))
        f = ''
        if 'ReadOnly' in mtags: f += 'r'
        if 'NotScriptable' in mtags: f += 'x'
        if 'Deprecated' in mtags: f += 'd'
        if not r_ok: f += 'p'
        if not w_ok: f += 'w'
        if 'Yields' in mtags: f += 'y'
        f = f or '-'
        if mt == 'Property':
            vt = m['ValueType']
            d = m.get('Default', '')
            if not isinstance(d, str) or d.startswith('__api_dump') or ' ' in d and vt['Category'] in ('Primitive','Enum'):
                d = ''
            d = d.replace(' ', '')
            out.append(f"P {m['Name']} {vt['Category']}:{vt['Name']} {f} {d}")
        elif mt == 'Function':
            out.append(f"F {m['Name']} {f}")
        elif mt == 'Event':
            out.append(f"E {m['Name']} {f}")
        elif mt == 'Callback':
            out.append(f"B {m['Name']} {f}")
for e in full['Enums']:
    out.append(f"N {e['Name']}")
    for i in e['Items']:
        out.append(f"I {i['Name']} {i['Value']}")
open(sys.argv[2], 'w').write('__API_TEXT = [==[\n' + '\n'.join(out) + '\n]==]\n')
print(len(out), 'linhas')
