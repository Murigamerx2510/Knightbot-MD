#!/usr/bin/env python3
"""
Gera o arquivo CultiveUmJardim.rbxlx (lugar do Roblox) a partir da pasta src/.

Segue a mesma convencao do Rojo:
  Nome.luau              -> ModuleScript
  Nome.server.luau       -> Script
  Nome.client.luau       -> LocalScript
  pasta/init.server.luau -> a pasta vira um Script e os outros arquivos ficam dentro dele
  pasta comum            -> Folder

Uso: python3 ferramentas/gerar_rbxlx.py
"""

import os
from xml.sax.saxutils import escape

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(RAIZ, "src")
SAIDA = os.path.join(RAIZ, "CultiveUmJardim.rbxlx")

contador = [0]


def referente():
    contador[0] += 1
    return "RBX%08X" % contador[0]


def cdata(texto):
    # "]]>" nao pode aparecer dentro de CDATA
    return "<![CDATA[" + texto.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(classe, nome, filhos=(), fonte=None, nivel=1):
    tab = "\t" * nivel
    linhas = [f'{tab}<Item class="{classe}" referent="{referente()}">', f"{tab}\t<Properties>"]
    linhas.append(f'{tab}\t\t<string name="Name">{escape(nome)}</string>')
    if fonte is not None:
        linhas.append(f'{tab}\t\t<ProtectedString name="Source">{cdata(fonte)}</ProtectedString>')
    linhas.append(f"{tab}\t</Properties>")
    for filho in filhos:
        linhas.append(filho(nivel + 1))
    linhas.append(f"{tab}</Item>")
    return "\n".join(linhas)


def ler(caminho):
    with open(caminho, encoding="utf-8") as arquivo:
        return arquivo.read()


def tipo_do_arquivo(nome):
    if nome.endswith(".server.luau"):
        return "Script", nome[: -len(".server.luau")]
    if nome.endswith(".client.luau"):
        return "LocalScript", nome[: -len(".client.luau")]
    if nome.endswith(".luau"):
        return "ModuleScript", nome[: -len(".luau")]
    return None, None


def no_da_pasta(caminho, nome):
    """Retorna uma funcao que gera o XML da pasta (ou do script init) no nivel pedido."""
    arquivos = sorted(os.listdir(caminho))
    init = None
    for candidato in ("init.server.luau", "init.client.luau", "init.luau"):
        if candidato in arquivos:
            init = candidato
    filhos = []
    for nome_arquivo in arquivos:
        completo = os.path.join(caminho, nome_arquivo)
        if nome_arquivo == init:
            continue
        if os.path.isdir(completo):
            filhos.append(no_da_pasta(completo, nome_arquivo))
            continue
        classe, nome_item = tipo_do_arquivo(nome_arquivo)
        if classe:
            fonte = ler(completo)
            filhos.append(lambda nivel, c=classe, n=nome_item, f=fonte: item(c, n, (), f, nivel))
    if init:
        classe, _ = tipo_do_arquivo(init)
        fonte = ler(os.path.join(caminho, init))
        return lambda nivel: item(classe, nome, filhos, fonte, nivel)
    return lambda nivel: item("Folder", nome, filhos, None, nivel)


def servico(classe, filhos):
    return item(classe, classe, filhos, None, 1)


def terreno(nivel):
    """Terreno com a grama animada ligada (Decoration so pode ser ligada no arquivo, nao por script)."""
    tab = "\t" * nivel
    return "\n".join([
        f'{tab}<Item class="Terrain" referent="{referente()}">',
        f"{tab}\t<Properties>",
        f'{tab}\t\t<string name="Name">Terrain</string>',
        f'{tab}\t\t<bool name="Decoration">true</bool>',
        f'{tab}\t\t<float name="GrassLength">0.7</float>',
        f"{tab}\t</Properties>",
        f"{tab}</Item>",
    ])


def principal():
    replicated = [
        no_da_pasta(os.path.join(SRC, "ReplicatedStorage", "Shared"), "Shared"),
        lambda nivel: item("Folder", "Modelos", (), None, nivel),
    ]
    server = [no_da_pasta(os.path.join(SRC, "ServerScriptService", "GardenServer"), "GardenServer")]
    client = [no_da_pasta(os.path.join(SRC, "StarterPlayerScripts", "GardenClient"), "GardenClient")]
    starter_player_scripts = lambda nivel: item("StarterPlayerScripts", "StarterPlayerScripts", client, None, nivel)

    partes = [
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
        '\t<Meta name="ExplicitAutoJoints">true</Meta>',
        "\t<External>null</External>",
        "\t<External>nil</External>",
        servico("Workspace", [terreno]),
        servico("ReplicatedStorage", replicated),
        servico("ServerScriptService", server),
        servico("StarterPlayer", [starter_player_scripts]),
        "</roblox>",
    ]
    with open(SAIDA, "w", encoding="utf-8", newline="\n") as arquivo:
        arquivo.write("\n".join(partes) + "\n")
    print("Gerado:", SAIDA)


if __name__ == "__main__":
    principal()
