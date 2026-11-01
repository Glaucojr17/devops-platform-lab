# Plataforma DevOps no Hyper-V: cenário de SaaS de estoque

## Contexto

Este é um cenário fictício de cliente: uma equipe desenvolve um SaaS de controle de estoque e precisa publicar mudanças com teste, aprovação, observabilidade e possibilidade de reversão. A infraestrutura é um **homelab próprio**, com ambientes de desenvolvimento, homologação e produção *simulada*. Esses nomes representam fluxos de entrega separados, não uma produção comercial nem alta disponibilidade. O objetivo é executar, medir e documentar cada parte antes de apresentá-la como concluída.

O laboratório parte de um host Windows 11 Pro/Hyper-V com cerca de 32 GiB de RAM. Já existem `lab-ops` (Debian, 5 GiB) e `lab-storage` (Debian, 3 GiB), além dos switches `Default Switch` e `LAB-MGMT`. O inventário atual do host deve ser confirmado antes de criar novas VMs. O trabalho de backup/storage existente permanece isolado.

## Arquitetura proposta

```mermaid
flowchart TD
    A["GitHub: código e revisão"] --> B["Azure DevOps Services: YAML"]
    B --> C["devops-ci: agente próprio e registry"]
    C --> D["K3s no Hyper-V: controle e worker"]
    D --> E["Estoque API: dev, hom e prod simulada"]
    D --> F["Zabbix + PostgreSQL + Grafana"]
```

O Azure DevOps Services é um serviço externo, mesmo sem assinatura Azure para AKS/ACR. O agente local faz o build e alcança o cluster por `LAB-MGMT`; usa Internet apenas para conectar-se ao Azure DevOps e obter dependências. No Hyper-V, K3s e um registry OCI privado reproduzem **o fluxo de entrega** de Kubernetes e registro de imagens. Não são AKS nem ACR; nenhum resultado será descrito como execução nesses serviços.

### Capacidade inicial, sujeita ao preflight

| VM | CPU | RAM fixa | VHDX dinâmico | Rede |
| --- | ---: | ---: | ---: | --- |
| `devops-ci` | 2 | 4 GiB | 50 GiB | Default Switch e LAB-MGMT |
| `devops-k3s-cp` | 2 | 4 GiB | 40 GiB | Default Switch e LAB-MGMT |
| `devops-k3s-worker` | 2 | 7 GiB | 70 GiB | Default Switch e LAB-MGMT |

As novas VMs somam 15 GiB. Com as VMs de backup ligadas, o total configurado dos dois projetos pode chegar a 23 GiB, antes do Windows e de serviços do host. Não há pressuposto de que tudo rodará simultaneamente; a capacidade será ajustada com base em RAM livre, consumo real, CPU e I/O antes do provisionamento. Um controle e um worker no mesmo host físico não oferecem HA real.

| Volume | Uso previsto |
| --- | --- |
| `L:` (`LAB_VMS`) | Configuração das VMs em `L:\HyperV\VMs`, discos de sistema em `L:\HyperV\VHDX` |
| `M:` (`LAB_LUN`) | Reservado ao laboratório de storage existente; sem novos discos do SaaS |
| `N:` (`LAB_BKP`) | Exportações e cópias de dados do novo projeto em pasta própria, após definir retenção |
| `C:` e `E:` | Fora do provisionamento de VMs deste cenário |

## Entregas e critérios de aceite

1. **Inventário:** executar `infra/hyperv/Get-StockSaasPreflight.ps1`; conferir rótulos, caminhos, switches, VMs e margem de RAM. Não criar VMs se faltar margem ou houver nomes em uso.
2. **Infraestrutura reproduzível:** provisionamento por PowerShell idempotente, sem limpeza de disco; Linux por Ansible e acesso por SSH. Validar cada etapa antes de prosseguir.
3. **Aplicação:** API Node.js/TypeScript de estoque, com um cliente fictício e dados de demonstração; testes unitários, integração e rota de saúde. A aplicação terá armazenamento persistente e migrações versionadas.
4. **CI/CD:** pipeline YAML em Azure DevOps com agente auto-hospedado, revisão por PR, build, testes, imagem tagueada pelo SHA do commit, scanner, publicação em registry local e deploy por Helm. PRs não recebem segredos de deploy.
5. **Ambientes:** namespaces `estoque-dev`, `estoque-hom` e `estoque-prod-simulada`; aprovação humana antes da última promoção, smoke test e rollback exercitado. Dados de teste e credenciais separados por namespace.
6. **Monitoramento:** Zabbix Server, interface web e PostgreSQL **no cluster**, com volumes persistentes e limites de recursos; agentes/proxy do chart oficial para o cluster, conforme necessidade. Grafana **no cluster** com plugin de fonte de dados Zabbix. Monitorar saúde da API, disponibilidade, pods/nós e capacidade; provocar alerta e verificar recuperação. A instalação do chart oficial de integração não será confundida com a instalação do servidor Zabbix.
7. **Recuperação:** testar backup e restore do banco do SaaS e da configuração declarativa, em destino segregado em `N:`; documentar perda aceitável, duração medida e limites do teste. Snapshot de VM não substitui backup consistente do banco.
8. **Documentação:** arquitetura, ADRs, runbooks, resultados observados, capturas sem segredos, caminho de reprodução e roteiro de demonstração. Marcar como pendente tudo que não tiver comando, saída e data de validação.

## Primeira execução: somente leitura

No PowerShell do **host Windows**:

```powershell
$script = '.\infra\hyperv\Get-StockSaasPreflight.ps1'
& $script | Format-List
```

Para compartilhar uma saída estruturada com o projeto, grave-a apenas em diretório local de trabalho e revise-a antes de publicar:

```powershell
& $script | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$env:USERPROFILE\Documents\stock-saas-preflight.json" -Encoding UTF8
```

O script não cria VMs, não modifica discos e interrompe a leitura com erro se um comando essencial falhar. A verificação de RAM usa 15 GiB para as novas VMs e sugere preservar mais 6 GiB para o host; é um **critério inicial**, não uma garantia de capacidade. O relatório contém nomes, caminhos e informações do host: revise-o antes de anexá-lo a um repositório público.

## Estado registrado

**Planejamento e preflight preparados.** Até o momento, nenhuma VM nova, instalação K3s, pipeline Azure DevOps ou implantação Zabbix/Grafana deste cenário foi validada no host. O próximo marco depende da saída do preflight no Windows.
