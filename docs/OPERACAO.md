# Investigação operacional

Se o rollout não completar, comece pelo estado observado, sem repetir o deploy às cegas:

```bash
kubectl rollout status deployment/lab-api -n devops-lab --timeout=60s
kubectl get pods -n devops-lab -o wide
kubectl describe deployment lab-api -n devops-lab
kubectl get events -n devops-lab --sort-by=.lastTimestamp
```

Um `ImagePullBackOff` no kind geralmente indica que a imagem não foi carregada no cluster ou que a tag difere entre build, Deployment e Terraform. Confira `kind load docker-image ...`, `imagePullPolicy` e o nome exato da imagem. Para falhas de readiness, use `kubectl logs -n devops-lab deployment/lab-api --tail=100`, `kubectl describe pod` e teste `/health/ready` via port-forward. Se a rota responde localmente mas o Service não, compare labels dos pods com o selector do Service e verifique endpoints com `kubectl get endpoints -n devops-lab lab-api`.

No incidente, registre horário, alteração recente, sintomas, impacto e ação adotada. Compare a resposta de `/health/live` (processo) e `/health/ready` (aceita tráfego); use `/metrics` e logs JSON para observar volume e status, sem confundir esse contador didático com uma solução completa de SRE. Depois da mitigação, documente causa, lacunas de detecção e ação preventiva verificável.
