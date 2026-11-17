# TapeteDesktop

Um tapete persa interativo sobre a Mesa do Mac: cobre visualmente os ícones, dobra ao puxar e mantém os arquivos no lugar.

**[Baixar aplicativo v0.8.0 — ZIP para Apple Silicon](https://github.com/lucas375/TapeteDesktop/releases/download/v0.8.0/TapeteDesktop-v0.8.0-macOS-arm64.zip)** ·

## Requisitos e instalação

- macOS 13 ou posterior, com Metal.
- O aplicativo ZIP é compilado para **Apple Silicon (arm64)**.
- Extraia o ZIP e abra `TapeteDesktop.app`. O controle fica no ícone de tapete na barra de menus; não há ícone no Dock.

Esta é uma versão experimental, com assinatura **ad hoc**, sem notarização da Apple. O macOS pode bloquear sua abertura. O código e as instruções de compilação estão disponíveis abaixo; não é necessário fornecer credenciais ao aplicativo.

## Usar

| Ação | Como fazer |
| --- | --- |
| Dobrar e balançar o tecido no lugar | Arraste pelo interior sem usar o teclado; a puxada pode ultrapassar a área original. |
| Mover pela Mesa | Segure **Option (⌥)** e arraste. |
| Girar entre os quatro lados | Use as setas **↶ ↷** ou **↑ → ↓ ←**. |
| Redimensionar | Arraste as bordas/quinas ou use botão direito → **Tamanho do tapete**. |
| Alisar | Dois cliques no tecido ou **Alisar** nos controles. |
| Travar/destravar | Use a barra de menus. Travado, os cliques passam para o Finder. |
| Opacidade, paleta e flexibilidade | Ajuste pela barra de menus. |
| Centralizar, mostrar/ocultar e encerrar | Use os controles da barra de menus. |

O clique direito sobre o tapete destravado oferece tamanho, giro, alisamento e bloqueio. O clique direito no ícone da barra de menus também oferece ações rápidas. Os ajustes são salvos localmente e restaurados ao reabrir. Um tapete pode ser movido entre monitores.

## Privacidade e segurança

O app funciona offline: não contém telemetria, integração com serviços ou bibliotecas externas. Não lê, move nem apaga arquivos da Mesa. Os ajustes ficam no `UserDefaults` do Mac. Veja [PRIVACY.md](PRIVACY.md) e [SECURITY.md](SECURITY.md).

As publicações usam uma lista explícita de arquivos: código, recursos, documentação e scripts. Caches, preferências, arquivos de configuração locais e compilações de desenvolvimento ficam fora do repositório. A compilação de release remapeia caminhos de origem e remove símbolos de depuração. Os ZIPs não incluem atributos estendidos, ACLs nem identificadores de proprietário do Mac. Os hashes SHA-256 acompanham cada release.

## Compilar

Requer Xcode ou Command Line Tools com Swift 5.9 ou posterior. Não há dependências externas.

```sh
git clone https://github.com/lucas375/TapeteDesktop.git
cd TapeteDesktop
./Scripts/build-app.sh
open build/TapeteDesktop.app
```

Para trabalhar no Xcode, abra `Package.swift`. O script compila para a arquitetura do Mac atual, gera o ícone e aplica uma assinatura ad hoc. Ele não usa certificado de desenvolvedor nem chave de assinatura privada.

## Validar e preparar um release

Os testes unitários requerem Xcode completo, por usarem XCTest. Se necessário, selecione o Xcode apenas para o comando com `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

```sh
swift test
./build/TapeteDesktop.app/Contents/MacOS/TapeteDesktop --smoke-test
python3 Scripts/audit-release.py
python3 Scripts/package-release.py
```

São **28 testes unitários** de geometria, tecido, rotação e migração de preferências. A verificação nativa adicional testa a janela real, passagem de cliques, persistência, dobra sem teclado, movimento com Option e redimensionamento. A auditoria de publicação procura credenciais, caminhos privados e arquivos indevidos no código, no executável e nos ZIPs; ela complementa a revisão e não é uma garantia de ausência de vulnerabilidades.

## Funcionamento e limites

SwiftUI fornece os controles; AppKit gerencia a janela sem moldura; Metal desenha uma malha de 2.337 pontos. O tecido responde a uma simulação com gravidade, inércia e restrições de dobra. A área transparente de renderização cresce com a dobra, sem um recorte quadrado, e volta ao tamanho normal quando o tecido repousa. A posição e o tamanho salvos não mudam durante essa puxada. A renderização pausa ao repousar. A textura é original e gerada por IA, com proveniência preservada; o [prompt](Resources/texture-prompt.txt) acompanha o projeto.

O tapete fica acima dos ícones do Finder e abaixo das janelas comuns. Aparece nos Spaces; um aplicativo opaco em tela cheia o cobre. A visibilidade em Mission Control, Stage Manager e tela cheia depende do sistema. A malha não tem autocolisão completa.

Referência visual: [reel de bisciobaddo/blackpear.studio](https://www.instagram.com/reel/DfzQZE-Ky_2/). Documentação técnica: [níveis de janela](https://developer.apple.com/documentation/coregraphics/cgwindowlevelkey), [Spaces](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct) e [MetalKit](https://developer.apple.com/documentation/metalkit/mtkview).
