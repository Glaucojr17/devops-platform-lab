# Laboratório de plataforma: Node.js, Kubernetes e Terraform

Este projeto pequeno mostra uma aplicação de ponta a ponta com os aspectos que costumo considerar em uma entrega de plataforma: uma API Node.js testada, imagem com usuário sem privilégios, probes de saúde, métricas, logs estruturados, dois modos de declaração do ambiente Kubernetes e validação em CI. É um **laboratório reproduzível**, não uma implantação de produção nem uma alegação de operação em EKS.

## O que há aqui

| Camada | Implementação | Como verificar |
| --- | --- | --- |
| Aplicação | API HTTP sem dependências externas; rotas `/`, `/health/live`, `/health/ready`, `/metrics` | `npm test` |
| Contêiner | Node Alpine, UID 10001, contexto de build enxuto | `docker build -t devops-platform-lab:local .` |
| Kubernetes | Dois pods, probes, limites de recursos, perfil seccomp e Service interno | `kubectl rollout status deployment/lab-api -n devops-lab` |
| IaC | Namespace, Deployment e Service no provider Kubernetes do Terraform | `terraform fmt -check`, `terraform validate`, `terraform plan` com cluster disponível |
| CI/CD | GitHub Actions valida aplicação, build e HCL; exemplo de build no Azure Pipelines | Inspecionar workflows e execução após publicar |

## Executar localmente

Requer Node.js 22+ para o desenvolvimento, Docker, kind, kubectl e Terraform 1.5+ para o fluxo completo. Com apenas Node.js, a aplicação e os testes funcionam:

```bash
npm test
npm start
# em outro terminal:
curl -fsS http://localhost:3000/health/ready
curl -fsS http://localhost:3000/metrics
```

Para testar no kind, execute da raiz do repositório:

```bash
kind create cluster --name devops-lab
docker build -t devops-platform-lab:local .
kind load docker-image devops-platform-lab:local --name devops-lab
kubectl config use-context kind-devops-lab
```

Escolha **uma** das duas formas abaixo para administrar os mesmos recursos. Não aplique os manifestos e o Terraform ao mesmo cluster ao mesmo tempo, pois seus estados de gerenciamento entrariam em conflito.

```bash
# Opção A: Kubernetes declarativo
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/application.yaml
```

```bash
# Opção B: Terraform
cd infra/terraform
terraform init
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
cd ../..
```

Depois, em qualquer opção:

```bash
kubectl rollout status deployment/lab-api -n devops-lab
kubectl port-forward -n devops-lab svc/lab-api 8080:80
# em outro terminal:
curl -fsS http://localhost:8080/health/ready
curl -fsS http://localhost:8080/metrics
```

Para remover os recursos, use `kubectl delete -f k8s/application.yaml -f k8s/namespace.yaml` na opção A ou `terraform destroy` dentro de `infra/terraform` na opção B; depois `kind delete cluster --name devops-lab`. Terraform grava estado local: evite colocá-lo no Git e trate-o como dado sensível.

## Decisões e limites

- A readiness sinaliza drenagem em `SIGTERM`; a liveness permanece ativa enquanto o processo responde. A aplicação encerra o servidor e dá até 10 segundos às conexões em andamento.
- `/metrics` expõe um contador Prometheus e logs JSON trazem `requestId`, status e duração. Não há backend de métricas, dashboards, SLO ou rastreamento distribuído neste laboratório. Em produção, isso exige instrumentação, retenção, cardinalidade controlada e alertas baseados em serviço.
- O cluster kind usa imagem carregada localmente. Para EKS/AKS/OKE seria necessário publicar a imagem em registry, autenticação, configuração de rede, política de identidade, gestão de segredos e estado Terraform remoto. Nada disso é pressuposto nos exemplos.
- O workflow de CI não recebe credenciais de cloud nem faz deploy. O arquivo Azure Pipelines é um exemplo de testes e build, sem configuração de projeto/registry e sem execução verificada aqui.
- O Dockerfile usa tag de imagem base e o CI usa versões de actions por simplicidade de laboratório. Para uma cadeia de suprimentos real, fixaria digests/SHAs, faria varredura de dependências e imagem, geração de SBOM e promoção por artefato imutável.

Veja [o roteiro de investigação](docs/OPERACAO.md) para falhas de rollout, probes e métricas.
