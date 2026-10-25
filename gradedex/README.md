# GradeDex

Marketplace de cartas Pokémon **graduadas** (PSA, BGS, CGC e TAG). Protótipo navegável, sem dependências e sem etapa de build.

> Loja demonstrativa: anúncios, preços, certificados, populações e lojas são fictícios e gerados de forma determinística em `js/data.js`. Nenhum pagamento é processado.

## Como rodar

Abra `index.html` direto no navegador, ou sirva a pasta:

```bash
cd gradedex
python3 -m http.server 8080   # ou: npx serve .
# http://localhost:8080
```

## O que tem

| Página | Rota | Destaques |
| --- | --- | --- |
| Início | `#/` | Slab em destaque com referência PSA 10 e sparkline, vendas recentes, em alta (30 dias), ofertas abaixo da referência, guia das graduadoras, vintage WotC, coleções |
| Busca | `#/busca` | Filtros facetados com contagem (graduadora, nota mínima, Black Label/Pristine, idioma, era, coleção, raridade, preço, loja verificada), ordenação, ver por carta ou por slab, busca por nº de certificado, autocomplete no cabeçalho |
| Carta | `#/carta/:id` | Slab com etiqueta da graduadora e subnotas BGS, menor preço por nota, tabela de anúncios com comparação contra a referência, histórico de 52 semanas por nota com tooltip, pop report com taxa de 10 e Black Label, alerta de preço, conferência de certificado |
| Loja | `#/loja/:id` | Reputação, vendas, prazo de postagem, selo de verificação |
| Carrinho | `#/carrinho` | Agrupado por loja, SEDEX/PAC por loja, frete grátis acima de R$ 5.000 por loja, seguro de envio, preço no PIX |
| Checkout | `#/checkout` | Endereço com validação de CEP/UF, PIX ou cartão em 10x (simulação), pedido com etapas de pagamento protegido |
| Favoritos | `#/favoritos` | Cartas favoritas e alertas de preço |
| Comparar | `#/comparar` | Até 3 slabs lado a lado: nota, subnotas, preço x referência, população na nota, loja |

Carrinho, favoritos, alertas e comparação ficam no `localStorage` do navegador. Há tema claro e escuro.

## Estrutura

```
gradedex/
├── index.html          # casca da página (cabeçalho, rodapé, scripts)
├── css/
│   ├── base.css        # tokens de cor/tipografia, cabeçalho, botões, formulários
│   ├── slab.css        # slab, etiquetas PSA/BGS/CGC/TAG e a arte gerada da carta
│   └── pages.css       # layout de cada página
└── js/
    ├── data.js         # catálogo: coleções, cartas, lojas, anúncios, histórico, pop report
    ├── store.js        # estado do visitante (localStorage)
    ├── ui.js           # formatação, ícones, componentes e gráficos em SVG
    ├── page-*.js       # uma página por arquivo
    └── app.js          # roteador por hash, busca do cabeçalho e ações globais
```

## Próximos passos para virar loja de verdade

- Trocar `js/data.js` por uma API (cartas, anúncios, lojas) e um banco como Postgres.
- Fotos reais dos slabs enviadas pelo vendedor no lugar da arte gerada.
- Conferência automática do certificado na base de cada graduadora.
- Pagamento com retenção (escrow) via intermediador, com liberação na confirmação de recebimento.
- Cálculo de frete real pelo CEP de origem e destino.
