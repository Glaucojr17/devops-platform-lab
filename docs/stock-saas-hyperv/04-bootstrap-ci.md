# Etapa 4 — SSH por chave e bootstrap da devops-ci

## Estado confirmado

Debian 13 em `devops-ci`: `eth1` ativa com `10.77.10.21/24`; a rota para `10.77.10.1` usa `eth1` e a rota padrão/Internet usa `eth0`. No Windows, `Test-NetConnection 10.77.10.21 -Port 22` retornou `TcpTestSucceeded: True` pela `LAB-MGMT`. O acesso por chave e as atualizações ainda não foram executados.

## Enviar chave pública e script pelo Windows

O comando reutiliza a identidade `id_ed25519_lab_ops` já criada para o homelab. Nenhuma chave privada é enviada à VM. Execute no PowerShell como seu usuário normal:

```powershell
$key = Join-Path $env:USERPROFILE '.ssh\id_ed25519_lab_ops'
if (-not (Test-Path -LiteralPath $key)) { throw 'Chave privada não encontrada.' }
if (-not (Test-Path -LiteralPath "$key.pub")) { throw 'Chave pública não encontrada.' }

$url = 'https://raw.githubusercontent.com/Glaucojr17/devops-platform-lab/main/infra/linux/bootstrap-devops-ci.sh'
$script = Join-Path $env:TEMP 'bootstrap-devops-ci.sh'
Invoke-WebRequest -Uri $url -OutFile $script -UseBasicParsing -ErrorAction Stop

scp -i $key "$key.pub" 'glaucojunior@10.77.10.21:/home/glaucojunior/devops-ci-admin.pub'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao enviar a chave pública.' }
scp -i $key $script 'glaucojunior@10.77.10.21:/home/glaucojunior/bootstrap-devops-ci.sh'
if ($LASTEXITCODE -ne 0) { throw 'Falha ao enviar o script.' }
```

Confirme a identidade da VM ao receber a pergunta sobre a chave do host SSH. O `scp` ainda pode pedir a **senha do usuário Debian**, pois a chave pública só será cadastrada na próxima etapa. Não publique sua chave privada, senha ou configuração pessoal do SSH.

## Executar na VM

Entre pelo console Hyper-V ou por SSH com senha e execute:

```bash
sudo bash /home/glaucojunior/bootstrap-devops-ci.sh
```

O script verifica hostname, endereço da MGMT e rota padrão antes de alterar algo. Depois valida a chave pública, cadastra-a uma única vez em `authorized_keys`, executa `apt-get update`, `upgrade` e instala `ca-certificates`, `curl`, `git`, `python3` e `ansible-core`. Interrompe ao primeiro erro e pode ser reexecutado após a correção. Não modifica a política de autenticação do SSH. Uma atualização de kernel poderá exigir reinicialização posterior, a ser feita após testar o login por chave e verificar as atualizações instaladas.

## Teste do host Windows

Abra **outra** janela do PowerShell, mantendo o console da VM disponível:

```powershell
$key = Join-Path $env:USERPROFILE '.ssh\id_ed25519_lab_ops'
ssh -i $key -o IdentitiesOnly=yes -o PreferredAuthentications=publickey -o PasswordAuthentication=no `
    glaucojunior@10.77.10.21 'id -un; hostname; ip -br -4 address; git --version; ansible --version | head -1'
if ($LASTEXITCODE -ne 0) { throw 'Login por chave falhou.' }
```

A senha da **chave privada** pode ser solicitada e é normal. A senha do usuário Debian não deve ser solicitada nesse teste. A saída esperada inclui `glaucojunior`, `devops-ci`, `10.77.10.21/24` e as versões instaladas. Na VM, rode `sudo dpkg --audit` e `df -h /`; o primeiro não deve listar pacotes pendentes.

## Próximo passo

Instalar Debian na `devops-k3s`, validar os adaptadores por MAC, configurar a interface de gestão como `10.77.10.22/24` sem gateway e testar SSH antes de instalar o cluster. A instalação do `ansible-core` nesta etapa prepara o nó de controle; ainda não é evidência de playbook executado.
