# Privacidade

O TapeteDesktop desenha um tapete sobre a Mesa do macOS. A implementação atual:

- não enumera, lê, move, apaga ou envia arquivos da Mesa;
- não captura a tela, grava áudio ou acessa câmera/localização;
- não faz requisições de rede nem possui telemetria;
- não exige conta, chave de API ou permissão de Acessibilidade;
- usa somente frameworks do macOS e uma textura empacotada no aplicativo.

Posição, tamanho, paleta, opacidade, giro, visibilidade e bloqueio são preferências locais no domínio `com.tapetedesktop.app` do `UserDefaults`. As notificações entre instâncias e do sistema são locais. As dobras são temporárias e não são salvas.

Os modos de verificação acionados explicitamente por linha de comando criam preferências temporárias e, com `--previews`, imagens sintéticas no diretório indicado. Não são capturas da Mesa do usuário.

GitHub e outros sites ligados na documentação possuem políticas próprias. Os links não são acessados automaticamente pelo aplicativo.
