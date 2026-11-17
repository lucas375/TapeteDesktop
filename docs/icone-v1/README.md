# Proposta de ícone — TapeteDesktop

## Conceito: dobra em destaque

Um tapete persa vinho com uma quina levantada comunica a interação principal do aplicativo: puxar e dobrar o tecido sobre a Mesa. O fundo marfim e os detalhes em azul e dourado mantêm a relação com o tapete atual. Um medalhão maior e uma silhueta limpa ajudam na leitura em tamanhos pequenos.

![Proposta do ícone](app-icon-master.png)

## Entregáveis

- `app-icon-master.png`: arte original em PNG, com transparência externa e proveniência de geração preservada.
- `TapeteDesktop-proposta-v1.icns`: pacote de ícones para experimentar no macOS.
- `TapeteDesktop-proposta-v1.iconset/`: os dez PNGs do conjunto de ícones, de 16 a 1024 pixels.
- `menu-bar-template.svg`: proposta monocromática de uma silhueta com quina dobrada, própria para adaptação a `NSImage.isTemplate`.
- `apresentacao.html`: apresentação local com fundos claro/escuro, tamanhos pequenos e símbolo de menu.
- `prompt.txt`: instruções da imagem, produzida com a ferramenta integrada de geração de imagens.

## Critérios de revisão

- [ ] O tapete e a quina dobrada são reconhecíveis em 32 e 64 pixels.
- [ ] O ícone tem boa leitura em superfícies claras e escuras.
- [ ] Não há letras, selos, ponteiros ou elementos de interface na arte.
- [ ] O contorno externo é transparente, sem fundo quadriculado incorporado.
- [ ] O conjunto `.icns` contém os tamanhos padrão de 16, 32, 128, 256 e 512 pontos, em 1× e 2×.
- [ ] O símbolo de barra de menus continua legível em 18–22 pontos.
- [ ] A proposta é revisada antes de substituir os ícones do aplicativo.

## Situação

Proposta visual para revisão. Os arquivos desta pasta não são consumidos pelo build atual do aplicativo. A aplicação ao bundle e ao símbolo da barra de menus fica para a etapa seguinte à escolha visual.

## Reproduzir o pacote

No macOS, a partir da raiz do repositório:

```sh
swift docs/icone-v1/export-icon.swift docs/icone-v1/app-icon-master.png docs/icone-v1/TapeteDesktop-proposta-v1.iconset
iconutil -c icns docs/icone-v1/TapeteDesktop-proposta-v1.iconset -o docs/icone-v1/TapeteDesktop-proposta-v1.icns
open docs/icone-v1/apresentacao.html
```

O PNG original mantém a proveniência da imagem. Os PNGs redimensionados e o `.icns` são derivados técnicos para apresentação e uso no macOS.
