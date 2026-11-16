# Segurança

## Reportar um problema

Abra uma issue apenas se o relato não contiver credenciais, arquivos pessoais, caminhos privados ou detalhes que facilitem exploração. Não publique segredos em comentários, screenshots ou logs. Para informação sensível, use um canal privado acordado com o mantenedor.

## Publicações

- O repositório contém apenas os arquivos explicitamente selecionados pelo empacotador.
- `.build`, `build`, `dist`, preferências, arquivos de ambiente e material de assinatura ficam fora do código publicado.
- O script de release remapeia caminhos locais e remove símbolos de depuração antes da assinatura.
- Os ZIPs preservam permissões necessárias à execução, sem atributos estendidos, ACLs ou IDs locais de proprietário.
- `Scripts/audit-release.py` revisa código, recursos, executável e ZIPs antes da publicação; os resultados e hashes acompanham o release.
- O recurso de imagem mantém a proveniência de geração por IA; ele não contém dados pessoais usados pelo aplicativo.

A compilação atual usa assinatura ad hoc, não notarizada pela Apple. A verificação automática de conteúdo e os testes não equivalem a uma auditoria independente de segurança nem garantem ausência de vulnerabilidades.
