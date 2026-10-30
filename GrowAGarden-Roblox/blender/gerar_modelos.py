# -*- coding: utf-8 -*-
"""
Cultive um Jardim - gerador de modelos 3D para Blender (4.2 ou mais novo).

O que este script faz:
  1. Cria todos os modelos low-poly do jogo: as 45 plantas, os frutos de todas as plantas
     de varias colheitas, os 5 sprinklers, os 6 ovos, o Gnomo e a Lanterna.
  2. Pinta tudo com uma unica textura de paleta (Paleta.png), que o Roblox importa.
  3. Exporta cada modelo como .fbx com o nome que o jogo procura
     (Planta_Carrot.fbx, Fruto_Apple.fbx, Sprinkler_CommonSprinkler.fbx, Ovo_CommonEgg.fbx,
     Gnomo.fbx, Lanterna.fbx...).
  4. Monta uma vitrine com todos os modelos, salva o .blend e renderiza imagens de previa.

Como usar:
  - Pelo Blender: aba "Scripting" > Abrir este arquivo > Run Script (Alt+P).
  - Pelo terminal: blender --background --python gerar_modelos.py
  - Pasta de saida: "modelos_exportados" ao lado deste script
    (ou defina a variavel de ambiente JARDIM_SAIDA com outra pasta).

Depois, no Roblox Studio: Avatar/Home > Import 3D, importe os .fbx e coloque os modelos
dentro de ReplicatedStorage > Modelos. O jogo usa os modelos automaticamente:
  - partes "Produto" sao o fruto: ficam verdes antes de amadurecer e mudam de cor com
    variantes e mutacoes (a textura volta quando o fruto esta maduro);
  - a parte "Brilho" ganha luz (centro das flores magicas, cogumelos, brasas);
  - a "Copa" da Cerejeira solta petalas.
"""

import math
import os

import bpy  # importar bpy antes de bmesh/mathutils (necessario no modulo bpy do pip)
import bmesh
from mathutils import Matrix, Vector

# Renderiza as imagens de previa so no modo terminal (no Blender aberto, aperte F12 se quiser)
RENDERIZAR_PREVIA = bpy.app.background and os.environ.get("JARDIM_SEM_RENDER", "") == ""

# (id, nome, tipo, altura, variasColheitas, maxFrutos, corFruto, corFolha, tamanhoFruto(x, altura, z), extras)
# Mesmos valores de src/ReplicatedStorage/Shared/Config.luau
SEMENTES = [
    ("Carrot", "Cenoura", "root", 1.6, False, 1, (255, 140, 30), (70, 180, 60), (0.6, 1.2, 0.6), ()),
    ("Strawberry", "Morango", "bush", 1.8, True, 4, (225, 30, 55), (60, 160, 60), (0.5, 0.6, 0.5), ()),
    ("Blueberry", "Mirtilo", "bush", 2.0, True, 5, (60, 80, 210), (50, 140, 70), (0.45, 0.45, 0.45), ()),
    ("Tulip", "Tulipa", "flower", 2.2, False, 1, (240, 70, 110), (70, 170, 60), (0.8, 0.9, 0.8), ()),
    ("Tomato", "Tomate", "bush", 2.6, True, 5, (235, 45, 30), (55, 150, 55), (0.75, 0.65, 0.75), ()),
    ("Apple", "Maçã", "tree", 6.0, True, 6, (215, 30, 40), (60, 150, 50), (0.7, 0.7, 0.7), ()),
    ("Bamboo", "Bambu", "stalk", 5.0, False, 1, (130, 200, 80), (80, 170, 60), (0.55, 5, 0.55), ()),
    ("Daffodil", "Narciso", "flower", 2.4, False, 1, (255, 230, 60), (80, 170, 60), (0.9, 0.8, 0.9), ()),
    ("Corn", "Milho", "tall", 4.0, True, 4, (255, 220, 70), (90, 170, 50), (0.5, 1.3, 0.5), ()),
    ("Cactus", "Cacto", "cactus", 4.0, True, 4, (235, 90, 150), (70, 150, 70), (0.65, 0.65, 0.65), ()),
    ("Pineapple", "Abacaxi", "pineapple", 2.4, True, 3, (240, 190, 40), (60, 150, 60), (0.8, 1.1, 0.8), ()),
    ("Banana", "Banana", "palm", 6.0, True, 5, (250, 220, 60), (70, 170, 70), (0.45, 1.2, 0.45), ()),
    ("Grape", "Uva", "vine", 3.0, True, 5, (125, 40, 155), (70, 150, 60), (0.8, 1.05, 0.8), ()),
    ("Watermelon", "Melancia", "ground", 1.8, False, 1, (55, 150, 50), (70, 170, 60), (2.4, 1.8, 1.8), ()),
    ("GlowMushroom", "Cogumelo Brilhante", "glowshroom", 2.0, True, 4, (90, 230, 255), (240, 230, 210), (0.5, 0.5, 0.5), ()),
    ("Pumpkin", "Abóbora", "ground", 1.6, False, 1, (240, 130, 20), (70, 160, 50), (2.2, 1.6, 2.2), ()),
    ("GreenBean", "Feijão Verde", "vine", 3.2, True, 6, (90, 190, 60), (60, 150, 50), (0.35, 1.1, 0.35), ()),
    ("Mushroom", "Cogumelo", "mushroom", 2.2, False, 1, (205, 50, 50), (240, 230, 210), (2, 1.2, 2), ()),
    ("Coconut", "Coco", "palm", 7.0, True, 4, (115, 75, 45), (60, 170, 70), (1, 1, 1), ()),
    ("Mango", "Manga", "tree", 7.0, True, 5, (255, 170, 40), (50, 140, 60), (0.8, 1, 0.8), ()),
    ("DragonFruit", "Pitaya", "cactus", 3.5, True, 4, (235, 40, 140), (90, 170, 80), (0.9, 1.1, 0.9), ()),
    ("Cherry", "Cereja", "tree", 5.5, True, 6, (200, 20, 40), (60, 150, 60), (0.5, 0.5, 0.5), ()),
    ("Acorn", "Bolota", "tree", 7.0, True, 5, (150, 100, 50), (70, 130, 50), (0.55, 0.7, 0.55), ()),
    ("PoisonIvy", "Hera Venenosa", "vine", 3.0, True, 4, (150, 230, 60), (50, 120, 40), (0.5, 0.5, 0.5), ()),
    ("FireFern", "Samambaia de Fogo", "fern", 2.6, True, 4, (255, 110, 30), (210, 80, 30), (0.55, 0.55, 0.55), ()),
    ("CherryBlossom", "Cerejeira", "blossom", 6.5, True, 6, (255, 160, 200), (255, 185, 215), (0.7, 0.6, 0.7), ("petals",)),
    ("Sunflower", "Girassol", "sunflower", 5.0, True, 3, (250, 210, 40), (70, 160, 60), (0.9, 0.9, 0.5), ()),
    ("RocketPop", "Picolé Foguete", "popsicle", 2.4, False, 1, (230, 40, 50), (80, 170, 70), (0.7, 1.6, 0.4), ()),
    ("VenusFlyTrap", "Dioneia", "flytrap", 3.0, True, 3, (220, 40, 60), (90, 180, 60), (0.6, 0.6, 0.6), ()),
    ("Pepper", "Pimenta", "bush", 2.6, True, 5, (225, 20, 20), (60, 150, 50), (0.4, 1, 0.4), ()),
    ("Pomegranate", "Romã", "tree", 6.0, True, 5, (190, 30, 50), (60, 140, 60), (0.75, 0.75, 0.75), ()),
    ("PoisonApple", "Maçã Envenenada", "tree", 6.0, True, 4, (120, 40, 160), (40, 90, 50), (0.7, 0.7, 0.7), ()),
    ("VenomSpitter", "Cuspidor de Veneno", "spitter", 3.0, True, 3, (130, 230, 50), (60, 130, 50), (0.7, 0.7, 0.7), ()),
    ("Cacao", "Cacau", "tree", 6.0, True, 4, (150, 90, 40), (50, 130, 50), (0.7, 1.1, 0.7), ()),
    ("GhostPepper", "Pimenta Fantasma", "bush", 2.6, True, 5, (235, 235, 245), (90, 120, 110), (0.4, 1, 0.4), ("ghostly",)),
    ("RainbowSeed", "Semente Arco-íris", "bloom", 3.0, True, 4, (255, 120, 220), (80, 170, 80), (0.7, 0.7, 0.7), ("rainbowPetals",)),
    ("MoonBloom", "Flor da Lua", "bloom", 4.0, True, 3, (170, 200, 255), (60, 120, 140), (0.9, 0.9, 0.9), ("glow",)),
    ("DragonsBreath", "Sopro do Dragão", "spitter", 3.6, True, 3, (255, 80, 20), (160, 40, 30), (0.8, 0.8, 0.8), ()),
    ("SunBloom", "Flor do Sol", "bloom", 4.2, True, 3, (255, 200, 40), (90, 160, 60), (0.9, 0.9, 0.9), ("glow",)),
    ("HypnoBloom", "Flor Hipnótica", "bloom", 4.0, True, 3, (200, 90, 255), (90, 60, 140), (0.85, 0.85, 0.85), ("glow",)),
    ("Beanstalk", "Pé de Feijão", "beanstalk", 10.0, True, 5, (100, 210, 70), (60, 170, 60), (0.5, 1.2, 0.5), ()),
    ("StarFruit", "Carambola", "tree", 6.5, True, 4, (255, 230, 80), (70, 160, 90), (0.7, 0.9, 0.7), ()),
    ("EclipseBloom", "Flor do Eclipse", "bloom", 4.5, True, 3, (90, 60, 140), (40, 30, 60), (0.95, 0.95, 0.95), ("glow",)),
    ("InfernoPepper", "Pimenta Infernal", "bush", 2.8, True, 5, (255, 60, 20), (120, 40, 30), (0.45, 1.05, 0.45), ()),
    ("GalaxyFruit", "Fruta Galáctica", "tree", 6.5, True, 4, (80, 60, 200), (40, 40, 90), (0.8, 0.8, 0.8), ("glow",)),
]

# (id, nome, cor, nivel) - quanto maior o nivel, mais enfeitado
SPRINKLERS = [
    ("CommonSprinkler", "Sprinkler Comum", (170, 170, 180), 1),
    ("UncommonSprinkler", "Sprinkler Incomum", (90, 210, 90), 2),
    ("RareSprinkler", "Sprinkler Raro", (80, 160, 230), 3),
    ("LegendarySprinkler", "Sprinkler Lendário", (255, 210, 60), 4),
    ("SuperSprinkler", "Sprinkler Super", (255, 120, 40), 5),
]

# (id, nome, cor) - o nivel e a posicao na lista
OVOS = [
    ("CommonEgg", "Ovo Comum", (240, 235, 220)),
    ("UncommonEgg", "Ovo Incomum", (150, 230, 140)),
    ("RareEgg", "Ovo Raro", (120, 170, 255)),
    ("LegendaryEgg", "Ovo Lendário", (255, 215, 70)),
    ("MythicEgg", "Ovo Mítico", (255, 110, 180)),
    ("SuperEgg", "Ovo Super", (255, 140, 50)),
]

CAULE = (85, 140, 60)
MADEIRA = (115, 78, 48)
BRANCO = (255, 255, 255)
PRETO = (25, 25, 25)
CINZA_ESCURO = (90, 90, 100)
CINZA = (150, 150, 160)
CREME = (245, 240, 200)
OURO = (255, 205, 40)
FOLHA = (70, 160, 60)
GRAMA = (95, 170, 70)
TERRA = (125, 82, 50)
ARCO_IRIS = [(255, 70, 70), (255, 160, 50), (255, 230, 60), (90, 220, 90), (70, 150, 255), (170, 90, 255)]


def escurecer(cor, fator=0.2):
    return tuple(int(c * (1 - fator)) for c in cor)


def clarear(cor, fator=0.08):
    return tuple(int(c + (255 - c) * fator) for c in cor)


def misturar(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tom(cor, quanto):
    """quanto > 0 clareia, quanto < 0 escurece."""
    return clarear(cor, quanto) if quanto >= 0 else escurecer(cor, -quanto)


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
    CELULAS = 32  # 32 x 32 = 1024 cores
    PIXELS_POR_CELULA = 8

    def __init__(self):
        self.cores = []
        self.posicoes = {}

    def indice(self, cor):
        cor = tuple(int(c) for c in cor)
        if cor not in self.posicoes:
            if len(self.cores) >= self.CELULAS * self.CELULAS:
                raise RuntimeError("Paleta cheia: aumente Paleta.CELULAS")
            self.posicoes[cor] = len(self.cores)
            self.cores.append(cor)
        return self.posicoes[cor]

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
            valor = [cor[0] / 255.0, cor[1] / 255.0, cor[2] / 255.0, 1.0]
            for py in range(self.PIXELS_POR_CELULA):
                # a linha 0 fica no topo da imagem (v = 1)
                y = lado - 1 - (linha * self.PIXELS_POR_CELULA + py)
                inicio = (y * lado + coluna * self.PIXELS_POR_CELULA) * 4
                pixels[inicio:inicio + self.PIXELS_POR_CELULA * 4] = valor * self.PIXELS_POR_CELULA
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
# Matrizes e direcoes (no Blender a altura e o eixo Z)
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


def alinhar_z(direcao_z):
    """Rotacao que leva o eixo Z local para a direcao dada (o eixo X local fica na horizontal)."""
    z = Vector(direcao_z).normalized()
    referencia = Vector((0.0, 0.0, 1.0)) if abs(z.z) < 0.999 else Vector((0.0, 1.0, 0.0))
    x = referencia.cross(z).normalized()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed().to_4x4()


def olhar(frente, cima=(0.0, 0.0, 1.0)):
    """Rotacao com o eixo Y local para a frente e o eixo Z local para cima."""
    f = Vector(frente).normalized()
    direita = f.cross(Vector(cima))
    if direita.length < 1e-6:
        direita = Vector((1.0, 0.0, 0.0))
    direita.normalize()
    acima = direita.cross(f)
    return Matrix((direita, f, acima)).transposed().to_4x4()


def direcao(azimute, inclinacao):
    """Direcao pelo azimute (graus, no plano do chao) e inclinacao (graus a partir da vertical)."""
    a, t = math.radians(azimute), math.radians(inclinacao)
    return Vector((math.sin(t) * math.cos(a), math.sin(t) * math.sin(a), math.cos(t)))


def esfera_fibonacci(i, total):
    """Direcoes espalhadas por igual numa esfera."""
    z = 1 - 2 * (i + 0.5) / total
    r = math.sqrt(max(0.0, 1 - z * z))
    a = i * 2.399963
    return Vector((math.cos(a) * r, math.sin(a) * r, z))


def curva(base, azimute, inclinacao, comprimento, curvatura, partes=5):
    """Pontos de uma haste que sai de base na direcao (azimute, inclinacao) e vai entortando."""
    pontos = [Vector(base)]
    passo = comprimento / partes
    for i in range(partes):
        angulo = inclinacao + curvatura * (i + 0.5) / partes
        pontos.append(pontos[-1] + direcao(azimute, angulo) * passo)
    return pontos


def ponto_na_linha(pontos, t):
    """Ponto na fracao t (0 a 1) de uma linha de varios pontos."""
    trechos = [(pontos[i + 1] - pontos[i]).length for i in range(len(pontos) - 1)]
    alvo = sum(trechos) * t
    for i, trecho in enumerate(trechos):
        if alvo <= trecho or i == len(trechos) - 1:
            return pontos[i].lerp(pontos[i + 1], min(alvo / trecho, 1.0) if trecho > 0 else 0.0)
        alvo -= trecho
    return pontos[-1]


# ---------------------------------------------------------------------------
# Construcao das malhas
# ---------------------------------------------------------------------------

LIMITE_TRIANGULOS = 9000  # o Roblox aceita ate 20.000 por MeshPart; deixamos folga


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

    def adicionar(self, objeto, forma, matriz, escala, cor, segmentos=12, topo=1.0, liso=None):
        """forma: 'esfera', 'gema', 'cilindro', 'tronco', 'cone', 'lamina' ou 'cubo' (tamanho 1)."""
        bm = self._bm(objeto)
        if forma == "esfera":
            resultado = bmesh.ops.create_uvsphere(bm, u_segments=segmentos, v_segments=max(4, segmentos // 2 + 1), radius=0.5)
        elif forma == "gema":  # esfera facetada
            resultado = bmesh.ops.create_uvsphere(bm, u_segments=6, v_segments=4, radius=0.5)
        elif forma == "cilindro":
            resultado = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segmentos, radius1=0.5, radius2=0.5, depth=1.0)
        elif forma == "tronco":  # tronco de cone: topo = raio de cima / raio de baixo
            resultado = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segmentos, radius1=0.5, radius2=0.5 * topo, depth=1.0)
        elif forma == "cone":
            resultado = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segmentos, radius1=0.5, radius2=0.0, depth=1.0)
        elif forma == "lamina":  # folha pontuda achatada
            resultado = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=4, radius1=0.5, radius2=0.0, depth=1.0)
        else:
            resultado = bmesh.ops.create_cube(bm, size=1.0)
        vertices = resultado["verts"]
        bmesh.ops.transform(bm, matrix=matriz @ tamanho(*escala), verts=vertices)
        if liso is None:
            liso = forma == "esfera" and segmentos >= 10
        camada = bm.loops.layers.uv.verify()
        u, v = PALETA.uv(cor)
        faces = set()
        for vertice in vertices:
            faces.update(vertice.link_faces)
        for face in faces:
            face.smooth = liso
            for loop in face.loops:
                loop[camada].uv = (u, v)

    def entre(self, objeto, a, b, largura, cor, segmentos=8, forma="cilindro", espessura=None, topo=1.0, sobra=0.0):
        """Peca esticada do ponto a ate o ponto b (a base da peca fica em a)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        comprimento = d.length
        if comprimento < 1e-6:
            return
        matriz = T(*((a + b) / 2)) @ alinhar_z(d)
        escala = (largura, espessura if espessura is not None else largura, comprimento + sobra)
        self.adicionar(objeto, forma, matriz, escala, cor, segmentos, topo)

    def limites(self):
        minimo = Vector((1e9, 1e9, 1e9))
        maximo = Vector((-1e9, -1e9, -1e9))
        for bm in self.malhas.values():
            for vertice in bm.verts:
                for i in range(3):
                    minimo[i] = min(minimo[i], vertice.co[i])
                    maximo[i] = max(maximo[i], vertice.co[i])
        return minimo, maximo

    def triangulos(self):
        return {objeto: sum(len(f.verts) - 2 for f in bm.faces) for objeto, bm in self.malhas.items()}

    def finalizar(self, colecao, material):
        # nomes unicos (ex.: Corpo_Carrot), senao o Blender renomeia para "Corpo.001"
        sufixo = self.nome.split("_", 1)[-1]
        for objeto, quantidade in self.triangulos().items():
            if quantidade > LIMITE_TRIANGULOS:
                print("AVISO: %s/%s tem %d triangulos" % (self.nome, objeto, quantidade))
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


# ---------------------------------------------------------------------------
# Pecas reaproveitadas (folhas, flores, frondes)
# ---------------------------------------------------------------------------

def folha_simples(m, objeto, base, d, comprimento, largura, cor, espessura=0.05, segmentos=8):
    """Folha (elipsoide achatado) saindo de base na direcao d."""
    d = Vector(d).normalized()
    centro = Vector(base) + d * comprimento * 0.5
    m.adicionar(objeto, "esfera", T(*centro) @ alinhar_z(d), (largura, espessura, comprimento), cor, segmentos)


def folha_arqueada(m, objeto, base, azimute, inclinacao, comprimento, curvatura, largura, cor, partes=4, espessura=0.07):
    """Folha comprida que sobe e depois cai (milho, palmeira, bananeira, flores)."""
    pontos = curva(base, azimute, inclinacao, comprimento, curvatura, partes)
    passo = comprimento / partes
    for i in range(partes):
        t = (i + 0.5) / partes
        w = largura * (0.5 + 2.0 * t * (1.0 - t)) * (1.0 - 0.35 * t)
        m.entre(objeto, pontos[i], pontos[i + 1], w, cor, 10, "esfera", espessura, sobra=passo * 0.45)


def folha_coracao(m, objeto, base, d, comprimento, cor):
    """Folha em forma de coracao (dois lobos) com cabinho."""
    d = Vector(d).normalized()
    base = Vector(base)
    inicio = base + d * comprimento * 0.22
    m.entre(objeto, base, inicio, 0.05, escurecer(cor, 0.15), 5)
    matriz = T(*(inicio + d * comprimento * 0.42)) @ alinhar_z(d)
    for lado in (1, -1):
        m.adicionar(objeto, "esfera", matriz @ T(lado * comprimento * 0.15, 0, -comprimento * 0.05) @ Ry(-lado * 22),
                    (comprimento * 0.42, 0.05, comprimento * 0.8), cor, 8)


def florzinha(m, objeto, centro, normal, raio, cor_petala, cor_miolo, petalas=5):
    matriz = T(*Vector(centro)) @ alinhar_z(normal)
    for k in range(petalas):
        m.adicionar(objeto, "esfera", matriz @ Rz(k * 360 / petalas) @ T(0, raio * 0.55, 0), (raio * 0.6, raio * 0.9, raio * 0.18), cor_petala, 6)
    m.adicionar(objeto, "esfera", matriz @ T(0, 0, raio * 0.08), (raio * 0.45, raio * 0.45, raio * 0.3), cor_miolo, 6)


def fronde_curva(m, objeto, pontos, cor, largura, ponta=None):
    """Haste com foliolos dos dois lados (samambaia, rama da cenoura)."""
    total = len(pontos) - 1
    for i in range(total):
        a, b = pontos[i], pontos[i + 1]
        m.entre(objeto, a, b, 0.06, escurecer(cor, 0.15), 5, sobra=0.03)
        d = (b - a).normalized()
        lateral = Vector((0.0, 0.0, 1.0)).cross(d)
        if lateral.length < 1e-4:
            lateral = Vector((1.0, 0.0, 0.0))
        lateral.normalize()
        t = (i + 0.5) / total
        tam = largura * (1.0 - 0.55 * t)
        meio = (a + b) / 2
        for lado in (1, -1):
            folha_simples(m, objeto, meio, lateral * lado + d * 0.45, tam, tam * 0.42, tom(cor, 0.05 * (i % 2)), segmentos=6)
    if ponta:
        objeto_ponta, cor_ponta, raio = ponta
        m.adicionar(objeto_ponta, "esfera", T(*pontos[-1]), (raio, raio, raio), cor_ponta, 10)


# ---------------------------------------------------------------------------
# Plantas (mesmas proporcoes das plantas feitas com Parts em Visuals.luau,
# para os frutos nascerem nos lugares certos)
# ---------------------------------------------------------------------------

def planta_root(m, s):
    h, (fx, fz, fh) = s["altura"], fruto_blender(s["fruto"])
    produto, cor, folha = "Produto_" + s["id"], s["corFruto"], s["corFolha"]
    # a raiz aparece saindo da terra: tronco de cone + topo arredondado
    corpo = fh * 0.56
    m.adicionar(produto, "tronco", T(0, 0, corpo / 2), (fx * 0.55, fz * 0.55, corpo), cor, 14, topo=1.8)
    m.adicionar(produto, "esfera", T(0, 0, corpo), (fx, fz, fh * 0.3), cor, 14)
    for i in range(6):  # risquinhos
        z = corpo * (0.15 + 0.13 * i)
        raio = fx * (0.275 + 0.22 * z / corpo)
        m.adicionar(produto, "esfera", Rz(i * 67) @ T(raio, 0, z), (0.04, fx * 0.28, 0.03), escurecer(cor, 0.18), 6)
    base = (0, 0, corpo + fh * 0.1)
    comprimento = max(h - base[2], 0.5)
    for i in range(5):
        pontos = curva(base, i * 72 + 15, 8 + 10 * (i % 2), comprimento, 25, 3)
        fronde_curva(m, "Corpo", pontos, tom(folha, 0.05 * (i % 3)), 0.34)


def planta_bush(m, s):
    h, folha, sid = s["altura"], s["corFolha"], s["id"]
    m.adicionar("Corpo", "tronco", T(0, 0, h * 0.15), (0.32, 0.32, h * 0.3), CAULE, 8, topo=0.7)
    m.adicionar("Corpo", "esfera", T(0, 0, h * 0.5), (h * 0.85, h * 0.85, h * 0.62), folha, 16)
    tufos = (
        (0.2, -0.1, 0.72, 0.5, 0.42, 0.08),
        (-0.22, 0.15, 0.62, 0.46, 0.4, 0.04),
        (0.05, 0.28, 0.55, 0.42, 0.36, -0.06),
        (-0.2, -0.25, 0.5, 0.42, 0.36, 0.05),
        (0.3, 0.12, 0.45, 0.38, 0.32, -0.08),
        (0.0, 0.0, 0.84, 0.34, 0.3, 0.12),
    )
    for x, y, z, w, a, t in tufos:
        m.adicionar("Corpo", "esfera", T(x * h, y * h, z * h), (w * h, w * h, a * h), tom(folha, t), 12)
    for i in range(10):  # folhas pontudas saindo da copa
        az = i * 36 + 12
        r = math.radians(az)
        base = Vector((math.cos(r) * h * 0.36, math.sin(r) * h * 0.36, h * (0.36 + 0.07 * (i % 3))))
        folha_simples(m, "Corpo", base, direcao(az, 62 - 10 * (i % 3)), h * 0.26, h * 0.12, tom(folha, 0.06 * (i % 2)))
    if sid in ("Strawberry", "Blueberry"):  # florzinhas brancas
        for i in range(4):
            r = math.radians(i * 90 + 40)
            normal = Vector((math.cos(r), math.sin(r), 0.9)).normalized()
            centro = Vector((math.cos(r) * h * 0.36, math.sin(r) * h * 0.36, h * 0.7))
            florzinha(m, "Corpo", centro, normal, 0.16, BRANCO, (255, 220, 80))
    if sid in ("Tomato", "Pepper", "GhostPepper", "InfernoPepper"):  # estaca de madeira
        x, y = h * 0.38, -h * 0.12
        estaca = clarear(MADEIRA, 0.15)
        m.adicionar("Corpo", "cilindro", T(x, y, h * 0.48), (0.1, 0.1, h * 0.96), estaca, 6)
        m.adicionar("Corpo", "cone", T(x, y, h * 0.99), (0.1, 0.1, 0.08), estaca, 6)
        for z in (0.35, 0.6):
            m.adicionar("Corpo", "cilindro", T(x, y, h * z), (0.16, 0.16, 0.05), (230, 210, 150), 6)
    if sid == "InfernoPepper":  # brasas soltando do arbusto
        for i in range(5):
            r = math.radians(i * 72 + 20)
            m.adicionar("Brilho", "esfera", T(math.cos(r) * h * 0.25, math.sin(r) * h * 0.25, h * (0.95 + 0.05 * (i % 2))), (0.12, 0.12, 0.12), (255, 140, 40), 6)


def planta_flower(m, s):
    h, (fx, fz, fh) = s["altura"], fruto_blender(s["fruto"])
    produto, cor, folha = "Produto_" + s["id"], s["corFruto"], s["corFolha"]
    topo_caule = h - fh * 0.95
    pontos = [Vector((0, 0, 0)), Vector((0.06, 0.0, topo_caule * 0.5)), Vector((0, 0, topo_caule))]
    for a, b in zip(pontos, pontos[1:]):
        m.entre("Corpo", a, b, 0.14, CAULE, 8, sobra=0.06)
    for i, az in enumerate((20, 200, 110)):
        folha_arqueada(m, "Corpo", (0, 0, 0.05), az, 12, h * (0.5 if i < 2 else 0.38), 40, 0.42, tom(folha, 0.05 * i))
    centro = Vector((0, 0, topo_caule + fh * 0.45))
    if s["id"] == "Daffodil":
        frente = Vector((0.0, -0.55, 0.85)).normalized()
        centro = Vector((0, -0.1, topo_caule + fh * 0.3))
        m.entre("Corpo", pontos[-1], centro - frente * 0.08, 0.12, CAULE, 6, sobra=0.04)
        m.adicionar("Corpo", "esfera", T(*(centro - frente * 0.1)), (0.24, 0.24, 0.2), escurecer(folha, 0.1), 10)
        cabeca = T(*centro) @ alinhar_z(frente)
        for k in range(6):
            m.adicionar(produto, "esfera", cabeca @ Rz(k * 60) @ T(0, fx * 0.3, 0), (fx * 0.34, fx * 0.62, 0.07), cor, 10)
        m.adicionar(produto, "tronco", cabeca @ T(0, 0, fx * 0.16), (fx * 0.3, fx * 0.3, fx * 0.32), misturar(cor, (255, 150, 30), 0.55), 12, topo=1.5)
    else:  # tulipa: taca de 6 petalas
        m.adicionar("Corpo", "esfera", T(0, 0, topo_caule + 0.04), (0.26, 0.26, 0.18), escurecer(folha, 0.1), 10)
        for k in range(6):
            interna = k % 2 == 0
            matriz = T(*centro) @ Rz(k * 60) @ T(fx * (0.15 if interna else 0.21), 0, 0) @ Ry(9 if interna else 17)
            m.adicionar(produto, "esfera", matriz, (fx * 0.22, fx * 0.56, fh * 0.92), cor if interna else escurecer(cor, 0.07), 12)


def planta_tall(m, s):
    h, folha = s["altura"], s["corFolha"]
    caule = escurecer(folha, 0.15)
    topo = h * 0.9
    partes = 5
    for i in range(partes):
        z0, z1 = topo * i / partes, topo * (i + 1) / partes
        largura = 0.38 - 0.04 * i
        m.entre("Corpo", (0, 0, z0), (0, 0, z1), largura, caule, 10)
        m.adicionar("Corpo", "cilindro", T(0, 0, z1), (largura + 0.06, largura + 0.06, 0.07), escurecer(caule, 0.12), 10)
    for i in range(7):
        folha_arqueada(m, "Corpo", (0, 0, h * (0.1 + 0.105 * i)), i * 137.5, 25, h * (0.42 - 0.025 * i), 95, 0.42, tom(folha, 0.04 * (i % 3)))
    pendao = (230, 200, 120)
    for i in range(7):
        d = direcao(i * 51, 0 if i == 0 else 30)
        a = Vector((0, 0, topo))
        m.entre("Corpo", a, a + d * h * 0.13, 0.07, pendao if i % 2 else escurecer(pendao, 0.1), 5, "cone")


def planta_ground(m, s):
    fx, fz, fh = fruto_blender(s["fruto"])
    produto, cor, folha = "Produto_" + s["id"], s["corFruto"], s["corFolha"]
    if s["id"] == "Pumpkin":  # abobora com gomos
        m.adicionar(produto, "esfera", T(0, 0, fh / 2), (fx * 0.86, fz * 0.86, fh * 0.94), escurecer(cor, 0.08), 16)
        for k in range(10):
            m.adicionar(produto, "esfera", Rz(k * 36) @ T(fx * 0.2, 0, fh / 2), (fx * 0.58, fx * 0.34, fh), cor if k % 2 else clarear(cor, 0.06), 14)
        talo = (95, 110, 45)
        a = Vector((0, 0, fh * 0.92))
        b = a + Vector((0.08, 0.02, 0.32))
        m.entre("Corpo", a, b, 0.24, talo, 7, "tronco", topo=0.65)
        m.entre("Corpo", b, b + Vector((0.2, 0.03, 0.14)), 0.15, talo, 7, "tronco", topo=0.6)
    else:  # melancia listrada
        m.adicionar(produto, "esfera", T(0, 0, fh / 2), (fx, fz, fh), cor, 18)
        listra = escurecer(cor, 0.4)
        for k in range(8):
            m.adicionar(produto, "esfera", T(0, 0, fh / 2) @ Rx(k * 22.5), (fx * 1.012, fz * 0.1, fh * 1.012), listra, 18)
        m.adicionar("Corpo", "cilindro", T(-fx * 0.49, 0, fh * 0.6) @ Ry(-60), (0.12, 0.12, 0.35), (100, 120, 50), 6)
    # folhas grandes no chao, de tamanhos e angulos diferentes (cada uma com 3 lobos)
    for k, (az, comprimento) in enumerate(((20, 1.7), (95, 1.35), (165, 1.85), (238, 1.25), (300, 1.55))):
        r = fx * 0.42 + comprimento * 0.35
        centro = Vector((math.cos(math.radians(az)) * r, math.sin(math.radians(az)) * r, 0.07))
        matriz = T(*centro) @ Rz(az + (12 if k % 2 else -9)) @ Ry(5 + 4 * (k % 3))
        cor = tom(folha, 0.05 * (k % 3) - 0.03)
        m.adicionar("Corpo", "esfera", matriz, (comprimento, comprimento * 0.62, 0.1), cor, 10)
        for lado in (1, -1):
            m.adicionar("Corpo", "esfera", matriz @ T(comprimento * 0.08, lado * comprimento * 0.2, 0.01) @ Rz(lado * 40),
                        (comprimento * 0.62, comprimento * 0.4, 0.09), cor, 8)
        m.entre("Corpo", Vector((0, 0, 0.06)), centro * 0.7, 0.07, CAULE, 6)
    for i in range(10):  # gavinha enrolada
        ang = math.radians(i * 50)
        raio = 0.25 - i * 0.015
        m.adicionar("Corpo", "esfera", T(fx * 0.55 + math.cos(ang) * raio, -fz * 0.62 + math.sin(ang) * raio, 0.12 + i * 0.03), (0.08, 0.08, 0.08), CAULE, 6)


def planta_tree(m, s):
    h, folha = s["altura"], s["corFolha"]
    m.adicionar("Corpo", "tronco", T(0, 0, h * 0.3), (h * 0.14, h * 0.14, h * 0.6), MADEIRA, 10, topo=0.65)
    for k in range(5):  # raizes
        m.adicionar("Corpo", "esfera", Rz(k * 72 + 20) @ T(h * 0.065, 0, h * 0.02), (h * 0.12, h * 0.05, h * 0.07), escurecer(MADEIRA, 0.1), 8)
    for k in range(3):  # galhos
        a = Vector((0, 0, h * 0.42))
        m.entre("Corpo", a, a + direcao(k * 120 + 40, 50) * h * 0.26, h * 0.05, MADEIRA, 7, "tronco", topo=0.6)
    copa = (
        (0.0, 0.0, 0.68, 0.75, 0.55, 0.0),
        (0.22, 0.0, 0.82, 0.45, 0.4, 0.07),
        (-0.2, 0.15, 0.78, 0.42, 0.38, 0.03),
        (0.05, -0.22, 0.8, 0.4, 0.36, -0.04),
        (-0.14, -0.16, 0.6, 0.4, 0.34, -0.06),
        (0.16, 0.2, 0.6, 0.38, 0.32, 0.05),
        (0.0, 0.0, 0.9, 0.36, 0.28, 0.1),
    )
    for x, y, z, w, a, t in copa:
        m.adicionar("Corpo", "esfera", T(x * h, y * h, z * h), (w * h, w * h, a * h), tom(folha, t), 14)
    if s["id"] == "GalaxyFruit":  # estrelinhas brilhando na copa
        for k in range(10):
            a = math.radians(k * 137.5)
            e = math.radians(-10 + (k * 29) % 70)
            pos = Vector((math.cos(a) * math.cos(e) * h * 0.385, math.sin(a) * math.cos(e) * h * 0.385, h * 0.68 + math.sin(e) * h * 0.285))
            m.adicionar("Brilho", "gema", T(*pos), (0.2, 0.2, 0.2), (255, 250, 200), 6)


def planta_stalk(m, s):
    fx, fz, fh = fruto_blender(s["fruto"])
    produto, cor, folha = "Produto_" + s["id"], s["corFruto"], s["corFolha"]
    partes = 5
    altura = fh / partes
    for i in range(partes):
        m.adicionar(produto, "cilindro", T(0, 0, altura * (i + 0.5)), (fx, fx, altura * 0.96), cor if i % 2 == 0 else clarear(cor, 0.05), 10)
        m.adicionar(produto, "cilindro", T(0, 0, altura * (i + 1) - 0.02), (fx * 1.14, fx * 1.14, 0.1), escurecer(cor, 0.22), 10)
    for dx, dy, fracao in ((0.45, 0.2, 0.55), (-0.35, -0.3, 0.35)):  # brotos ao lado
        for i in range(3):
            z0, z1 = fh * fracao * i / 3, fh * fracao * (i + 1) / 3
            m.entre("Corpo", (dx, dy, z0), (dx, dy, z1 - 0.03), fx * 0.6, escurecer(cor, 0.08), 8)
            m.adicionar("Corpo", "cilindro", T(dx, dy, z1), (fx * 0.7, fx * 0.7, 0.07), escurecer(cor, 0.25), 8)
    for i in range(8):  # folhas nos nos
        z = fh * (0.45 + 0.07 * i)
        d = direcao(i * 137.5, 62 + 8 * (i % 2))
        base = Vector((0, 0, z))
        m.entre("Corpo", base + d * fx * 0.4, base + d * (fx * 0.4 + 1.1), 0.32, tom(folha, 0.04 * (i % 3)), 4, "lamina", espessura=0.05)


def planta_palm(m, s):
    h, folha = s["altura"], s["corFolha"]
    banana = s["id"] == "Banana"
    topo = h * 0.84
    cor_tronco = misturar(MADEIRA, folha, 0.45) if banana else MADEIRA
    partes = 7
    pontos = [Vector((0.18 * math.sin(math.pi * i / partes), 0, topo * i / partes)) for i in range(partes + 1)]
    for i in range(partes):
        cor = clarear(cor_tronco, 0.08) if i % 2 else cor_tronco
        m.entre("Corpo", pontos[i], pontos[i + 1], 0.62 - 0.04 * i, cor, 10, "tronco", topo=0.88, sobra=0.04)
    m.adicionar("Corpo", "esfera", T(0, 0, topo), (0.7, 0.7, 0.45), escurecer(folha, 0.15), 10)
    folhas = 6 if banana else 8
    for i in range(folhas):
        folha_arqueada(m, "Corpo", (0, 0, topo), i * 360 / folhas + 10, 50, h * (0.5 if banana else 0.46), 90,
                       1.25 if banana else 0.85, tom(folha, 0.05 * (i % 3)), partes=5)
    m.entre("Corpo", (0, 0, topo), (0, 0, h), 0.3, clarear(folha, 0.06), 4, "lamina", espessura=0.12)  # folha nova no meio
    if banana:  # coracao da bananeira
        m.entre("Corpo", (0.1, 0, topo - 0.1), (0.35, 0, topo - 0.5), 0.1, CAULE, 6)
        m.adicionar("Corpo", "esfera", T(0.38, 0.0, topo - 0.75) @ Ry(20), (0.38, 0.38, 0.6), (120, 40, 80), 10)


def planta_cactus(m, s):
    h, cor = s["altura"], s["corFolha"]
    m.adicionar("Corpo", "cilindro", T(0, 0, h * 0.375), (h * 0.25, h * 0.25, h * 0.75), cor, 12)
    m.adicionar("Corpo", "esfera", T(0, 0, h * 0.75), (h * 0.25, h * 0.25, h * 0.22), cor, 12)
    for k in range(8):  # costelas
        m.adicionar("Corpo", "esfera", Rz(k * 45 + 22.5) @ T(h * 0.118, 0, h * 0.42), (0.07, 0.09, h * 0.74), escurecer(cor, 0.12), 6)
    for lado in (1, -1):
        altura_braco = h * (0.4 if lado == 1 else 0.5)
        m.adicionar("Corpo", "cilindro", T(lado * h * 0.17, 0, altura_braco) @ Ry(90), (h * 0.13, h * 0.13, h * 0.18), cor, 10)
        m.adicionar("Corpo", "cilindro", T(lado * h * 0.25, 0, altura_braco + h * 0.1), (h * 0.13, h * 0.13, h * 0.22), cor, 10)
        m.adicionar("Corpo", "esfera", T(lado * h * 0.25, 0, altura_braco + h * 0.21), (h * 0.13, h * 0.13, h * 0.11), cor, 10)
    for i in range(22):  # espinhos
        a = math.radians(i * 137.5)
        fora = Vector((math.cos(a), math.sin(a), 0.25)).normalized()
        base = Vector((math.cos(a) * h * 0.125, math.sin(a) * h * 0.125, h * (0.08 + 0.03 * i)))
        m.entre("Corpo", base, base + fora * 0.2, 0.05, CREME, 4, "cone")
    flor = misturar(s["corFruto"], BRANCO, 0.3)
    topo = Vector((0, 0, h * 0.85))
    for k in range(6):
        m.adicionar("Corpo", "esfera", T(*topo) @ Rz(k * 60) @ Ry(55) @ T(0, 0, h * 0.045), (0.05, h * 0.05, h * 0.09), flor, 8)
    m.adicionar("Corpo", "esfera", T(*topo), (h * 0.05, h * 0.05, h * 0.04), (255, 220, 90), 8)


def planta_mushroom(m, s):
    h, (fx, fz, fh) = s["altura"], fruto_blender(s["fruto"])
    produto, cor, caule = "Produto_" + s["id"], s["corFruto"], s["corFolha"]
    m.adicionar("Corpo", "tronco", T(0, 0, h * 0.26), (0.85, 0.85, h * 0.52), caule, 12, topo=0.72)
    topo = h * 0.5 + fh * 0.25
    m.adicionar("Corpo", "cilindro", T(0, 0, topo - fh * 0.18), (fx * 0.78, fz * 0.78, 0.1), escurecer(caule, 0.12), 18)
    m.adicionar(produto, "esfera", T(0, 0, topo), (fx, fz, fh), cor, 18)
    for e_graus, quantidade in ((32, 6), (62, 4)):  # pintas brancas
        e = math.radians(e_graus)
        for k in range(quantidade):
            a = math.radians(k * 360 / quantidade + e_graus)
            normal = Vector((math.cos(a) * math.cos(e) / (fx / 2), math.sin(a) * math.cos(e) / (fz / 2), math.sin(e) / (fh / 2))).normalized()
            pos = Vector((math.cos(a) * math.cos(e) * fx / 2, math.sin(a) * math.cos(e) * fz / 2, topo + math.sin(e) * fh / 2))
            m.adicionar("Corpo", "esfera", T(*pos) @ alinhar_z(normal), (0.34, 0.34, 0.07), BRANCO, 8)
    m.adicionar("Corpo", "esfera", T(0, 0, topo + fh / 2), (0.4, 0.4, 0.06), BRANCO, 8)
    for x, y, escala in ((0.75, 0.35, 1.0), (-0.6, -0.55, 0.8)):  # cogumelinhos ao lado
        alt = h * 0.32 * escala
        m.adicionar("Corpo", "tronco", T(x, y, alt / 2), (0.25 * escala, 0.25 * escala, alt), caule, 8, topo=0.8)
        m.adicionar(produto, "esfera", T(x, y, alt), (fx * 0.35 * escala, fz * 0.35 * escala, fh * 0.28 * escala), cor, 12)


def planta_beanstalk(m, s):
    h, folha = s["altura"], s["corFolha"]
    topo = h * 0.86
    partes = 18
    for fio in range(2):  # dois caules enrolados
        cor = escurecer(folha, 0.12) if fio == 0 else clarear(folha, 0.04)
        fase = fio * math.pi
        pontos = [Vector((math.cos(i * 0.7 + fase) * 0.3, math.sin(i * 0.7 + fase) * 0.3, topo * i / partes)) for i in range(partes + 1)]
        for i in range(partes):
            m.entre("Corpo", pontos[i], pontos[i + 1], 0.4 - 0.012 * i, cor, 8, sobra=0.1)
    for i in range(1, 11):
        az = i * 137.5
        r = math.radians(az)
        base = Vector((math.cos(r) * 0.3, math.sin(r) * 0.3, topo * i / 11))
        folha_coracao(m, "Corpo", base, direcao(az, 70), 1.0 - 0.03 * i, tom(folha, 0.05 * (i % 3)))
    for k in range(7):  # nuvem
        a = math.radians(k * 51)
        raio = 0.0 if k == 0 else 0.75
        largura = 1.5 if k == 0 else 1.15
        m.adicionar("Corpo", "esfera", T(math.cos(a) * raio, math.sin(a) * raio, topo + 0.3 + 0.08 * (k % 2)),
                    (largura, largura, 0.75), BRANCO if k % 2 == 0 else (235, 240, 250), 12)
    pedra, telhado = (200, 200, 210), (90, 110, 200)  # castelinho nas nuvens
    base = topo + 0.55
    m.adicionar("Corpo", "cubo", T(0, 0, base + 0.2), (0.8, 0.6, 0.4), pedra)
    m.adicionar("Corpo", "cubo", T(0, -0.31, base + 0.12), (0.18, 0.03, 0.24), (90, 60, 40))
    for lado in (1, -1):
        m.adicionar("Corpo", "cilindro", T(lado * 0.42, 0, base + 0.3), (0.3, 0.3, 0.6), pedra, 10)
        m.adicionar("Corpo", "cone", T(lado * 0.42, 0, base + 0.75), (0.38, 0.38, 0.3), telhado, 10)


def folha_parreira(m, objeto, centro, cor):
    """Folha de uva: 3 lobos virados para fora da trelica."""
    for ang in (-50, 0, 50):
        m.adicionar(objeto, "esfera", T(*centro) @ Ry(ang) @ T(0, 0, 0.12), (0.22, 0.05, 0.3), cor, 8)


def folha_tripla(m, objeto, centro, cor):
    """Hera venenosa: tres foliolos pontudos."""
    for ang in (-65, 0, 65):
        m.adicionar(objeto, "esfera", T(*centro) @ Ry(ang) @ T(0, 0, 0.15), (0.14, 0.05, 0.32), cor, 8)


def folha_feijao(m, objeto, centro, cor):
    for ang in (-28, 28):
        m.adicionar(objeto, "esfera", T(*centro) @ Ry(180 + ang) @ T(0, 0, 0.16), (0.2, 0.05, 0.34), cor, 8)


def planta_vine(m, s):
    h, folha, sid = s["altura"], s["corFolha"], s["id"]
    for x in (-0.9, 0.9):  # trelica
        m.adicionar("Corpo", "cilindro", T(x, 0, h / 2), (0.16, 0.16, h), MADEIRA, 8)
        m.adicionar("Corpo", "cone", T(x, 0, h + 0.08), (0.18, 0.18, 0.16), escurecer(MADEIRA, 0.1), 8)
    for z in (0.4, 0.7, 0.95):
        m.adicionar("Corpo", "cubo", T(0, 0, h * z), (1.9, 0.08, 0.08), MADEIRA)
    m.entre("Corpo", (-0.9, 0, h * 0.4), (0.9, 0, h * 0.95), 0.06, clarear(MADEIRA, 0.1), 4)
    m.entre("Corpo", (0.9, 0, h * 0.4), (-0.9, 0, h * 0.95), 0.06, clarear(MADEIRA, 0.1), 4)
    for i in range(3):  # ramos ondulados
        x0 = -0.6 + 0.6 * i
        lado = 0.05 if i % 2 else -0.05
        pontos = [Vector((x0 + math.sin(j * 1.3 + i) * 0.15, lado, h * 0.95 * j / 6)) for j in range(7)]
        for a, b in zip(pontos, pontos[1:]):
            m.entre("Corpo", a, b, 0.09, CAULE, 6, sobra=0.03)
    for i in range(16):
        x = -0.85 + ((i * 0.37) % 1) * 1.7
        z = h * (0.2 + ((i * 0.53) % 1) * 0.75)
        y = 0.13 if i % 2 == 0 else -0.13
        cor = tom(folha, 0.05 * (i % 3) - 0.03)
        if sid == "PoisonIvy":
            folha_tripla(m, "Corpo", Vector((x, y, z)), cor)
        elif sid == "Grape":
            folha_parreira(m, "Corpo", Vector((x, y, z)), cor)
        else:
            folha_feijao(m, "Corpo", Vector((x, y, z)), cor)


def planta_fern(m, s):
    h, folha, cor = s["altura"], s["corFolha"], s["corFruto"]
    m.adicionar("Corpo", "esfera", T(0, 0, 0.1), (0.8, 0.8, 0.32), escurecer(folha, 0.3), 10)
    for i in range(11):
        alta = i % 3 == 0
        pontos = curva((0, 0, 0.15), i * 32.7 + 5, 8 if alta else 30 + 8 * (i % 2), h * (0.95 if alta else 0.75), 35 if alta else 60, 6)
        fronde_curva(m, "Corpo", pontos, tom(folha, 0.05 * (i % 3)), 0.5, ("Brilho", cor, 0.22))


QUANTIDADE_BOCAS = 5  # igual ao jogo (Visuals.luau: TRAP_COUNT)


def planta_flytrap(m, s):
    h, folha = s["altura"], s["corFolha"]
    boca = (200, 40, 50)
    m.adicionar("Corpo", "esfera", T(0, 0, 0.1), (1.2, 1.2, 0.3), escurecer(folha, 0.2), 12)
    for k in range(6):  # roseta no chao
        m.adicionar("Corpo", "esfera", Rz(k * 60 + 30) @ T(0.55, 0, 0.1) @ Ry(-10), (0.9, 0.36, 0.07), tom(folha, 0.05 * (k % 2)), 8)
    r = h * 0.36
    for k in range(QUANTIDADE_BOCAS):
        a = k * 2 * math.pi / QUANTIDADE_BOCAS + 0.4
        fora = Vector((math.cos(a), -math.sin(a), 0.0))  # o Z do Roblox vira -Y no Blender
        cabeca = fora * r + Vector((0, 0, h * 0.72))
        meio = fora * r * 0.4 + Vector((0, 0, h * 0.42))
        m.entre("Corpo", (0, 0, 0.12), meio, 0.13, CAULE, 6, sobra=0.04)
        m.entre("Corpo", meio, cabeca - fora * 0.12, 0.12, CAULE, 6, sobra=0.04)
        frente = (fora + Vector((0, 0, 0.35))).normalized()
        base = T(*cabeca) @ olhar(frente)
        for lado in (1, -1):
            mandibula = base @ T(0, -0.12, 0.2 * lado) @ Rx(28 * lado) @ T(0, 0.4, 0)
            m.adicionar("Corpo", "esfera", mandibula @ T(0, 0, 0.04 * lado), (0.74, 0.82, 0.15), folha, 12)
            m.adicionar("Corpo", "esfera", mandibula @ T(0, 0, -0.02 * lado), (0.64, 0.72, 0.07), boca, 10)
            for t in range(7):  # cilios
                ang = math.radians(-80 + t * 160 / 6)
                borda = mandibula @ Vector((math.sin(ang) * 0.37, math.cos(ang) * 0.41, 0.0))
                d = (mandibula.to_3x3() @ Vector((math.sin(ang) * 0.5, math.cos(ang) * 0.5, -0.9 * lado))).normalized()
                m.entre("Corpo", borda, borda + d * 0.2, 0.045, CREME, 4, "cone")
    topo = Vector((0, 0, h))  # haste com florzinhas brancas no meio
    m.entre("Corpo", (0, 0, 0.15), topo - Vector((0, 0, 0.12)), 0.07, CAULE, 6)
    for k in range(5):
        a = math.radians(k * 72)
        centro = topo + Vector((math.cos(a) * 0.12, math.sin(a) * 0.12, -0.1 + 0.03 * (k % 2)))
        florzinha(m, "Corpo", centro, Vector((math.cos(a), math.sin(a), 1.2)), 0.16, BRANCO, (240, 230, 120))


def cor_petala(sid, k, camada, cor):
    if sid == "RainbowSeed":
        base = ARCO_IRIS[k % len(ARCO_IRIS)]
        return base if camada == 0 else clarear(base, 0.3)
    if sid == "HypnoBloom":
        return cor if (k + camada) % 2 == 0 else misturar(cor, BRANCO, 0.6)
    if sid == "EclipseBloom":
        return escurecer(cor, 0.25) if camada == 0 else misturar(cor, (255, 190, 90), 0.5)
    if sid == "SunBloom":
        return cor if camada == 0 else misturar(cor, (255, 120, 30), 0.45)
    if sid == "MoonBloom":
        return misturar(cor, BRANCO, 0.45) if camada == 0 else cor
    return misturar(cor, BRANCO, 0.25 if camada == 0 else 0.05)


def orbe(m, sid, centro, tamanho_orbe, cor):
    """Orbe magico flutuando sobre as flores especiais (ganha luz no jogo)."""
    c = Vector(centro)
    if sid == "MoonBloom":  # lua crescente
        quantidade = 9
        for i in range(quantidade):
            t = i / (quantidade - 1)
            ang = math.radians(-120 + 240 * t)
            tam = tamanho_orbe * 0.55 * (1 - 0.7 * abs(2 * t - 1) ** 1.5)
            m.adicionar("Brilho", "esfera", T(*(c + Vector((math.cos(ang), 0, math.sin(ang))) * tamanho_orbe * 0.42)), (tam, tam * 0.8, tam), cor, 8)
    elif sid == "SunBloom":  # sol com raios
        m.adicionar("Brilho", "esfera", T(*c), (tamanho_orbe * 0.6,) * 3, cor, 12)
        for k in range(12):
            d = esfera_fibonacci(k, 12)
            m.entre("Brilho", c + d * tamanho_orbe * 0.26, c + d * tamanho_orbe * 0.5, tamanho_orbe * 0.14, misturar(cor, (255, 140, 30), 0.3), 5, "cone")
    elif sid == "EclipseBloom":  # sol escuro com coroa
        m.adicionar("Corpo", "esfera", T(*c), (tamanho_orbe * 0.62,) * 3, (25, 20, 35), 12)
        for k in range(16):
            a = math.radians(k * 22.5)
            tam = tamanho_orbe * (0.16 if k % 2 == 0 else 0.1)
            m.adicionar("Brilho", "esfera", T(*(c + Vector((math.cos(a), 0, math.sin(a))) * tamanho_orbe * 0.42)), (tam,) * 3, (255, 200, 90), 6)
    elif sid == "HypnoBloom":  # espiral
        m.adicionar("Brilho", "esfera", T(*c), (tamanho_orbe * 0.7,) * 3, cor, 12)
        for i in range(16):
            t = i / 15
            ang = math.radians(t * 900)
            e = math.radians(-70 + 140 * t)
            d = Vector((math.cos(ang) * math.cos(e), math.sin(ang) * math.cos(e), math.sin(e)))
            m.adicionar("Corpo", "esfera", T(*(c + d * tamanho_orbe * 0.36)), (tamanho_orbe * 0.12,) * 3, BRANCO, 5)
    else:  # Semente Arco-iris: gema
        m.adicionar("Brilho", "gema", T(*(c - Vector((0, 0, tamanho_orbe * 0.08)))), (tamanho_orbe * 0.6, tamanho_orbe * 0.6, tamanho_orbe * 0.5), cor, 6)
        m.adicionar("Brilho", "cone", T(*(c + Vector((0, 0, tamanho_orbe * 0.3)))), (tamanho_orbe * 0.4, tamanho_orbe * 0.4, tamanho_orbe * 0.3), cor, 6)


def planta_bloom(m, s):
    h, folha, cor, sid = s["altura"], s["corFolha"], s["corFruto"], s["id"]
    pontos = [Vector((0, 0, 0)), Vector((0.05 * h, 0, 0.22 * h)), Vector((-0.03 * h, 0, 0.44 * h)), Vector((0, 0, 0.64 * h))]
    for i in range(3):
        m.entre("Corpo", pontos[i], pontos[i + 1], 0.3 - 0.04 * i, CAULE, 10, sobra=0.06)
    for k in range(3):
        folha_arqueada(m, "Corpo", (0, 0, h * (0.06 + 0.1 * k)), k * 130 + 15, 30, h * 0.4, 80, 0.9, tom(folha, 0.05 * k))
    z = h * 0.66
    quantidade = {"SunBloom": 12, "MoonBloom": 7, "HypnoBloom": 10}.get(sid, 8)
    for camada, (comprimento, inclinacao, largura) in enumerate(((0.34, 68, 0.15), (0.22, 42, 0.11))):
        for k in range(quantidade):
            az = k * 360 / quantidade + camada * 180 / quantidade
            matriz = T(0, 0, z) @ Rz(az) @ Ry(inclinacao) @ T(0, 0, h * comprimento * 0.5)
            m.adicionar("Corpo", "esfera", matriz, (0.09, h * largura, h * comprimento), cor_petala(sid, k, camada, cor), 10)
    m.adicionar("Corpo", "esfera", T(0, 0, z + 0.05), (h * 0.18, h * 0.18, h * 0.11), misturar(cor, BRANCO, 0.2), 12)
    orbe(m, sid, (0, 0, h * 0.91), h * 0.17, cor)


def planta_sunflower(m, s):
    h, folha = s["altura"], s["corFolha"]
    amarelo, miolo = (255, 205, 40), (110, 70, 30)
    pontos = [Vector((0, 0, 0)), Vector((0.04 * h, 0, 0.3 * h)), Vector((-0.02 * h, 0, 0.6 * h)), Vector((0, -0.04 * h, 0.82 * h))]
    for i in range(3):
        m.entre("Corpo", pontos[i], pontos[i + 1], 0.3 - 0.03 * i, CAULE, 8, sobra=0.06)
    for k in range(4):
        base = Vector((0, 0, h * (0.22 + 0.14 * k)))
        folha_coracao(m, "Corpo", base, direcao(k * 100 + 30, 60), h * 0.24, tom(folha, 0.05 * (k % 2)))
    frente = Vector((0, -0.85, 0.5)).normalized()
    cabeca = T(*(pontos[-1] + frente * 0.12)) @ alinhar_z(frente)
    m.adicionar("Corpo", "cilindro", cabeca, (h * 0.27, h * 0.27, 0.22), miolo, 18)
    for anel, (raio, quantidade) in enumerate(((0.045, 7), (0.09, 13))):  # sementes
        for k in range(quantidade):
            a = math.radians(k * 360 / quantidade + anel * 10)
            m.adicionar("Corpo", "esfera", cabeca @ T(math.cos(a) * h * raio, math.sin(a) * h * raio, 0.11), (0.09, 0.09, 0.05), escurecer(miolo, 0.3), 4)
    for camada in range(2):
        quantidade = 14
        for k in range(quantidade):
            matriz = cabeca @ Rz(k * 360 / quantidade + camada * 180 / quantidade) @ T(0, h * (0.2 - 0.03 * camada), -0.02 * camada)
            m.adicionar("Corpo", "esfera", matriz, (h * 0.075, h * (0.17 - 0.03 * camada), 0.06),
                        amarelo if camada == 0 else misturar(amarelo, (255, 150, 30), 0.35), 8)
    m.adicionar("Corpo", "cilindro", cabeca @ T(0, 0, -0.14), (h * 0.24, h * 0.24, 0.08), escurecer(folha, 0.1), 14)


def planta_spitter(m, s):
    h, folha, cor = s["altura"], s["corFolha"], s["corFruto"]
    m.adicionar("Corpo", "esfera", T(0, 0, h * 0.3), (h * 0.55, h * 0.55, h * 0.5), folha, 16)
    for k in range(8):  # pintas
        a = math.radians(k * 137.5)
        e = math.radians(-20 + (k * 17) % 50)
        normal = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        pos = Vector((normal.x * h * 0.27, normal.y * h * 0.27, h * 0.3 + normal.z * h * 0.245))
        m.adicionar("Corpo", "esfera", T(*pos) @ alinhar_z(normal), (h * 0.08, h * 0.08, 0.04), escurecer(folha, 0.25), 6)
    for k in range(5):
        folha_arqueada(m, "Corpo", (0, 0, 0.08), k * 72 + 20, 55, h * 0.42, 70, 0.55, escurecer(folha, 0.12))
    pescoco = curva((0, 0, h * 0.48), 270, 6, h * 0.36, 58, 4)
    for i in range(len(pescoco) - 1):
        m.entre("Corpo", pescoco[i], pescoco[i + 1], h * (0.17 - 0.012 * i), folha, 10, sobra=0.05)
    d = (pescoco[-1] - pescoco[-2]).normalized()
    boca = T(*pescoco[-1]) @ alinhar_z(d)
    m.adicionar("Corpo", "tronco", boca @ T(0, 0, h * 0.04), (h * 0.17, h * 0.17, h * 0.1), escurecer(folha, 0.22), 12, topo=1.5)
    m.adicionar("Corpo", "cilindro", boca @ T(0, 0, h * 0.09), (h * 0.27, h * 0.27, 0.06), escurecer(folha, 0.3), 12)
    m.adicionar("Brilho", "cilindro", boca @ T(0, 0, h * 0.085), (h * 0.18, h * 0.18, 0.05), cor, 12)
    for k in range(8):  # dentes
        a = math.radians(k * 45)
        base = boca @ Vector((math.cos(a) * h * 0.115, math.sin(a) * h * 0.115, h * 0.1))
        ponta = boca @ Vector((math.cos(a) * h * 0.08, math.sin(a) * h * 0.08, h * 0.16))
        m.entre("Corpo", base, ponta, 0.07, CREME, 4, "cone")
    for k in range(7):  # espinhos no corpo
        a = math.radians(k * 51 + 10)
        normal = Vector((math.cos(a), math.sin(a), 0.5)).normalized()
        base = Vector((normal.x * h * 0.25, normal.y * h * 0.25, h * 0.32 + normal.z * h * 0.2))
        m.entre("Corpo", base, base + normal * h * 0.12, 0.12, misturar(cor, BRANCO, 0.3), 5, "cone")
    if s["id"] == "DragonsBreath":
        for lado in (1, -1):  # chifres e asas
            m.entre("Corpo", boca @ Vector((lado * h * 0.08, h * 0.08, -h * 0.02)), boca @ Vector((lado * h * 0.14, h * 0.2, -h * 0.12)), 0.09, CREME, 5, "cone")
            m.adicionar("Corpo", "esfera", T(lado * h * 0.3, h * 0.05, h * 0.42) @ Ry(lado * 35), (h * 0.04, h * 0.3, h * 0.36), escurecer(folha, 0.2), 10)


def planta_popsicle(m, s):
    fx, fz, fh = fruto_blender(s["fruto"])
    produto, cor, folha = "Produto_" + s["id"], s["corFruto"], s["corFolha"]
    m.adicionar("Corpo", "cubo", T(0, 0, 0.36), (0.16, 0.07, 0.72), (220, 190, 130))
    camada = fh / 3
    base = 0.7
    m.adicionar(produto, "cilindro", T(0, 0, base + camada * 0.5), (fx, fz, camada), (60, 110, 230), 14)
    m.adicionar(produto, "cilindro", T(0, 0, base + camada * 1.5), (fx, fz, camada), BRANCO, 14)
    m.adicionar(produto, "cone", T(0, 0, base + camada * 2.6), (fx, fz, camada * 1.2), cor, 14)
    for lado in (1, -1):  # aletas do foguete
        m.adicionar(produto, "esfera", T(lado * fx * 0.5, 0, base + camada * 0.35) @ Ry(lado * 25), (fx * 0.35, fz * 0.3, camada * 0.9), cor, 10)
    for k in range(3):
        folha_arqueada(m, "Corpo", (0, 0, 0.05), k * 120 + 30, 40, 0.7, 80, 0.3, tom(folha, 0.05 * k))


def planta_pineapple(m, s):
    h, folha = s["altura"], s["corFolha"]
    m.adicionar("Corpo", "tronco", T(0, 0, h * 0.1), (0.4, 0.4, h * 0.2), escurecer(folha, 0.2), 8, topo=0.8)
    for i in range(14):
        inclinacao = 18 + (i % 3) * 22  # 18, 40 ou 62 graus
        comprimento = h * (0.95, 0.8, 0.62)[i % 3]
        base = Vector((0, 0, h * 0.12))
        d = direcao(i * 137.5, inclinacao)
        m.entre("Corpo", base, base + d * comprimento, 0.24, tom(folha, 0.06 * (i % 3) - 0.04), 4, "lamina", espessura=0.06)


def planta_glowshroom(m, s):
    h, caule, cor = s["altura"], s["corFolha"], s["corFruto"]
    cogumelos = ((0.0, 0.0, 0.84, 1.0), (0.42, 0.2, 0.52, 0.72), (-0.38, -0.25, 0.42, 0.6), (-0.18, 0.42, 0.3, 0.46), (0.3, -0.4, 0.24, 0.4))
    for x, y, altura, escala in cogumelos:
        px, py = x * h * 0.5, y * h * 0.5
        alt = h * altura
        m.adicionar("Corpo", "tronco", T(px, py, alt / 2), (0.3 * escala + 0.1, 0.3 * escala + 0.1, alt), caule, 8, topo=0.7)
        m.adicionar("Corpo", "cilindro", T(px, py, alt - h * 0.06 * escala), (h * 0.36 * escala, h * 0.36 * escala, 0.04), escurecer(caule, 0.1), 12)
        m.adicionar("Brilho", "esfera", T(px, py, alt), (h * 0.45 * escala, h * 0.45 * escala, h * 0.24 * escala), cor, 14)
        for k in range(4):
            a = math.radians(k * 90 + 30)
            m.adicionar("Corpo", "esfera", T(px + math.cos(a) * h * 0.11 * escala, py + math.sin(a) * h * 0.11 * escala, alt + h * 0.085 * escala),
                        (h * 0.06 * escala, h * 0.06 * escala, 0.03), clarear(cor, 0.55), 5)


def planta_blossom(m, s):
    h, folha = s["altura"], s["corFolha"]
    tronco = (90, 55, 40)
    pontos = [Vector((0, 0, 0)), Vector((0.05 * h, 0, 0.25 * h)), Vector((-0.02 * h, 0.02 * h, 0.45 * h))]
    for i in range(2):
        m.entre("Corpo", pontos[i], pontos[i + 1], h * (0.1 - 0.02 * i), tronco, 9, "tronco", topo=0.8, sobra=0.05)
    for az, inclinacao, comprimento in ((30, 55, 0.3), (150, 50, 0.28), (260, 60, 0.3), (90, 25, 0.25)):
        m.entre("Corpo", pontos[2], pontos[2] + direcao(az, inclinacao) * h * comprimento, h * 0.045, tronco, 7, "tronco", topo=0.6)
    for k in range(4):  # raizes
        m.adicionar("Corpo", "esfera", Rz(k * 90 + 20) @ T(h * 0.06, 0, h * 0.02), (h * 0.12, h * 0.05, h * 0.06), escurecer(tronco, 0.1), 8)
    tons = (folha, clarear(folha, 0.2), misturar(folha, (255, 120, 170), 0.25))
    copa = ((0.0, 0.0, 0.7, 0.8, 0.5), (0.25, 0.05, 0.8, 0.5, 0.38), (-0.24, -0.12, 0.76, 0.45, 0.35), (0.05, 0.26, 0.74, 0.45, 0.34),
            (-0.1, 0.2, 0.86, 0.4, 0.3), (0.18, -0.22, 0.66, 0.42, 0.32), (-0.28, 0.12, 0.62, 0.38, 0.3), (0.3, 0.2, 0.62, 0.36, 0.3), (0.0, 0.0, 0.9, 0.4, 0.22))
    for i, (x, y, z, w, a) in enumerate(copa):
        m.adicionar("Copa", "esfera", T(x * h, y * h, z * h), (w * h, w * h, a * h), tons[i % 3], 14)
    for i in range(16):  # petalas caidas no chao
        ang = math.radians(i * 137.5)
        r = h * (0.12 + 0.02 * (i % 9))
        m.adicionar("Corpo", "esfera", T(math.cos(ang) * r, math.sin(ang) * r, 0.02) @ Rz(i * 40), (0.18, 0.12, 0.025), tons[i % 3], 6)


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
    "vine": planta_vine,
    "fern": planta_fern,
    "flytrap": planta_flytrap,
    "bloom": planta_bloom,
    "sunflower": planta_sunflower,
    "spitter": planta_spitter,
    "popsicle": planta_popsicle,
    "pineapple": planta_pineapple,
    "glowshroom": planta_glowshroom,
    "blossom": planta_blossom,
}


# ---------------------------------------------------------------------------
# Frutos (centro na origem; "Produto" e o fruto, "Cabo" e o resto)
# ---------------------------------------------------------------------------

def cabinho(m, fh, comprimento=0.24, cor=CAULE, folha=True):
    m.adicionar("Cabo", "cilindro", T(0, 0, fh / 2 + comprimento * 0.35), (0.07, 0.07, comprimento), cor, 6)
    if folha:
        m.adicionar("Cabo", "esfera", T(0.1, 0, fh / 2 + comprimento * 0.5) @ Ry(65), (0.1, 0.035, 0.26), FOLHA, 8)


def fruto_padrao(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx, fz, fh), cor, 14)
    cabinho(m, fh)


def fruto_morango(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "cone", T(0, 0, -fh * 0.12) @ Rx(180), (fx, fz, fh * 0.76), cor, 12)
    m.adicionar(p, "esfera", T(0, 0, fh * 0.2), (fx, fz, fh * 0.5), cor, 12)
    for fila, (z, quantidade) in enumerate(((0.12, 7), (-0.06, 6), (-0.22, 5), (-0.36, 3))):  # sementinhas
        zz = fh * z
        raio_cone = (fx / 2) * (zz + fh * 0.5) / (fh * 0.76)
        raio_topo = (fx / 2) * math.sqrt(max(0.0, 1 - ((zz - fh * 0.2) / (fh * 0.25)) ** 2))
        raio = max(raio_cone, raio_topo) + 0.005
        for k in range(quantidade):
            a = math.radians(k * 360 / quantidade + fila * 25)
            m.adicionar(p, "esfera", T(math.cos(a) * raio, math.sin(a) * raio, zz), (0.045, 0.045, 0.06), (255, 225, 110), 4)
    for k in range(6):
        m.adicionar("Cabo", "esfera", Rz(k * 60) @ T(fx * 0.2, 0, fh * 0.44) @ Ry(12), (fx * 0.42, fx * 0.16, 0.035), FOLHA, 6)
    cabinho(m, fh, 0.2, folha=False)


def fruto_mirtilo(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx, fz, fh * 0.92), cor, 14)
    coroa = escurecer(cor, 0.3)
    m.adicionar(p, "esfera", T(0, 0, fh * 0.43), (fx * 0.28, fz * 0.28, 0.05), coroa, 8)
    for k in range(5):
        m.adicionar(p, "cone", Rz(k * 72) @ T(fx * 0.1, 0, fh * 0.46) @ Ry(25), (0.07, 0.07, 0.1), coroa, 4)


def fruto_tomate(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx, fz, fh * 0.9), cor, 16)
    for k in range(4):  # gomos
        m.adicionar(p, "esfera", Rz(k * 90 + 45) @ T(fx * 0.12, 0, 0), (fx * 0.8, fz * 0.75, fh * 0.86), cor, 12)
    for k in range(5):
        m.adicionar("Cabo", "esfera", Rz(k * 72) @ T(fx * 0.16, 0, fh * 0.43) @ Ry(15), (fx * 0.34, 0.07, 0.03), FOLHA, 6)
    cabinho(m, fh * 0.9, 0.18, folha=False)


def fruto_maca(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx, fz, fh * 0.92), cor, 16)
    m.adicionar(p, "esfera", T(0, 0, -fh * 0.32), (fx * 0.5, fz * 0.5, fh * 0.28), cor, 10)
    cabinho(m, fh * 0.85, 0.26, MADEIRA)


def fruto_milho(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", T(0, 0, fh * 0.05), (fx * 0.78, fz * 0.78, fh * 0.9), cor, 12)
    for k in range(10):  # fileiras de graos
        m.adicionar(p, "esfera", Rz(k * 36) @ T(fx * 0.3, 0, fh * 0.05), (0.06, 0.08, fh * 0.8), clarear(cor, 0.12), 6)
    palha = (140, 195, 85)
    for k in range(3):
        m.adicionar("Cabo", "esfera", Rz(k * 120 + 20) @ T(fx * 0.3, 0, -fh * 0.12) @ Ry(10), (0.06, fx * 0.55, fh * 0.75), tom(palha, 0.05 * k), 8)
    m.adicionar("Cabo", "cone", T(0, 0, fh * 0.52), (0.14, 0.14, 0.18), (200, 150, 90), 6)


def fruto_cacto(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx * 0.85, fz * 0.85, fh), cor, 12)
    for k in range(10):
        a = math.radians(k * 137.5)
        e = math.radians(-50 + (k * 23) % 100)
        pos = Vector((math.cos(a) * math.cos(e) * fx * 0.43, math.sin(a) * math.cos(e) * fz * 0.43, math.sin(e) * fh * 0.5))
        m.adicionar("Cabo", "esfera", T(*pos), (0.05, 0.05, 0.05), CREME, 4)
    m.adicionar("Cabo", "tronco", T(0, 0, fh * 0.5), (fx * 0.3, fz * 0.3, 0.08), escurecer(cor, 0.2), 8, topo=1.3)


def fruto_abacaxi(m, s, p, cor, fx, fz, fh):
    corpo_z = -fh * 0.14
    m.adicionar(p, "esfera", T(0, 0, corpo_z), (fx, fz, fh * 0.72), cor, 14)
    for fila in range(4):  # escamas
        e = math.radians(-45 + fila * 28)
        for k in range(7):
            a = math.radians(k * 360 / 7 + fila * 26)
            pos = Vector((math.cos(a) * math.cos(e) * fx * 0.5, math.sin(a) * math.cos(e) * fz * 0.5, corpo_z + math.sin(e) * fh * 0.36))
            m.adicionar(p, "esfera", T(*pos), (0.07, 0.07, 0.07), escurecer(cor, 0.28), 4)
    folha = (70, 160, 70)
    topo = Vector((0, 0, corpo_z + fh * 0.33))
    for k in range(8):
        d = direcao(k * 45 + 10, 18 + 14 * (k % 2))
        m.entre("Cabo", topo, topo + d * fh * (0.5 if k % 2 == 0 else 0.4), 0.1, tom(folha, 0.05 * (k % 3)), 4, "lamina", espessura=0.03)


def fruto_banana(m, s, p, cor, fx, fz, fh):
    theta = math.radians(75)
    raio = fh / theta
    partes = 6
    desvio = raio * (1 - math.cos(theta / 2)) / 2
    pontos = []
    for i in range(partes + 1):
        phi = -theta / 2 + theta * i / partes
        pontos.append(Vector((raio - raio * math.cos(phi) - desvio, 0, raio * math.sin(phi))))
    passo = fh / partes
    for i in range(partes):
        t = (i + 0.5) / partes
        w = fx * (0.45 + 0.55 * math.sin(math.pi * t))
        m.entre(p, pontos[i], pontos[i + 1], w, cor, 10, "esfera", w * 0.9, sobra=passo * 0.5)
    m.adicionar("Cabo", "esfera", T(*pontos[0]), (0.08, 0.08, 0.08), (70, 50, 30), 6)
    d = (pontos[-1] - pontos[-2]).normalized()
    m.entre("Cabo", pontos[-1], pontos[-1] + d * 0.18, 0.1, (110, 130, 60), 6, "tronco", topo=0.8)


def fruto_coco(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx, fz, fh), cor, 14)
    for k in range(3):  # fibras
        m.adicionar(p, "esfera", Rz(k * 60), (fx * 1.01, fz * 0.06, fh * 1.01), escurecer(cor, 0.18), 14)
    for k in range(3):  # "olhos"
        a = math.radians(k * 120)
        m.adicionar("Cabo", "esfera", T(math.cos(a) * fx * 0.1, math.sin(a) * fz * 0.1, fh * 0.48), (0.09, 0.09, 0.05), (60, 40, 25), 6)


def fruto_manga(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Ry(15), (fx * 0.85, fz * 0.8, fh), cor, 14)
    m.adicionar(p, "esfera", T(fx * 0.1, -fz * 0.05, fh * 0.12) @ Ry(15), (fx * 0.7, fz * 0.72, fh * 0.7), misturar(cor, (230, 80, 50), 0.45), 12)
    cabinho(m, fh * 0.95, 0.2)


def fruto_pitaya(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx * 0.8, fz * 0.8, fh * 0.86), cor, 14)
    aba = clarear(cor, 0.12)
    for fila, e_graus in enumerate((-35, 0, 35)):  # escamas com ponta verde
        e = math.radians(e_graus)
        for k in range(5):
            a = math.radians(k * 72 + fila * 36)
            normal = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
            base = Vector((normal.x * fx * 0.4, normal.y * fz * 0.4, normal.z * fh * 0.43))
            d = (normal + Vector((0, 0, 1.1))).normalized()
            fim = base + d * fh * 0.26
            m.entre(p, base, fim, fx * 0.2, aba, 8, "esfera", 0.04, sobra=0.04)
            m.entre("Cabo", fim - d * 0.03, fim + d * 0.07, 0.05, (120, 200, 80), 4, "cone")


def fruto_cereja(m, s, p, cor, fx, fz, fh):
    juncao = Vector((0, 0, fh * 0.62))
    for lado in (1, -1):
        c = Vector((lado * fx * 0.24, 0, -fh * 0.18))
        m.adicionar(p, "esfera", T(*c), (fx * 0.62, fz * 0.62, fh * 0.58), cor, 12)
        m.entre("Cabo", c + Vector((0, 0, fh * 0.26)), juncao, 0.045, CAULE, 5)
    m.adicionar("Cabo", "esfera", T(*(juncao + Vector((0.08, 0, 0.02)))) @ Ry(70), (0.1, 0.035, 0.26), FOLHA, 8)


def fruto_bolota(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", T(0, 0, -fh * 0.1), (fx * 0.82, fz * 0.82, fh * 0.78), cor, 12)
    m.adicionar(p, "cone", T(0, 0, -fh * 0.52) @ Rx(180), (0.1, 0.1, 0.1), escurecer(cor, 0.2), 6)
    tampa = escurecer(cor, 0.35)
    m.adicionar("Cabo", "esfera", T(0, 0, fh * 0.2), (fx * 0.96, fz * 0.96, fh * 0.42), tampa, 12)
    for k in range(10):
        a = math.radians(k * 36)
        m.adicionar("Cabo", "esfera", T(math.cos(a) * fx * 0.44, math.sin(a) * fz * 0.44, fh * 0.13), (0.09, 0.09, 0.07), clarear(tampa, 0.1), 5)
    m.adicionar("Cabo", "cilindro", T(0, 0, fh * 0.44), (0.07, 0.07, 0.14), tampa, 6)


def fruto_bagas(m, s, p, cor, fx, fz, fh):
    juncao = Vector((0, 0, fh * 0.45))
    for k in range(3):
        a = math.radians(k * 120 + 30)
        c = Vector((math.cos(a) * fx * 0.22, math.sin(a) * fz * 0.22, -fh * 0.12 + (fh * 0.12 if k == 0 else 0)))
        m.adicionar(p, "esfera", T(*c), (fx * 0.5, fz * 0.5, fh * 0.5), cor, 10)
        m.entre("Cabo", c + Vector((0, 0, fh * 0.2)), juncao, 0.04, CAULE, 5)
    m.adicionar("Cabo", "esfera", T(*(juncao + Vector((0.09, 0, 0.03)))) @ Ry(65), (0.11, 0.035, 0.26), (50, 120, 40), 8)


def fruto_chama(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", T(0, 0, -fh * 0.15), (fx, fz, fh * 0.7), cor, 12)
    m.adicionar(p, "cone", T(0, 0, fh * 0.2), (fx * 0.78, fz * 0.78, fh * 0.62), cor, 12)
    if s["id"] == "DragonsBreath":
        for lado in (1, -1):
            m.adicionar(p, "cone", T(lado * fx * 0.25, 0, fh * 0.05) @ Ry(lado * 30), (fx * 0.4, fz * 0.4, fh * 0.45), cor, 8)


def fruto_flor(m, s, p, cor, fx, fz, fh):
    for k in range(5):  # petalas viradas para cima
        m.adicionar(p, "esfera", Rz(k * 72) @ T(fx * 0.22, 0, 0) @ Ry(-18), (fx * 0.48, fx * 0.38, 0.05), cor, 10)
        m.adicionar(p, "esfera", Rz(k * 72) @ T(fx * 0.42, 0, fh * 0.06) @ Ry(-18), (fx * 0.1, fx * 0.16, 0.05), clarear(cor, 0.25), 6)
    m.adicionar("Cabo", "esfera", T(0, 0, 0.03), (fx * 0.2, fx * 0.2, 0.1), (255, 220, 90), 8)
    for k in range(6):
        a = math.radians(k * 60)
        m.adicionar("Cabo", "esfera", T(math.cos(a) * fx * 0.1, math.sin(a) * fx * 0.1, 0.09), (0.04, 0.04, 0.04), (255, 240, 150), 4)
    for lado in (1, -1):  # botoes
        c = Vector((lado * fx * 0.38, -fz * 0.2, -fh * 0.32))
        m.adicionar(p, "esfera", T(*c), (fx * 0.2, fx * 0.2, fh * 0.25), clarear(cor, 0.1), 8)
        m.entre("Cabo", c + Vector((0, 0, fh * 0.1)), Vector((0, 0, -0.02)), 0.03, CAULE, 4)


def fruto_girassol(m, s, p, cor, fx, fz, fh):
    cabeca = alinhar_z(Vector((0.0, -1.0, 0.35)))
    miolo = (110, 70, 30)
    m.adicionar("Cabo", "cilindro", cabeca, (fx * 0.48, fx * 0.48, fz * 0.32), miolo, 14)
    for k in range(8):
        a = math.radians(k * 45)
        m.adicionar("Cabo", "esfera", cabeca @ T(math.cos(a) * fx * 0.13, math.sin(a) * fx * 0.13, fz * 0.16), (0.07, 0.07, 0.04), escurecer(miolo, 0.3), 4)
    for k in range(12):
        m.adicionar(p, "esfera", cabeca @ Rz(k * 30) @ T(0, fx * 0.34, 0), (fx * 0.15, fx * 0.3, 0.05),
                    cor if k % 2 == 0 else misturar(cor, (255, 160, 30), 0.3), 8)
    m.adicionar("Cabo", "cilindro", cabeca @ T(0, 0, -fz * 0.2), (fx * 0.42, fx * 0.42, 0.06), FOLHA, 12)


def fruto_armadilha(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", T(0, 0, -fh * 0.05), (fx * 0.85, fz * 0.85, fh * 0.8), cor, 12)
    m.adicionar("Cabo", "esfera", T(0, 0, fh * 0.28), (fx * 0.95, fz * 0.95, fh * 0.35), (90, 180, 60), 12)
    for k in range(10):  # dentinhos
        a = math.radians(k * 36)
        base = Vector((math.cos(a) * fx * 0.44, math.sin(a) * fz * 0.44, fh * 0.2))
        m.entre("Cabo", base, base + Vector((math.cos(a) * 0.08, math.sin(a) * 0.08, -0.12)), 0.04, BRANCO, 4, "cone")


def fruto_pimenta(m, s, p, cor, fx, fz, fh):
    pontos = [Vector((0, 0, fh * 0.36)), Vector((0, 0, fh * 0.06)), Vector((fx * 0.06, 0, -fh * 0.2)), Vector((fx * 0.22, 0, -fh * 0.42)), Vector((fx * 0.42, 0, -fh * 0.5))]
    larguras = (fx, fx * 0.88, fx * 0.62, fx * 0.32)
    for i in range(4):
        m.entre(p, pontos[i], pontos[i + 1], larguras[i], cor, 12, "esfera", larguras[i] * fz / fx, sobra=fh * 0.12)
    if s["id"] in ("GhostPepper", "InfernoPepper"):  # enrugada
        for k in range(8):
            t = (k + 0.5) / 8
            centro = ponto_na_linha(pontos, t * 0.85)
            a = math.radians(k * 137.5)
            r = fx * (0.42 - 0.25 * t)
            m.adicionar(p, "esfera", T(centro.x + math.cos(a) * r, math.sin(a) * r, centro.z), (fx * 0.3, fx * 0.3, fx * 0.24), cor, 6)
    m.adicionar("Cabo", "tronco", T(0, 0, fh * 0.42), (fx * 0.8, fz * 0.8, fh * 0.1), FOLHA, 10, topo=0.6)
    m.adicionar("Cabo", "cilindro", T(0, 0, fh * 0.53) @ Ry(20), (0.07, 0.07, fh * 0.16), FOLHA, 6)


def fruto_roma(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx, fz, fh * 0.92), cor, 16)
    coroa = escurecer(cor, 0.2)
    m.adicionar(p, "tronco", T(0, 0, fh * 0.47), (fx * 0.32, fz * 0.32, fh * 0.14), coroa, 10, topo=0.85)
    for k in range(6):
        a = math.radians(k * 60)
        base = Vector((math.cos(a) * fx * 0.13, math.sin(a) * fz * 0.13, fh * 0.53))
        m.entre(p, base, base + Vector((math.cos(a) * 0.05, math.sin(a) * 0.05, 0.1)), 0.06, coroa, 4, "cone")


def fruto_cacau(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx * 0.8, fz * 0.8, fh), cor, 14)
    for k in range(8):  # gomos
        m.adicionar(p, "esfera", Rz(k * 45) @ T(fx * 0.32, 0, 0), (0.08, 0.1, fh * 0.9), tom(cor, 0.1 if k % 2 else -0.12), 6)
    cabinho(m, fh, 0.2, MADEIRA, folha=False)


def fruto_espinhos(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx * 0.8, fz * 0.8, fh * 0.8), cor, 12)
    espinho = clarear(cor, 0.3)
    for k in range(12):
        d = esfera_fibonacci(k, 12)
        base = Vector((d.x * fx * 0.38, d.y * fz * 0.38, d.z * fh * 0.38))
        m.entre(p, base, base + d * fx * 0.2, 0.1, espinho, 5, "cone")
    m.adicionar(p, "esfera", T(0, 0, -fh * 0.46), (0.12, 0.12, 0.16), clarear(cor, 0.15), 6)  # gota de veneno


def fruto_gema(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "gema", T(0, 0, -fh * 0.08), (fx, fz, fh * 0.75), cor, 6)
    m.adicionar(p, "cone", T(0, 0, fh * 0.32), (fx * 0.62, fz * 0.62, fh * 0.32), cor, 6)


def fruto_lua(m, s, p, cor, fx, fz, fh):
    quantidade = 11
    raio = fx * 0.32
    for i in range(quantidade):
        t = i / (quantidade - 1)
        ang = math.radians(-115 + 230 * t)
        tam = fx * 0.4 * (1 - 0.75 * abs(2 * t - 1) ** 1.6)
        m.adicionar(p, "esfera", T(math.cos(ang) * raio, 0, math.sin(ang) * raio), (tam, tam * 0.8, tam), cor, 10)


def fruto_sol(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx * 0.62, fz * 0.62, fh * 0.62), cor, 12)
    raio_cor = misturar(cor, (255, 140, 30), 0.35)
    for k in range(14):
        d = esfera_fibonacci(k, 14)
        m.entre(p, d * fx * 0.28, d * fx * 0.52, 0.12, raio_cor, 5, "cone")


def fruto_hipno(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx * 0.85, fz * 0.85, fh * 0.85), cor, 14)
    for i in range(18):  # espiral branca
        t = i / 17
        ang = math.radians(t * 900)
        e = math.radians(-70 + 140 * t)
        d = Vector((math.cos(ang) * math.cos(e) * fx, math.sin(ang) * math.cos(e) * fz, math.sin(e) * fh))
        m.adicionar("Cabo", "esfera", T(*(d * 0.43)), (0.09, 0.09, 0.09), BRANCO, 5)


def fruto_eclipse(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx * 0.72, fz * 0.72, fh * 0.72), cor, 14)
    for k in range(18):  # coroa dourada
        a = math.radians(k * 20)
        tam = 0.11 if k % 2 == 0 else 0.07
        m.adicionar("Cabo", "esfera", T(math.cos(a) * fx * 0.46, 0, math.sin(a) * fh * 0.46), (tam, tam, tam), (255, 200, 90), 5)


def fruto_vagem(m, s, p, cor, fx, fz, fh):
    pontos = [Vector((0, 0, fh * 0.48)), Vector((fx * 0.18, 0, fh * 0.12)), Vector((fx * 0.12, 0, -fh * 0.22)), Vector((-fx * 0.12, 0, -fh * 0.48))]
    for i in range(3):
        m.entre(p, pontos[i], pontos[i + 1], fx * 0.72, cor, 10, "esfera", fz * 0.5, sobra=fh * 0.14)
    for i in range(4):  # graos marcando a vagem
        pos = ponto_na_linha(pontos, (i + 0.6) / 4.6)
        m.adicionar(p, "esfera", T(pos.x, -fz * 0.12, pos.z), (fx * 0.5, fz * 0.4, fx * 0.55), clarear(cor, 0.06), 8)
    m.entre("Cabo", pontos[0], pontos[0] + Vector((0.02, 0, 0.12)), 0.06, CAULE, 5)


def fruto_carambola(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx * 0.36, fz * 0.36, fh * 0.94), cor, 10)
    for k in range(5):  # as 5 pontas da estrela
        m.adicionar(p, "esfera", Rz(k * 72) @ T(fx * 0.2, 0, 0), (fx * 0.42, fx * 0.16, fh), cor, 12)
    cabinho(m, fh, 0.16, folha=False)


def fruto_planeta(m, s, p, cor, fx, fz, fh):
    m.adicionar(p, "esfera", Matrix.Identity(4), (fx * 0.72, fz * 0.72, fh * 0.72), cor, 14)
    m.adicionar("Cabo", "cilindro", Rx(22), (fx * 1.25, fz * 1.25, 0.03), (205, 175, 255), 20)  # anel
    for k in range(4):
        a = math.radians(k * 90 + 30)
        m.adicionar("Cabo", "gema", T(math.cos(a) * fx * 0.55, math.sin(a) * fz * 0.55, fh * (0.3 if k % 2 else -0.25)), (0.08, 0.08, 0.08), (255, 250, 210), 6)


def fruto_cogumelo(m, s, p, cor, fx, fz, fh):
    m.adicionar("Cabo", "tronco", T(0, 0, -fh * 0.22), (fx * 0.3, fz * 0.3, fh * 0.5), (240, 230, 210), 8, topo=0.8)
    m.adicionar(p, "esfera", T(0, 0, fh * 0.12), (fx, fz, fh * 0.62), cor, 12)
    for k in range(4):
        a = math.radians(k * 90 + 20)
        m.adicionar("Cabo", "esfera", T(math.cos(a) * fx * 0.3, math.sin(a) * fz * 0.3, fh * 0.36), (0.1, 0.1, 0.04), clarear(cor, 0.5), 5)


def fruto_uva(m, s, p, cor, fx, fz, fh):
    raio_uva = fx * 0.3
    for camada, quantidade in enumerate((5, 4, 3, 1)):  # cacho
        z = fh * (0.25 - camada * 0.22)
        anel = fx * 0.07 * quantidade
        for i in range(quantidade):
            a = math.radians(i * 360 / quantidade + camada * 30)
            m.adicionar(p, "esfera", T(math.cos(a) * anel, math.sin(a) * anel, z), (raio_uva, raio_uva, raio_uva), cor if (i + camada) % 3 else clarear(cor, 0.08), 8)
    m.adicionar("Cabo", "cilindro", T(0, 0, fh * 0.45), (0.06, 0.06, 0.2), MADEIRA, 6)
    m.adicionar("Cabo", "esfera", T(0.1, 0, fh * 0.5) @ Ry(70), (0.14, 0.04, 0.3), FOLHA, 8)


FORMAS_FRUTO = {
    "Strawberry": fruto_morango,
    "Blueberry": fruto_mirtilo,
    "Tomato": fruto_tomate,
    "Apple": fruto_maca,
    "PoisonApple": fruto_maca,
    "Corn": fruto_milho,
    "Cactus": fruto_cacto,
    "Pineapple": fruto_abacaxi,
    "Banana": fruto_banana,
    "Grape": fruto_uva,
    "GlowMushroom": fruto_cogumelo,
    "GreenBean": fruto_vagem,
    "Beanstalk": fruto_vagem,
    "Coconut": fruto_coco,
    "Mango": fruto_manga,
    "DragonFruit": fruto_pitaya,
    "Cherry": fruto_cereja,
    "Acorn": fruto_bolota,
    "PoisonIvy": fruto_bagas,
    "FireFern": fruto_chama,
    "DragonsBreath": fruto_chama,
    "CherryBlossom": fruto_flor,
    "Sunflower": fruto_girassol,
    "VenusFlyTrap": fruto_armadilha,
    "Pepper": fruto_pimenta,
    "GhostPepper": fruto_pimenta,
    "InfernoPepper": fruto_pimenta,
    "Pomegranate": fruto_roma,
    "VenomSpitter": fruto_espinhos,
    "Cacao": fruto_cacau,
    "RainbowSeed": fruto_gema,
    "MoonBloom": fruto_lua,
    "SunBloom": fruto_sol,
    "HypnoBloom": fruto_hipno,
    "EclipseBloom": fruto_eclipse,
    "StarFruit": fruto_carambola,
    "GalaxyFruit": fruto_planeta,
}


def construir_fruto(m, s):
    FORMAS_FRUTO.get(s["id"], fruto_padrao)(m, s, "Produto_" + s["id"], s["corFruto"], *fruto_blender(s["fruto"]))


# ---------------------------------------------------------------------------
# Sprinklers, ovos, gnomo e lanterna
# ---------------------------------------------------------------------------

def construir_sprinkler(m, cor, nivel):
    m.adicionar("Base", "cilindro", T(0, 0, 0.12), (1.4, 1.4, 0.24), CINZA_ESCURO, 16)
    m.adicionar("Base", "tronco", T(0, 0, 0.32), (1.1, 1.1, 0.18), CINZA, 16, topo=0.6)
    m.adicionar("Cano", "cilindro", T(0, 0, 1.0), (0.26, 0.26, 1.4), CINZA, 10)
    m.adicionar("Cano", "cilindro", T(0, 0, 1.62), (0.36, 0.36, 0.1), CINZA_ESCURO, 10)
    # a agua sai da "Cabeca" no jogo
    m.adicionar("Cabeca", "esfera", T(0, 0, 1.9), (0.8, 0.8, 0.7), cor, 14)
    bicos = 2 + 2 * nivel
    for i in range(bicos):
        m.adicionar("Cabeca", "cilindro", T(0, 0, 1.92) @ Rz(i * 360 / bicos) @ T(0.45, 0, 0) @ Ry(80), (0.12, 0.12, 0.3), escurecer(cor, 0.2), 6)
    if nivel >= 3:  # anel
        m.adicionar("Cabeca", "cilindro", T(0, 0, 1.75), (1.05, 1.05, 0.06), escurecer(cor, 0.1), 18)
    if nivel >= 4:  # coroa
        for i in range(6):
            m.adicionar("Cabeca", "cone", T(0, 0, 2.2) @ Rz(i * 60) @ T(0.24, 0, 0.06), (0.12, 0.12, 0.22), OURO, 5)
    if nivel >= 5:  # gema
        m.adicionar("Cabeca", "gema", T(0, 0, 2.38), (0.3, 0.3, 0.36), (255, 80, 200), 6)


def construir_ovo(m, cor, nivel):
    m.adicionar("Casca", "esfera", T(0, 0, 1.0), (1.6, 1.6, 2.0), cor, 20)
    pinta = escurecer(cor, 0.25)
    claro = clarear(cor, 0.4)
    for i in range(6):  # pintas
        a = math.radians(i * 60 + 15)
        e = math.radians(28 if i % 2 else -12)
        normal = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        pos = Vector((normal.x * 0.79, normal.y * 0.79, 1.0 + normal.z * 0.99))
        m.adicionar("Casca", "esfera", T(*pos) @ alinhar_z(normal), (0.38, 0.38, 0.08), pinta, 8)
    if nivel >= 2:  # faixa
        m.adicionar("Casca", "esfera", T(0, 0, 0.95), (1.63, 1.63, 0.18), claro, 20)
    if nivel >= 3:  # zigue-zague
        for k in range(14):
            a = math.radians(k * 360 / 14)
            base = Vector((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.95))
            m.entre("Casca", base, base + Vector((math.cos(a) * 0.02, math.sin(a) * 0.02, 0.2 if k % 2 else -0.2)), 0.14, claro, 4, "cone")
    if nivel >= 4:  # gemas na faixa
        for k in range(8):
            a = math.radians(k * 45 + 22.5)
            m.adicionar("Casca", "gema", T(math.cos(a) * 0.82, math.sin(a) * 0.82, 0.95), (0.16, 0.16, 0.16), (255, 250, 220), 6)
    if nivel >= 5:  # espiral
        for i in range(20):
            t = i / 19
            a = math.radians(t * 720)
            z = 0.2 + 1.6 * t
            raio = 0.8 * math.sqrt(max(0.0, 1 - ((z - 1.0) / 1.0) ** 2)) + 0.01
            m.adicionar("Casca", "esfera", T(math.cos(a) * raio, math.sin(a) * raio, z), (0.12, 0.12, 0.12), BRANCO, 5)
    if nivel >= 6:  # coroa
        for k in range(6):
            m.adicionar("Casca", "cone", T(0, 0, 1.9) @ Rz(k * 60) @ T(0.24, 0, 0.05), (0.14, 0.14, 0.26), OURO, 5)
        m.adicionar("Casca", "gema", T(0, 0, 2.05), (0.24, 0.24, 0.3), (255, 60, 90), 6)


def construir_gnomo(m):
    pele, azul, vermelho, marrom = (255, 205, 170), (60, 100, 200), (220, 50, 50), (90, 60, 40)
    for lado in (1, -1):  # botas
        m.adicionar("Corpo", "esfera", T(lado * 0.2, -0.08, 0.1), (0.32, 0.45, 0.2), marrom, 10)
    m.adicionar("Corpo", "tronco", T(0, 0, 0.55), (0.92, 0.92, 0.8), azul, 16, topo=0.7)  # casaco
    m.adicionar("Corpo", "cilindro", T(0, 0, 0.42), (0.88, 0.88, 0.1), PRETO, 16)  # cinto
    m.adicionar("Corpo", "cubo", T(0, -0.44, 0.42), (0.18, 0.04, 0.14), OURO)  # fivela
    for lado in (1, -1):  # bracos e maos
        m.adicionar("Corpo", "esfera", T(lado * 0.42, -0.05, 0.62) @ Ry(lado * 20), (0.22, 0.22, 0.5), azul, 10)
        m.adicionar("Cabeca", "esfera", T(lado * 0.48, -0.1, 0.38), (0.17, 0.17, 0.17), pele, 8)
    m.adicionar("Cabeca", "esfera", T(0, 0, 1.12), (0.62, 0.62, 0.6), pele, 14)
    m.adicionar("Cabeca", "esfera", T(0, -0.31, 1.1), (0.17, 0.17, 0.17), (255, 160, 140), 8)  # nariz
    for lado in (1, -1):
        m.adicionar("Cabeca", "esfera", T(lado * 0.12, -0.27, 1.22), (0.07, 0.04, 0.08), PRETO, 6)  # olhos
    m.adicionar("Barba", "esfera", T(0, -0.16, 0.9), (0.6, 0.42, 0.62), BRANCO, 12)
    m.adicionar("Barba", "esfera", T(0, -0.3, 1.02), (0.36, 0.12, 0.1), BRANCO, 8)  # bigode
    m.adicionar("Chapeu", "tronco", T(0, 0, 1.4), (0.72, 0.72, 0.16), vermelho, 14, topo=0.9)
    pontos = [Vector((0, 0, 1.45)), Vector((0, 0.02, 1.85)), Vector((0, 0.12, 2.15)), Vector((0, 0.3, 2.3))]
    for i, largura in enumerate((0.66, 0.42, 0.22)):  # gorro pontudo dobrado para tras
        m.entre("Chapeu", pontos[i], pontos[i + 1], largura, vermelho, 12, "tronco", topo=0.62, sobra=0.03)


def construir_lanterna(m):
    metal = (60, 60, 70)
    m.adicionar("Poste", "cilindro", T(0, 0, 0.06), (0.6, 0.6, 0.12), metal, 12)
    m.adicionar("Poste", "cilindro", T(0, 0, 1.55), (0.16, 0.16, 3.0), metal, 8)
    m.adicionar("Poste", "esfera", T(0, 0, 3.08), (0.22, 0.22, 0.22), metal, 8)
    m.entre("Poste", (0, 0, 3.0), (0.78, 0, 3.0), 0.09, metal, 6)
    m.adicionar("Poste", "cilindro", T(0.65, 0, 2.94), (0.03, 0.03, 0.12), metal, 4)  # gancho
    m.adicionar("Poste", "cone", T(0.65, 0, 2.82) @ Rz(45), (0.6, 0.6, 0.16), metal, 4)  # telhadinho
    m.adicionar("Poste", "cubo", T(0.65, 0, 2.3), (0.46, 0.46, 0.06), metal)  # base
    for dx, dy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):  # grade
        m.adicionar("Poste", "cubo", T(0.65 + dx * 0.2, dy * 0.2, 2.53), (0.04, 0.04, 0.46), metal)
    m.adicionar("Vidro", "cubo", T(0.65, 0, 2.53), (0.38, 0.38, 0.44), (255, 220, 130))  # a luz fica aqui


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


def mover(objetos, deslocamento, escala=1.0):
    for objeto in objetos:
        objeto.scale = (escala, escala, escala)
        objeto.location = Vector(objeto.location) + Vector(deslocamento)


def criar_camera(colecao, nome, posicao, alvo, lente):
    dados = bpy.data.cameras.new(nome)
    dados.lens = lente
    dados.clip_end = 500
    objeto = bpy.data.objects.new(nome, dados)
    colecao.objects.link(objeto)
    objeto.location = posicao
    objeto.rotation_euler = (Vector(alvo) - Vector(posicao)).to_track_quat("-Z", "Y").to_euler()
    return objeto


def montar_vitrine(cena, colecao, material, largura, frente, fundo, linhas):
    # chao de grama e canteiros de terra para as imagens de previa
    chao = Modelo("Chao")
    chao.adicionar("Chao", "cubo", T(largura / 2, (frente + fundo) / 2, -0.25), (largura + 60, fundo - frente + 60, 0.5), GRAMA)
    for y in linhas:
        chao.adicionar("Chao", "cubo", T(largura / 2, y - 0.8, 0.02), (largura + 4, 5.8, 0.1), TERRA)
    chao.finalizar(colecao, material)

    sol_dados = bpy.data.lights.new("Sol", type="SUN")
    sol_dados.energy = 3.5
    sol_dados.angle = math.radians(3)
    sol = bpy.data.objects.new("Sol", sol_dados)
    sol.rotation_euler = (math.radians(42), math.radians(12), math.radians(28))
    colecao.objects.link(sol)

    mundo = bpy.data.worlds.new("Ceu")
    mundo.use_nodes = True
    fundo_no = mundo.node_tree.nodes.get("Background")
    if fundo_no:
        fundo_no.inputs["Color"].default_value = (0.55, 0.75, 1.0, 1.0)
        fundo_no.inputs["Strength"].default_value = 0.9
    cena.world = mundo


def renderizar(cena, camera, caminho, largura=1600, altura=900):
    cena.camera = camera
    cena.render.engine = "CYCLES"
    cena.cycles.samples = 24
    cena.cycles.use_denoising = False
    cena.render.resolution_x = largura
    cena.render.resolution_y = altura
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
        dict(id=i, nome=n, tipo=t, altura=h, multi=mu, maxFrutos=mf, corFruto=cf, corFolha=cl, fruto=fs, extras=ex)
        for (i, n, t, h, mu, mf, cf, cl, fs, ex) in SEMENTES
    ]

    # 1) monta todos os modelos na origem (as cores ja vao para a paleta).
    #    Vitrine: plantas da mais baixa (frente) para a mais alta (fundo), fruto ao lado (2x maior).
    modelos = []  # (Modelo, (x, y), escala na vitrine)
    colunas, passo_x, passo_y = 9, 4.2, 8.5
    linhas = []
    for indice, s in enumerate(sorted(sementes, key=lambda item: item["altura"])):
        x, y = (indice % colunas) * passo_x, (indice // colunas) * passo_y
        if y not in linhas:
            linhas.append(y)
        planta = Modelo("Planta_" + s["id"])
        CONSTRUTORES[s["tipo"]](planta, s)
        modelos.append((planta, (x, y), 1.0))
        if s["multi"]:
            fruto = Modelo("Fruto_" + s["id"])
            construir_fruto(fruto, s)
            modelos.append((fruto, (x + 1.7, y - 2.5), 2.0))
    y_itens = -7.5
    linhas.append(y_itens)
    for indice, (gid, _nome, cor, nivel) in enumerate(SPRINKLERS):
        sprinkler = Modelo("Sprinkler_" + gid)
        construir_sprinkler(sprinkler, cor, nivel)
        modelos.append((sprinkler, (indice * 2.6, y_itens), 1.0))
    for indice, (oid, _nome, cor) in enumerate(OVOS):
        ovo = Modelo("Ovo_" + oid)
        construir_ovo(ovo, cor, indice + 1)
        modelos.append((ovo, (14.0 + indice * 2.4, y_itens), 1.0))
    gnomo = Modelo("Gnomo")
    construir_gnomo(gnomo)
    modelos.append((gnomo, (29.5, y_itens), 1.0))
    lanterna = Modelo("Lanterna")
    construir_lanterna(lanterna)
    modelos.append((lanterna, (32.0, y_itens), 1.0))

    # 2) cria a textura de paleta e o material
    for cor in (GRAMA, TERRA):
        PALETA.indice(cor)
    imagem = PALETA.criar_imagem(os.path.join(pasta_fbx, "Paleta.png"))
    material = criar_material(imagem)
    print("Cores na paleta:", len(PALETA.cores))

    # 3) cria os objetos, exporta cada modelo e coloca na vitrine
    exportados = set()
    for modelo, (x, y), escala in modelos:
        colecao = bpy.data.collections.new(modelo.nome)
        cena.collection.children.link(colecao)
        minimo, _maximo = modelo.limites()
        objetos = modelo.finalizar(colecao, material)
        bpy.context.view_layer.update()
        exportar_fbx(objetos, os.path.join(pasta_fbx, modelo.nome + ".fbx"))
        exportados.add(modelo.nome + ".fbx")
        mover(objetos, (x, y, -minimo.z * escala + 0.07), escala)
        print("Exportado:", modelo.nome)
    # apaga .fbx antigos que o jogo nao usa mais (ids que mudaram de nome)
    for arquivo in sorted(os.listdir(pasta_fbx)):
        if arquivo.endswith(".fbx") and arquivo not in exportados:
            os.remove(os.path.join(pasta_fbx, arquivo))
            print("Removido (antigo):", arquivo)

    vitrine = bpy.data.collections.new("Vitrine")
    cena.collection.children.link(vitrine)
    largura = (colunas - 1) * passo_x
    fundo = max(linhas)
    montar_vitrine(cena, vitrine, material, largura, y_itens, fundo, linhas)
    meio = largura / 2
    cameras = [
        ("previa_modelos.jpg", criar_camera(vitrine, "Camera", (meio, y_itens - 30, 30), (meio, fundo * 0.4, 0), 26)),
        ("previa_plantas_altas.jpg", criar_camera(vitrine, "CameraFundo", (meio, linhas[2] - 9, 13), (meio, fundo, 3.5), 24)),
        ("previa_plantas_baixas.jpg", criar_camera(vitrine, "CameraFrente", (meio, y_itens - 9, 9), (meio, linhas[1], 0.5), 24)),
    ]
    cena.camera = cameras[0][1]

    caminho_blend = os.path.join(saida, "CultiveUmJardim_Modelos.blend")
    imagem.pack()
    if bpy.app.background:
        bpy.context.preferences.filepaths.save_version = 0  # sem arquivo de backup .blend1
    # copy=True: salva uma copia sem trocar o arquivo que voce esta editando
    bpy.ops.wm.save_as_mainfile(filepath=caminho_blend, copy=not bpy.app.background)
    print("Arquivo .blend salvo em:", caminho_blend)

    if RENDERIZAR_PREVIA:
        for nome_arquivo, camera in cameras:
            renderizar(cena, camera, os.path.join(saida, nome_arquivo))
        print("Previas renderizadas.")

    print("Pronto! %d modelos exportados para %s" % (len(modelos), pasta_fbx))


if __name__ == "__main__":
    principal()
