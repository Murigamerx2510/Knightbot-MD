# 🌱 Cultive um Jardim — jogo estilo "Grow a Garden" para Roblox

Jogo completo de fazenda para Roblox, inspirado no Grow a Garden: compre sementes, plante no seu
jardim, colha frutos, venda, compre equipamentos, choque ovos de pets e aproveite o clima que cria
mutações valiosas. Os modelos 3D foram feitos no **Blender** (por script) e a lógica do jogo roda no
**Roblox Studio** (Luau).

![Mapa do jogo](docs/mapa.jpg)

> **Importante:** um jogo de Roblox não pode ser feito *só* no Blender. O Blender faz os **modelos 3D**,
> e o jogo em si (regras, lojas, salvamento, interface) precisa ser feito em **Luau, no Roblox Studio**.
> Por isso o projeto tem as duas partes: `src/` (scripts do Roblox) e `blender/` (modelos 3D).
>
> O nome "Grow a Garden" e os modelos originais pertencem aos criadores do jogo original. Este é um jogo
> **original inspirado** nele, com nome, código e modelos próprios. Não use o nome nem as artes do
> original se for publicar.

---

## ✨ O que tem no jogo

| Sistema | Como funciona |
|---|---|
| 🏡 **6 jardins** | Cada jogador ganha um jardim cercado com placa com seu nome. |
| 🌱 **20 sementes** | Cenoura, Morango, Mirtilo, Tulipa, Tomate, Narciso, Milho, Melancia, Abóbora, Maçã, Bambu, Coco, Cacto, Pitaya, Manga, Cogumelo, Uva, Pimenta, Cacau e Pé de Feijão. |
| 🔁 **Colheita única ou várias** | Algumas plantas são colhidas uma vez; outras ficam e dão frutos várias vezes. |
| ⏱️ **Crescimento offline** | As plantas continuam crescendo mesmo com você fora do jogo. |
| 🛒 **Lojas com estoque** | Sam (sementes), Eloise (equipamentos) e Ray (ovos). O estoque muda a cada 5 minutos e é igual em todos os servidores. |
| 💰 **Venda** | Steven compra seus frutos. O valor depende da raridade, do **peso** e das **mutações**. |
| ✨ **Mutações** | Dourado (x20), Arco-íris (x50), Molhado (x2), Gelado (x2), Congelado (x10), Eletrizado (x100). |
| 🌧️ **Clima** | Chuva, Geada e Tempestade com raios. Mudam a iluminação, aceleram plantas e criam mutações. |
| 🔧 **Equipamentos** | Regador, Pá e 4 tipos de Sprinkler. |
| 🥚 **Ovos e 12 pets** | Choque ovos no jardim. Os pets seguem você e dão bônus de Crescimento, Venda ou Sorte. |
| 💾 **Salvamento** | DataStore com novas tentativas, salvamento automático e ao fechar o servidor. |
| 📱 **Interface** | HUD, lojas, inventário, venda, pets, avisos e faixa de clima. Funciona no PC e no celular. |

<p>
<img src="docs/tela_loja.jpg" width="49%"> <img src="docs/tela_venda.jpg" width="49%">
<img src="docs/tela_pets.jpg" width="49%"> <img src="docs/tela_chuva.jpg" width="49%">
<img src="docs/jardim.jpg" width="49%"> <img src="docs/loja.jpg" width="49%">
</p>

*Prévias geradas pelo simulador de testes (veja abaixo). No Roblox o visual fica parecido, com os
textos das placas e a iluminação do Roblox.*

---

## 🚀 Como abrir no Roblox Studio

### Opção 1 — Abrir o arquivo pronto (mais fácil)

1. Baixe o arquivo **`CultiveUmJardim.rbxlx`** desta pasta.
2. Abra o **Roblox Studio** → **Arquivo › Abrir do Arquivo** (*File › Open from File*) → escolha o `.rbxlx`.
3. Aperte **Play (F5)**. O mapa inteiro é criado sozinho quando o jogo começa.

> No modo de edição o mundo aparece vazio: é normal, porque o mapa é gerado por código ao dar Play.

### Opção 2 — Copiar os scripts à mão

Crie no Explorer exatamente esta estrutura e cole o conteúdo de cada arquivo:

```
ReplicatedStorage
├── Shared            (Folder)
│   ├── Config        (ModuleScript)  ← src/ReplicatedStorage/Shared/Config.luau
│   └── Formulas      (ModuleScript)  ← src/ReplicatedStorage/Shared/Formulas.luau
└── Modelos           (Folder)        ← aqui vão os modelos do Blender (opcional)

ServerScriptService
└── GardenServer      (Script)        ← src/ServerScriptService/GardenServer/init.server.luau
    ├── DataService   (ModuleScript)  ← DataService.luau
    ├── GardenService (ModuleScript)  ← GardenService.luau
    ├── Inventory     (ModuleScript)  ← Inventory.luau
    ├── MapBuilder    (ModuleScript)  ← MapBuilder.luau
    ├── PetService    (ModuleScript)  ← PetService.luau
    ├── Remotes       (ModuleScript)  ← Remotes.luau
    ├── ShopService   (ModuleScript)  ← ShopService.luau
    ├── Sync          (ModuleScript)  ← Sync.luau
    ├── Visuals       (ModuleScript)  ← Visuals.luau
    └── WeatherService(ModuleScript)  ← WeatherService.luau

StarterPlayer
└── StarterPlayerScripts
    └── GardenClient  (LocalScript)   ← src/StarterPlayerScripts/GardenClient/init.client.luau
        ├── Effects   (ModuleScript)  ← Effects.luau
        └── Interface (ModuleScript)  ← Interface.luau
```

Os ModuleScripts ficam **dentro** do Script/LocalScript (como filhos), e os nomes precisam ser iguais.

### Opção 3 — Rojo (para quem programa)

```bash
rojo serve        # sincroniza com o Studio usando default.project.json
rojo build -o CultiveUmJardim.rbxlx
```

### Configurações recomendadas

1. **Salvar o progresso:** publique o jogo (*File › Publish to Roblox*) e ative
   **Game Settings › Security › Enable Studio Access to API Services**.
   Sem isso o jogo funciona normalmente, mas avisa que não vai salvar.
2. **Máximo de jogadores:** em **Game Settings › Places**, coloque **6 jogadores por servidor**
   (um jardim por jogador). Se entrar um 7º, ele recebe uma mensagem de servidor cheio.

---

## 🎨 Modelos 3D do Blender

![Modelos feitos no Blender](docs/modelos_blender.jpg)

A pasta `blender/` tem:

- **`gerar_modelos.py`** — script do Blender que cria os 41 modelos low-poly (20 plantas, 13 frutos,
  4 sprinklers e 4 ovos), pinta tudo com uma textura de paleta e exporta em `.fbx`.
- **`modelos_exportados/fbx/`** — os 41 arquivos `.fbx` **já prontos** (com a textura embutida).
- **`modelos_exportados/CultiveUmJardim_Modelos.blend`** — o arquivo do Blender com tudo montado.

### Gerar de novo / editar no Blender (4.2 ou mais novo)

- No Blender: aba **Scripting › Open** → `gerar_modelos.py` → **Run Script**.
  (Ele cria uma cena nova e não apaga o que você tinha aberto.)
- Pelo terminal: `blender --background --python blender/gerar_modelos.py`

As cores, alturas e tamanhos vêm dos mesmos valores do `Config.luau`.

### Colocar os modelos no jogo

O jogo **funciona sem importar nada**: se um modelo não existir, ele monta a planta com Parts.
Para usar os modelos do Blender:

1. No Roblox Studio abra o **Importador 3D** (*File › Import 3D* ou *Home › Import 3D*).
2. Selecione os `.fbx` de `blender/modelos_exportados/fbx/` e importe.
3. Arraste os modelos importados para **ReplicatedStorage › Modelos**, **sem mudar os nomes**
   (ex.: `Planta_Carrot`, `Fruto_Apple`, `Sprinkler_BasicSprinkler`, `Ovo_CommonEgg`).
4. Dê Play. O jogo ajusta o tamanho dos modelos sozinho.

Regras de nome (se você fizer seus próprios modelos):

| Nome do modelo | Uso |
|---|---|
| `Planta_<IdDaSemente>` | corpo da planta (ex.: `Planta_Mango`) |
| `Fruto_<IdDaSemente>` | fruto das plantas de várias colheitas |
| `Sprinkler_<IdDoItem>` | sprinkler (a água sai da peça com "Cabeca" no nome) |
| `Ovo_<IdDoOvo>` | ovo chocando no jardim |

Peças com **"Produto"** no nome são as que mudam de cor com as mutações.
Os IDs estão no `Config.luau` (`id = "Carrot"`, `id = "Apple"`, ...).

---

## 🎮 Como jogar

1. Você começa com **¢20** e **1 semente de Cenoura**.
2. Equipe a semente (tecla **1** ou toque na barra) e **clique na terra marrom** do seu jardim.
3. Espere crescer e aperte **E** (ou toque no botão) para **Colher**.
4. Clique em **💰 Vender** no topo e depois em **Vender Tudo**.
5. Compre sementes melhores com o Sam (**🌱 Sementes**), equipamentos com a Eloise e ovos com o Ray.
6. Passe o mouse em cima das plantas para ver peso, mutações e quanto falta para crescer.

**Pá:** clique duas vezes na mesma planta para removê-la.
**Sprinkler / Ovo:** equipe e clique em qualquer lugar do seu jardim.

### Comandos de teste (só funcionam dentro do Roblox Studio)

| Comando no chat | O que faz |
|---|---|
| `/sheckles 100000` | ganha Sheckles |
| `/crescer` | todas as suas plantas e ovos ficam prontos |
| `/estoque` | enche o estoque das lojas |
| `/clima chuva` · `/clima geada` · `/clima tempestade` · `/clima parar` | controla o clima |

---

## 🛠️ Personalizar

Quase tudo fica em **`src/ReplicatedStorage/Shared/Config.luau`**:

- preços, tempo de crescimento, valor e peso de cada semente;
- chance de aparecer na loja e quantidade em estoque;
- equipamentos, ovos, pets e bônus;
- mutações e multiplicadores;
- duração e frequência dos climas;
- dinheiro inicial, limite de plantas, tempo de reabastecimento.

Para adicionar uma semente nova, copie um bloco da `SeedList`, mude o `id`/`name`/valores e escolha
um `plantType` (`root`, `bush`, `flower`, `tall`, `ground`, `tree`, `stalk`, `palm`, `cactus`,
`mushroom` ou `beanstalk`).

---

## ✅ Testes: como sei que não tem erros

Para testar sem abrir o Roblox Studio, o projeto tem um **simulador do Roblox**
(`ferramentas/teste/`) que roda os scripts no **Luau de verdade** e confere cada acesso usando a
**lista oficial de APIs do Roblox** (classes, propriedades, métodos, eventos e enums, além dos tipos
dos valores).

O cenário de teste joga o jogo inteiro: entra com vários jogadores, compra **todas** as sementes,
planta, colhe, vende, usa regador, pá e sprinklers, choca ovos, equipa pets, passa por todos os
climas, renasce, sai e volta (crescimento offline), simula falha do DataStore, enche o servidor e
usa modelos importados do Blender.

```
CHECAGENS: 112, falharam: 0, erros: 0
Metodos sem simulacao: (nenhum)
APIs obsoletas usadas: (nenhuma)
```

Para rodar de novo (precisa de Node.js 18+ e Python 3):

```bash
bash ferramentas/teste/testar.sh
```

> O simulador pega erros de nome de propriedade, enum, tipo de valor, chamada com `.` no lugar de `:`,
> espera infinita, dados que não podem ser salvos etc. Mesmo assim ele não é o Roblox de verdade:
> teste também no Studio antes de publicar.

---

## 📁 Estrutura

```
GrowAGarden-Roblox/
├── CultiveUmJardim.rbxlx        ← lugar pronto para abrir no Roblox Studio
├── default.project.json         ← projeto Rojo
├── src/                         ← todo o código Luau do jogo
├── blender/
│   ├── gerar_modelos.py         ← gera os modelos 3D no Blender
│   └── modelos_exportados/      ← .fbx prontos + .blend
├── ferramentas/
│   ├── gerar_rbxlx.py           ← recria o .rbxlx a partir de src/
│   └── teste/                   ← simulador do Roblox + cenário de teste
└── docs/                        ← imagens deste README
```

Se você mudar algo em `src/`, rode `python3 ferramentas/gerar_rbxlx.py` para atualizar o `.rbxlx`.
