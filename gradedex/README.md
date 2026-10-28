# GradeDex

Marketplace de cartas Pokémon **graduadas** (PSA, BGS, CGC e TAG) com loja oficial que compra, consigna e revende slabs. Sem dependências e sem etapa de build.

> As lojas de demonstração (anúncios, preços, certificados, populações e vendas) são fictícias e geradas em `js/data.js`. Os anúncios com o selo **Loja oficial** são os que o dono cadastra no painel. O site não processa pagamentos: a compra dos slabs da loja é combinada pelo WhatsApp.

## Como rodar

Abra `index.html` direto no navegador, ou sirva a pasta:

```bash
cd gradedex
python3 -m http.server 8080   # ou: npx serve .
# http://localhost:8080
```

## Páginas

| Página | Rota | Destaques |
| --- | --- | --- |
| Início | `#/` | Slab em destaque, slabs da loja oficial, em alta (30 dias), abaixo da referência, faixa "venda seus slabs", guia das graduadoras, vintage, coleções |
| Busca | `#/busca` | Filtros facetados com contagem, ordenação, ver por carta ou por slab, busca por nº de certificado, autocomplete no cabeçalho |
| Carta | `#/carta/:id` | Slab com scan oficial e zoom, fotos reais (anúncios da loja), menor preço por nota, anúncios x referência, histórico de 52 semanas, pop report, alerta de preço, conferência de certificado, "venda para nós" |
| Loja | `#/loja/:id` | Reputação, vendas, prazo de postagem; `#/loja/gradedex` é a loja oficial |
| Carrinho e checkout | `#/carrinho`, `#/checkout` | Agrupado por loja, SEDEX/PAC, seguro, PIX; slabs da loja oficial geram o pedido pronto para enviar pelo WhatsApp |
| Vender | `#/vender` | Venda instantânea e consignação, com taxas e exemplo |
| Venda instantânea | `#/vender/oferta` | Carta, graduadora, nota, subnotas, idioma e certificado → oferta na hora (% da referência) e proposta pelo WhatsApp |
| Consignação | `#/vender/consignacao` | Mesmo formulário → preço sugerido, comissão e quanto a pessoa recebe |
| Painel da loja | `#/painel` | Só para o dono: anúncios (preço, pausar, vendido, editar, excluir), novo anúncio com até 4 fotos, configurações |
| Favoritos e comparar | `#/favoritos`, `#/comparar` | Favoritas, alertas e até 3 slabs lado a lado |

## Revenda: como a loja funciona

- **Anunciar slabs da loja** (`#/painel/novo`): escolha a carta, a nota e o certificado (o formato é validado por graduadora e não aceita certificado repetido), defina o preço a partir da referência e envie fotos. O anúncio aparece na home, na busca e na página da carta com o selo Loja oficial. Slabs consignados guardam o nome do consignante e mostram quanto ele recebe.
- **Venda instantânea**: o visitante recebe uma oferta de `instantRate` × referência da nota (70% por padrão) e envia a proposta pelo WhatsApp da loja.
- **Consignação**: preço sugerido = referência; a loja fica com `consignFee` (12% por padrão).
- **Configurações** (`#/painel/config`): nome, cidade, WhatsApp (com 55 e DDD), percentuais, prazo de postagem, frete base e se as lojas de demonstração continuam aparecendo.

Onde os anúncios ficam salvos:

- **No link publicado no claude.ai:** no banco compartilhado do próprio link. Todo mundo que abre a loja (logado no claude.ai) vê os anúncios; só o dono do link e editores que ele convidar alteram. Fotos ficam no armazenamento do link.
- **Abrindo o `index.html` ou em outro servidor:** no `localStorage` do navegador ("modo local"). Serve para testar; para uma loja pública fora do Claude, é preciso um backend (veja abaixo).

## Scans oficiais das cartas

`tools/baixar_scans.py` baixa os scans do [pokemontcg.io](https://pokemontcg.io), confere nome e número de cada carta e gera `img/cards/<id>.webp` (600 px) e `<id>-sm.webp` (260 px), além de `js/scans.js`, que diz ao site quais cartas têm scan. Cartas sem scan continuam com a arte gerada.

```bash
cd gradedex
python3 tools/baixar_scans.py            # baixa só o que falta
python3 tools/baixar_scans.py --refazer  # baixa tudo de novo
```

Precisa de acesso a `api.pokemontcg.io` e `images.pokemontcg.io`. O id de cada carta no pokemontcg.io fica no mapa `PTCG` em `js/data.js`. As imagens das cartas pertencem à The Pokémon Company; marketplaces costumam exibi-las para identificar o produto à venda.

## Estrutura

```
gradedex/
├── index.html          # casca da página (cabeçalho, rodapé, scripts)
├── css/
│   ├── base.css        # tokens de cor/tipografia, cabeçalho, botões, formulários
│   ├── slab.css        # slab, etiquetas PSA/BGS/CGC/TAG, scan e arte gerada da carta
│   └── pages.css       # layout de cada página
├── img/cards/          # scans gerados por tools/baixar_scans.py
├── tools/
│   └── baixar_scans.py
└── js/
    ├── scans.js        # gerado: cartas com scan
    ├── data.js         # catálogo, lojas de demonstração, histórico, pop report, índices de anúncios
    ├── store.js        # estado do visitante (carrinho, favoritos, alertas)
    ├── ui.js           # formatação, ícones, componentes, gráficos e zoom
    ├── market.js       # anúncios e configurações da loja oficial (banco do link ou localStorage)
    ├── forms.js        # seletor de carta e campos do slab usados nos formulários de venda
    ├── page-*.js       # uma página por arquivo
    └── app.js          # roteador por hash, busca do cabeçalho e ações globais
```

## Próximos passos para uma loja pública fora do Claude

- Backend próprio (por exemplo Supabase ou Firebase) no lugar do `market.js` em modo local, com login do dono.
- Catálogo completo pela API do pokemontcg.io, em vez das 33 cartas de `js/data.js`.
- Pagamento com retenção via intermediador (por exemplo Mercado Pago) e frete real pelo CEP.
- Conferência automática do certificado na base de cada graduadora.
