# Sub Dash

Jogo de submarino no fundo do mar, inspirado nos jogos de "dash" da Play Store, feito em HTML5 Canvas puro.
Não precisa instalar nada: é um único arquivo.

## Como jogar

- Abra `index.html` no navegador (celular ou PC), ou sirva a pasta: `npx serve block-dash`.
- Segure a tela, o botão do mouse ou `Espaço` / `↑` para **subir**. Solte para **descer**.
- `Esc` ou `P` pausa, `R` reinicia.

## Dificuldades

| Dificuldade | Vidas | Velocidade | Passagens |
|---|---|---|---|
| Fácil | 3 | devagar | bem largas |
| Normal | 2 | média | médias, com túneis |
| Difícil | 1 | rápida | estreitas, com tubarões |
| Insano | 1 | muito rápida | bem apertadas |

## Fases

1. **Recife de Coral**: corais, peixes-palhaço, águas-vivas, baiacus e minas com boia.
2. **Navio Naufragado**: destroços de madeira, âncoras penduradas, tubarões e um navio afundado ao fundo.
3. **Fossa Abissal**: escuridão total, só o farol do submarino ilumina; peixes-lanterna e estalactites com cristais.
4. **Mergulho Infinito**: passa pelos três ambientes sem parar e fica cada vez mais rápido.

## Itens e loja

- Pérolas: guardadas no aparelho, servem para comprar 8 submarinos diferentes na loja do menu.
- Bolha de escudo: aguenta uma batida.
- Coração: devolve uma vida (Fácil e Normal).
- Terminar uma fase dá bônus de pérolas, maior nas dificuldades mais altas.

Toda fase é gerada em volta de um caminho seguro, então sempre existe uma passagem possível.

`game.html` é a mesma página sem o cabeçalho HTML, usada para publicar como Artifact.
