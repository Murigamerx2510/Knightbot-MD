# -*- coding: utf-8 -*-
"""
Cultive um Jardim - gerador de modelos 3D para Blender (4.2 ou mais novo).

O que este script faz:
  1. Cria todos os modelos low-poly do jogo: plantas, frutos, sprinklers e ovos.
  2. Pinta tudo com uma unica textura de paleta (Paleta.png), que o Roblox importa.
  3. Exporta cada modelo como .fbx com o nome que o jogo procura
     (Planta_Carrot.fbx, Fruto_Apple.fbx, Sprinkler_BasicSprinkler.fbx, Ovo_CommonEgg.fbx...).
  4. Monta uma vitrine com todos os modelos, salva o .blend e renderiza uma imagem.

Como usar:
  - Pelo Blender: aba "Scripting" > Abrir este arquivo > Run Script (Alt+P).
  - Pelo terminal: blender --background --python gerar_modelos.py
  - Pasta de saida: "modelos_exportados" ao lado deste script
    (ou defina a variavel de ambiente JARDIM_SAIDA com outra pasta).

Depois, no Roblox Studio: Avatar/Home > Import 3D, importe os .fbx e coloque os modelos
dentro de ReplicatedStorage > Modelos. O jogo usa os modelos automaticamente.
"""

import math
import os

import bpy  # importar bpy antes de bmesh/mathutils (necessario no modulo bpy do pip)
import bmesh
from mathutils import Matrix, Vector

# Renderiza a imagem de previa so no modo terminal (no Blender aberto, aperte F12 se quiser)
RENDERIZAR_PREVIA = bpy.app.background and os.environ.get("JARDIM_SEM_RENDER", "") == ""

# (id, nome, tipo, altura, variasColheitas, maxFrutos, corFruto, corFolha, tamanhoFruto(x, altura, z))
# Mesmos valores de src/ReplicatedStorage/Shared/Config.luau
SEMENTES = [
    ("Carrot", "Cenoura", "root", 1.6, False, 1, (255, 140, 30), (70, 180, 60), (0.6, 1.2, 0.6)),
    ("Strawberry", "Morango", "bush", 1.8, True, 4, (225, 30, 55), (60, 160, 60), (0.5, 0.6, 0.5)),
    ("Blueberry", "Mirtilo", "bush", 2.0, True, 5, (60, 80, 210), (50, 140, 70), (0.45, 0.45, 0.45)),
    ("OrangeTulip", "Tulipa Laranja", "flower", 2.2, False, 1, (255, 130, 30), (70, 170, 60), (0.8, 0.9, 0.8)),
    ("Tomato", "Tomate", "bush", 2.6, True, 5, (235, 45, 30), (55, 150, 55), (0.75, 0.65, 0.75)),
    ("Daffodil", "Narciso", "flower", 2.4, False, 1, (255, 230, 60), (80, 170, 60), (0.9, 0.8, 0.9)),
    ("Corn", "Milho", "tall", 4.0, True, 3, (255, 220, 70), (90, 170, 50), (0.5, 1.3, 0.5)),
    ("Watermelon", "Melancia", "ground", 1.8, False, 1, (55, 150, 50), (70, 170, 60), (2.4, 1.8, 1.8)),
    ("Pumpkin", "Abóbora", "ground", 1.6, False, 1, (240, 130, 20), (70, 160, 50), (2.2, 1.6, 2.2)),
    ("Apple", "Maçã", "tree", 6.0, True, 6, (215, 30, 40), (60, 150, 50), (0.7, 0.7, 0.7)),
    ("Bamboo", "Bambu", "stalk", 5.0, False, 1, (130, 200, 80), (80, 170, 60), (0.55, 5.0, 0.55)),
    ("Coconut", "Coco", "palm", 7.0, True, 4, (115, 75, 45), (60, 170, 70), (1.0, 1.0, 1.0)),
    ("Cactus", "Cacto", "cactus", 4.0, True, 4, (235, 90, 150), (70, 150, 70), (0.65, 0.65, 0.65)),
    ("DragonFruit", "Pitaya", "cactus", 3.5, True, 4, (235, 40, 140), (90, 170, 80), (0.9, 1.1, 0.9)),
    ("Mango", "Manga", "tree", 7.0, True, 5, (255, 170, 40), (50, 140, 60), (0.8, 1.0, 0.8)),
    ("Mushroom", "Cogumelo", "mushroom", 2.2, False, 1, (205, 50, 50), (240, 230, 210), (2.0, 1.2, 2.0)),
    ("Grape", "Uva", "bush", 3.0, True, 5, (125, 40, 155), (70, 150, 60), (0.8, 1.05, 0.8)),
    ("Pepper", "Pimenta", "bush", 2.6, True, 5, (225, 20, 20), (60, 150, 50), (0.4, 1.0, 0.4)),
    ("Cacao", "Cacau", "tree", 6.0, True, 4, (150, 90, 40), (50, 130, 50), (0.7, 1.1, 0.7)),
    ("Beanstalk", "Pé de Feijão", "beanstalk", 10.0, True, 5, (100, 210, 70), (60, 170, 60), (0.5, 1.2, 0.5)),
]

SPRINKLERS = [
    ("BasicSprinkler", "Sprinkler Básico", (170, 170, 180)),
    ("AdvancedSprinkler", "Sprinkler Avançado", (80, 160, 230)),
    ("GodlySprinkler", "Sprinkler Divino", (255, 210, 60)),
    ("MasterSprinkler", "Sprinkler Mestre", (200, 90, 255)),
]

OVOS = [
    ("CommonEgg", "Ovo Comum", (240, 235, 220)),
    ("UncommonEgg", "Ovo Incomum", (150, 230, 140)),
    ("RareEgg", "Ovo Raro", (120, 170, 255)),
    ("LegendaryEgg", "Ovo Lendário", (255, 215, 70)),
]

CAULE = (85, 140, 60)
MADEIRA = (115, 78, 48)
BRANCO = (255, 255, 255)
PRETO = (25, 25, 25)
CINZA_ESCURO = (90, 90, 100)
CINZA = (150, 150, 160)


def escurecer(cor, fator=0.2):
    return tuple(int(c * (1 - fator)) for c in cor)


def clarear(cor, fator=0.08):
    return tuple(int(c + (255 - c) * fator) for c in cor)


# ---------------------------------------------------------------------------
# Pasta de saida
# ---------------------------------------------------------------------------

def pasta_saida():
    pasta = os.environ.get("JARDIM_SAIDA")
    if not pasta:
        base = ""
        arquivo = globals().get("__file__", "")
        if arquivo and os.path.isabs(arquivo) and os.path.exists(arquivo):
            base = os.path.dirname(arquivo)
        elif bpy.data.filepath:
            base = os.path.dirname(bpy.data.filepath)
        else:
            base = os.path.expanduser("~")
        pasta = os.path.join(base, "modelos_exportados")
    os.makedirs(pasta, exist_ok=True)
    return pasta


# ---------------------------------------------------------------------------
# Paleta de cores (uma textura pequena com quadradinhos coloridos)
# ---------------------------------------------------------------------------

class Paleta:
    CELULAS = 16  # 16 x 16 = 256 cores
    PIXELS_POR_CELULA = 8

    def __init__(self):
        self.cores = []

    def indice(self, cor):
        cor = tuple(int(c) for c in cor)
        if cor not in self.cores:
            if len(self.cores) >= self.CELULAS * self.CELULAS:
                raise RuntimeError("Paleta cheia: aumente Paleta.CELULAS")
            self.cores.append(cor)
        return self.cores.index(cor)

    def uv(self, cor):
        i = self.indice(cor)
        coluna = i % self.CELULAS
        linha = i // self.CELULAS
        return ((coluna + 0.5) / self.CELULAS, 1.0 - (linha + 0.5) / self.CELULAS)

    def criar_imagem(self, caminho):
        lado = self.CELULAS * self.PIXELS_POR_CELULA
        imagem = bpy.data.images.get("Paleta")
        if imagem:
            bpy.data.images.remove(imagem)
        imagem = bpy.data.images.new("Paleta", width=lado, height=lado, alpha=False)
        pixels = [1.0] * (lado * lado * 4)
        for i, cor in enumerate(self.cores):
            coluna = i % self.CELULAS
            linha = i // self.CELULAS
            for py in range(self.PIXELS_POR_CELULA):
                for px in range(self.PIXELS_POR_CELULA):
                    x = coluna * self.PIXELS_POR_CELULA + px
                    # a linha 0 fica no topo da imagem (v = 1)
                    y = lado - 1 - (linha * self.PIXELS_POR_CELULA + py)
                    k = (y * lado + x) * 4
                    pixels[k:k + 4] = [cor[0] / 255.0, cor[1] / 255.0, cor[2] / 255.0, 1.0]
        imagem.pixels = pixels
        imagem.filepath_raw = caminho
        imagem.file_format = "PNG"
        imagem.save()
        return imagem


PALETA = Paleta()


def criar_material(imagem):
    material = bpy.data.materials.get("Paleta") or bpy.data.materials.new("Paleta")
    material.use_nodes = True
    nos = material.node_tree.nodes
    ligacoes = material.node_tree.links
    nos.clear()
    saida = nos.new("ShaderNodeOutputMaterial")
    saida.location = (400, 0)
    bsdf = nos.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (100, 0)
    bsdf.inputs["Roughness"].default_value = 0.75
    textura = nos.new("ShaderNodeTexImage")
    textura.location = (-300, 0)
    textura.image = imagem
    textura.interpolation = "Closest"
    ligacoes.new(textura.outputs["Color"], bsdf.inputs["Base Color"])
    ligacoes.new(bsdf.outputs["BSDF"], saida.inputs["Surface"])
    return material


# ---------------------------------------------------------------------------
# Construcao das malhas
# ---------------------------------------------------------------------------

def T(x, y, z):
    return Matrix.Translation((x, y, z))


def Rx(graus):
    return Matrix.Rotation(math.radians(graus), 4, "X")


def Ry(graus):
    return Matrix.Rotation(math.radians(graus), 4, "Y")


def Rz(graus):
    return Matrix.Rotation(math.radians(graus), 4, "Z")


def tamanho(sx, sy, sz):
    return Matrix.Diagonal((sx, sy, sz, 1.0))


class Modelo:
    """Um modelo = varios objetos (cada um vira uma MeshPart no Roblox)."""

    def __init__(self, nome):
        self.nome = nome
        self.malhas = {}  # nome do objeto -> bmesh
        self.ordem = []

    def _bm(self, objeto):
        if objeto not in self.malhas:
            self.malhas[objeto] = bmesh.new()
            self.ordem.append(objeto)
        return self.malhas[objeto]

    def adicionar(self, objeto, forma, matriz, escala, cor, segmentos=12):
        """forma: 'esfera', 'cilindro', 'cubo' ou 'cone'. A forma base tem tamanho 1."""
        bm = self._bm(objeto)
        if forma == "esfera":
            resultado = bmesh.ops.create_uvsphere(bm, u_segments=segmentos, v_segments=max(4, segmentos // 2 + 1), radius=0.5)
        elif forma == "cilindro":
            resultado = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segmentos, radius1=0.5, radius2=0.5, depth=1.0)
        elif forma == "cone":
            resultado = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segmentos, radius1=0.5, radius2=0.0, depth=1.0)
        else:
            resultado = bmesh.ops.create_cube(bm, size=1.0)
        vertices = resultado["verts"]
        bmesh.ops.transform(bm, matrix=matriz @ tamanho(*escala), verts=vertices)
        camada = bm.loops.layers.uv.verify()
        u, v = PALETA.uv(cor)
        faces = set()
        for vertice in vertices:
            faces.update(vertice.link_faces)
        for face in faces:
            face.smooth = False
            for loop in face.loops:
                loop[camada].uv = (u, v)

    def finalizar(self, colecao, material):
        # nomes unicos (ex.: Corpo_Carrot), senao o Blender renomeia para "Corpo.001"
        sufixo = self.nome.split("_", 1)[-1]
        objetos = []
        for nome_parte in self.ordem:
            bm = self.malhas[nome_parte]
            nome_objeto = nome_parte if nome_parte.startswith("Produto") or nome_parte == sufixo else nome_parte + "_" + sufixo
            malha = bpy.data.meshes.new(nome_objeto)
            bm.to_mesh(malha)
            bm.free()
            malha.materials.append(material)
            objeto = bpy.data.objects.new(nome_objeto, malha)
            colecao.objects.link(objeto)
            objetos.append(objeto)
        return objetos


# Altura = eixo Z no Blender. tamanhoFruto vem como (x, altura, z) do Roblox.
def fruto_blender(fs):
    return (fs[0], fs[2], fs[1])


def planta_root(m, s):
    h, fs = s["altura"], fruto_blender(s["fruto"])
    m.adicionar("Produto_" + s["id"], "esfera", T(0, 0, fs[2] * 0.15), fs, s["corFruto"])
    for i in range(3):
        matriz = T(0, 0, fs[2] * 0.55) @ Rz(i * 120) @ Rx(18) @ T(0, 0, h * 0.3)
        m.adicionar("Corpo", "cubo", matriz, (0.15, 0.4, h * 0.6), s["corFolha"])


def planta_bush(m, s):
    h = s["altura"]
    m.adicionar("Corpo", "cilindro", T(0, 0, h * 0.15), (0.25, 0.25, h * 0.3), CAULE, 8)
    m.adicionar("Corpo", "esfera", T(0, 0, h * 0.5), (h * 0.85, h * 0.85, h * 0.65), s["corFolha"], 10)
    m.adicionar("Corpo", "esfera", T(h * 0.2, h * 0.1, h * 0.72), (h * 0.5, h * 0.5, h * 0.45), clarear(s["corFolha"]), 10)
    m.adicionar("Corpo", "esfera", T(-h * 0.22, -h * 0.15, h * 0.62), (h * 0.45, h * 0.45, h * 0.4), clarear(s["corFolha"], 0.04), 10)


def planta_flower(m, s):
    h, fs = s["altura"], fruto_blender(s["fruto"])
    m.adicionar("Corpo", "cilindro", T(0, 0, h * 0.375), (0.18, 0.18, h * 0.75), CAULE, 8)
    for i in range(2):
        matriz = T(0, 0, h * 0.12) @ Rz(i * 180) @ Rx(25) @ T(0, 0, h * 0.18)
        m.adicionar("Corpo", "cubo", matriz, (0.12, 0.5, h * 0.4), s["corFolha"])
    topo = h * 0.75 + fs[2] * 0.4
    m.adicionar("Produto_" + s["id"], "esfera", T(0, 0, topo), (fs[0] * 0.8, fs[1] * 0.8, fs[2] * 0.8), s["corFruto"], 10)
    for i in range(5):
        matriz = T(0, 0, topo) @ Rz(i * 72) @ T(0, fs[1] * 0.32, 0) @ Rx(15)
        m.adicionar("Produto_" + s["id"], "esfera", matriz, (fs[0] * 0.55, fs[1] * 0.3, fs[2]), s["corFruto"], 8)


def planta_tall(m, s):
    h = s["altura"]
    m.adicionar("Corpo", "cilindro", T(0, 0, h / 2), (0.35, 0.35, h), escurecer(s["corFolha"], 0.15), 8)
    for i in range(1, 5):
        matriz = T(0, 0, h * (0.25 + 0.12 * i)) @ Rz(i * 97) @ Rx(40) @ T(0, 0, h * 0.2)
        m.adicionar("Corpo", "cubo", matriz, (0.1, 0.45, h * 0.42), s["corFolha"])
    m.adicionar("Corpo", "cone", T(0, 0, h + 0.3), (0.35, 0.35, 0.7), (230, 200, 120), 6)


def planta_ground(m, s):
    fs = fruto_blender(s["fruto"])
    m.adicionar("Produto_" + s["id"], "esfera", T(0, 0, fs[2] / 2), fs, s["corFruto"], 14)
    if s["id"] == "Watermelon":
        for i in range(6):
            matriz = T(0, 0, fs[2] / 2) @ Rx(i * 30)
            m.adicionar("Produto_" + s["id"], "esfera", matriz, (fs[0] * 1.01, fs[1] * 0.12, fs[2] * 1.01), escurecer(s["corFruto"], 0.35), 14)
    m.adicionar("Corpo", "cilindro", T(0, 0, fs[2] + 0.15), (0.22, 0.22, 0.5), (100, 120, 50), 6)
    for i in range(3):
        matriz = Rz(i * 120) @ T(fs[0] * 0.6, 0, 0.1)
        m.adicionar("Corpo", "esfera", matriz, (1.4, 1.0, 0.15), s["corFolha"], 8)


def planta_tree(m, s):
    h = s["altura"]
    m.adicionar("Corpo", "cilindro", T(0, 0, h * 0.275), (h * 0.11, h * 0.11, h * 0.55), MADEIRA, 8)
    m.adicionar("Corpo", "esfera", T(0, 0, h * 0.68), (h * 0.75, h * 0.75, h * 0.55), s["corFolha"], 12)
    m.adicionar("Corpo", "esfera", T(h * 0.22, 0, h * 0.82), (h * 0.45, h * 0.45, h * 0.4), clarear(s["corFolha"], 0.07), 10)
    m.adicionar("Corpo", "esfera", T(-h * 0.2, -h * 0.15, h * 0.78), (h * 0.42, h * 0.42, h * 0.38), clarear(s["corFolha"], 0.03), 10)


def planta_stalk(m, s):
    fs = fruto_blender(s["fruto"])
    segmentos = 4
    altura_segmento = fs[2] / segmentos
    for i in range(segmentos):
        m.adicionar("Produto_" + s["id"], "cilindro", T(0, 0, altura_segmento * (i + 0.5)), (fs[0], fs[0], altura_segmento * 0.95), s["corFruto"], 8)
        m.adicionar("Produto_" + s["id"], "cilindro", T(0, 0, altura_segmento * (i + 1)), (fs[0] * 1.15, fs[0] * 1.15, 0.12), escurecer(s["corFruto"]), 8)
    for i in range(3):
        matriz = T(0, 0, fs[2] * 0.85) @ Rz(i * 120) @ Rx(55) @ T(0, 0, 0.6)
        m.adicionar("Corpo", "cubo", matriz, (0.08, 0.35, 1.2), s["corFolha"])


def planta_palm(m, s):
    h = s["altura"]
    topo = h * 0.85
    for i in range(5):
        cor = clarear(MADEIRA, 0.08) if i % 2 else MADEIRA
        largura = 0.55 - (i + 1) * 0.03
        m.adicionar("Corpo", "cilindro", T(0, 0, topo / 5 * (i + 0.5)), (largura, largura, topo / 5 * 1.02), cor, 8)
    for i in range(6):
        matriz = T(0, 0, topo) @ Rz(i * 60) @ Rx(-25) @ T(0, h * 0.2, 0)
        m.adicionar("Corpo", "cubo", matriz, (0.9, h * 0.42, 0.12), s["corFolha"])


def planta_cactus(m, s):
    h, cor = s["altura"], s["corFolha"]
    m.adicionar("Corpo", "cilindro", T(0, 0, h * 0.375), (h * 0.25, h * 0.25, h * 0.75), cor, 10)
    m.adicionar("Corpo", "esfera", T(0, 0, h * 0.75), (h * 0.25, h * 0.25, h * 0.25), cor, 10)
    for lado in (1, -1):
        altura_braco = h * 0.4 if lado == 1 else h * 0.5
        m.adicionar("Corpo", "cilindro", T(lado * h * 0.17, 0, altura_braco) @ Ry(90), (h * 0.13, h * 0.13, h * 0.18), cor, 8)
        m.adicionar("Corpo", "cilindro", T(lado * h * 0.25, 0, altura_braco + h * 0.1), (h * 0.13, h * 0.13, h * 0.22), cor, 8)
        m.adicionar("Corpo", "esfera", T(lado * h * 0.25, 0, altura_braco + h * 0.21), (h * 0.13, h * 0.13, h * 0.13), cor, 8)


def planta_mushroom(m, s):
    h, fs = s["altura"], fruto_blender(s["fruto"])
    m.adicionar("Corpo", "cilindro", T(0, 0, h * 0.25), (0.7, 0.7, h * 0.5), s["corFolha"], 10)
    topo = h * 0.5 + fs[2] * 0.25
    m.adicionar("Produto_" + s["id"], "esfera", T(0, 0, topo), fs, s["corFruto"], 14)
    for i in range(5):
        matriz = T(0, 0, topo) @ Rz(i * 72) @ Rx(35) @ T(0, 0, fs[2] * 0.46)
        m.adicionar("Corpo", "esfera", matriz, (0.35, 0.35, 0.12), BRANCO, 8)


def planta_beanstalk(m, s):
    h = s["altura"]
    segmentos = 8
    altura_segmento = h / segmentos
    for i in range(1, segmentos + 1):
        x, y = math.cos(i * 0.8) * 0.3, math.sin(i * 0.8) * 0.3
        m.adicionar("Corpo", "cilindro", T(x, y, altura_segmento * (i - 0.5)), (0.5, 0.5, altura_segmento * 1.1), escurecer(s["corFolha"], 0.1), 8)
        matriz = T(x, y, altura_segmento * (i - 0.3)) @ Rz(i * 109) @ T(0.6, 0, 0)
        m.adicionar("Corpo", "esfera", matriz, (1.0, 0.6, 0.12), s["corFolha"], 8)
    for i in range(4):
        matriz = T(0, 0, h + 0.4) @ Rz(i * 90) @ T(0.7, 0, 0)
        m.adicionar("Corpo", "esfera", matriz, (1.4, 1.2, 0.9), BRANCO, 10)


CONSTRUTORES = {
    "root": planta_root,
    "bush": planta_bush,
    "flower": planta_flower,
    "tall": planta_tall,
    "ground": planta_ground,
    "tree": planta_tree,
    "stalk": planta_stalk,
    "palm": planta_palm,
    "cactus": planta_cactus,
    "mushroom": planta_mushroom,
    "beanstalk": planta_beanstalk,
}


def construir_fruto(m, s):
    fs = fruto_blender(s["fruto"])
    nome = "Produto_" + s["id"]
    if s["id"] == "Grape":
        # cacho de uvas
        for camada, quantidade in enumerate((4, 3, 2, 1)):
            for i in range(quantidade):
                angulo = i * (360 / quantidade) + camada * 30
                raio = 0.12 * quantidade
                matriz = T(0, 0, fs[2] * (0.3 - camada * 0.2)) @ Rz(angulo) @ T(raio, 0, 0)
                m.adicionar(nome, "esfera", matriz, (0.3, 0.3, 0.3), s["corFruto"], 8)
    elif s["id"] == "Strawberry":
        m.adicionar(nome, "cone", T(0, 0, -fs[2] * 0.1) @ Rx(180), (fs[0], fs[1], fs[2] * 0.8), s["corFruto"], 10)
        m.adicionar(nome, "esfera", T(0, 0, fs[2] * 0.25), (fs[0], fs[1], fs[2] * 0.45), s["corFruto"], 10)
    else:
        m.adicionar(nome, "esfera", Matrix.Identity(4), fs, s["corFruto"], 12)
    m.adicionar("Cabo", "cilindro", T(0, 0, fs[2] / 2 + 0.08), (0.1, 0.1, 0.25), CAULE, 6)
    for i in range(3):
        matriz = T(0, 0, fs[2] / 2) @ Rz(i * 120) @ Rx(70) @ T(0, 0, 0.1)
        m.adicionar("Cabo", "cubo", matriz, (0.05, 0.12, 0.25), CAULE)


def construir_sprinkler(m, cor):
    m.adicionar("Base", "cilindro", T(0, 0, 0.2), (1.4, 1.4, 0.4), CINZA_ESCURO, 12)
    m.adicionar("Cano", "cilindro", T(0, 0, 1.0), (0.3, 0.3, 1.6), CINZA, 8)
    m.adicionar("Cabeca", "esfera", T(0, 0, 1.9), (0.8, 0.8, 0.8), cor, 12)
    for i in range(4):
        m.adicionar("Cabeca", "cubo", T(0, 0, 1.95) @ Rz(i * 90) @ T(0.45, 0, 0), (0.35, 0.12, 0.12), cor)


def construir_ovo(m, cor):
    m.adicionar("Casca", "esfera", T(0, 0, 1.0), (1.6, 1.6, 2.0), cor, 16)
    for i in range(4):
        matriz = T(0, 0, 1.0) @ Rz(i * 90) @ Rx(20 * (i % 2)) @ T(0, 0.72, 0.1)
        m.adicionar("Casca", "esfera", matriz, (0.4, 0.15, 0.4), escurecer(cor, 0.25), 8)


# ---------------------------------------------------------------------------
# Cena, exportacao e previa
# ---------------------------------------------------------------------------

def preparar_cena():
    """No terminal comeca do zero; no Blender aberto cria uma cena nova (nao apaga o seu trabalho)."""
    if bpy.app.background:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        return bpy.context.scene
    cena = bpy.data.scenes.new("CultiveUmJardim")
    if bpy.context.window:
        bpy.context.window.scene = cena
    return cena


def garantir_fbx():
    if not hasattr(bpy.ops.export_scene, "fbx"):
        try:
            bpy.ops.preferences.addon_enable(module="io_scene_fbx")
        except Exception as erro:  # noqa: BLE001
            print("Nao foi possivel ativar o exportador FBX:", erro)


def exportar_fbx(objetos, caminho):
    bpy.ops.object.select_all(action="DESELECT")
    for objeto in objetos:
        objeto.select_set(True)
    bpy.context.view_layer.objects.active = objetos[0]
    bpy.ops.export_scene.fbx(
        filepath=caminho,
        use_selection=True,
        object_types={"MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_UNITS",
        axis_forward="-Z",
        axis_up="Y",
        mesh_smooth_type="FACE",
        path_mode="COPY",
        embed_textures=True,
    )


def mover(objetos, deslocamento):
    for objeto in objetos:
        objeto.location = Vector(objeto.location) + Vector(deslocamento)


def montar_vitrine(cena, colecao, material):
    # chao de grama e canteiros de terra para a imagem de previa
    chao = Modelo("Chao")
    chao.adicionar("Chao", "cubo", T(14, 9, -0.25), (60, 40, 0.5), (95, 170, 70))
    for linha in range(3):
        chao.adicionar("Chao", "cubo", T(14, linha * 7, 0.02), (52, 4.5, 0.1), (125, 82, 50))
    chao.finalizar(colecao, material)

    camera_dados = bpy.data.cameras.new("Camera")
    camera = bpy.data.objects.new("Camera", camera_dados)
    colecao.objects.link(camera)
    camera.location = (14, -19, 15)
    camera.rotation_euler = (math.radians(57), 0, 0)
    camera_dados.lens = 24
    cena.camera = camera

    sol_dados = bpy.data.lights.new("Sol", type="SUN")
    sol_dados.energy = 3.5
    sol = bpy.data.objects.new("Sol", sol_dados)
    sol.rotation_euler = (math.radians(45), math.radians(10), math.radians(30))
    colecao.objects.link(sol)

    mundo = bpy.data.worlds.new("Ceu")
    mundo.use_nodes = True
    fundo = mundo.node_tree.nodes.get("Background")
    if fundo:
        fundo.inputs["Color"].default_value = (0.55, 0.75, 1.0, 1.0)
        fundo.inputs["Strength"].default_value = 0.9
    cena.world = mundo


def renderizar(cena, caminho):
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 24
    cena.cycles.use_denoising = False
    cena.render.resolution_x = 1280
    cena.render.resolution_y = 720
    cena.render.filepath = caminho
    cena.render.image_settings.file_format = "JPEG"
    cena.render.image_settings.quality = 90
    bpy.ops.render.render(write_still=True)


def principal():
    cena = preparar_cena()
    garantir_fbx()
    saida = pasta_saida()
    pasta_fbx = os.path.join(saida, "fbx")
    os.makedirs(pasta_fbx, exist_ok=True)

    sementes = [
        dict(id=i, nome=n, tipo=t, altura=h, multi=mu, maxFrutos=mf, corFruto=cf, corFolha=cl, fruto=fs)
        for (i, n, t, h, mu, mf, cf, cl, fs) in SEMENTES
    ]

    # 1) monta todos os modelos na origem (as cores ja vao para a paleta)
    modelos = []  # (nomeDoArquivo, Modelo, posicaoNaVitrine)
    for indice, s in enumerate(sementes):
        planta = Modelo("Planta_" + s["id"])
        CONSTRUTORES[s["tipo"]](planta, s)
        coluna, linha = indice % 10, indice // 10
        modelos.append((planta.nome, planta, (coluna * 3.2, linha * 7, 0.07)))
        if s["multi"]:
            fruto = Modelo("Fruto_" + s["id"])
            construir_fruto(fruto, s)
            modelos.append((fruto.nome, fruto, (coluna * 3.2, linha * 7 - 2.2, 0.8)))
    for indice, (sid, _nome, cor) in enumerate(SPRINKLERS):
        sprinkler = Modelo("Sprinkler_" + sid)
        construir_sprinkler(sprinkler, cor)
        modelos.append((sprinkler.nome, sprinkler, (indice * 3, 14, 0.07)))
    for indice, (oid, _nome, cor) in enumerate(OVOS):
        ovo = Modelo("Ovo_" + oid)
        construir_ovo(ovo, cor)
        modelos.append((ovo.nome, ovo, (16 + indice * 3, 14, 0.07)))

    # 2) cria a textura de paleta e o material
    for cor in [(95, 170, 70), (125, 82, 50)]:
        PALETA.indice(cor)
    imagem = PALETA.criar_imagem(os.path.join(pasta_fbx, "Paleta.png"))
    material = criar_material(imagem)

    # 3) cria os objetos, exporta cada modelo e move para a vitrine
    for nome_arquivo, modelo, posicao in modelos:
        colecao = bpy.data.collections.new(nome_arquivo)
        cena.collection.children.link(colecao)
        objetos = modelo.finalizar(colecao, material)
        bpy.context.view_layer.update()
        exportar_fbx(objetos, os.path.join(pasta_fbx, nome_arquivo + ".fbx"))
        mover(objetos, posicao)
        print("Exportado:", nome_arquivo)

    vitrine = bpy.data.collections.new("Vitrine")
    cena.collection.children.link(vitrine)
    montar_vitrine(cena, vitrine, material)

    caminho_blend = os.path.join(saida, "CultiveUmJardim_Modelos.blend")
    imagem.pack()
    # copy=True: salva uma copia sem trocar o arquivo que voce esta editando
    bpy.ops.wm.save_as_mainfile(filepath=caminho_blend, copy=not bpy.app.background)
    print("Arquivo .blend salvo em:", caminho_blend)

    if RENDERIZAR_PREVIA:
        renderizar(cena, os.path.join(saida, "previa_modelos.jpg"))
        print("Previa renderizada.")

    print("Pronto! %d modelos exportados para %s" % (len(modelos), pasta_fbx))


if __name__ == "__main__":
    principal()
