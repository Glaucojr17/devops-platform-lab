# Etapa 2 — instalar Debian na VM devops-ci

**Estado inicial observado:** `devops-ci` foi criada e está desligada; 2 vCPU, 4 GiB RAM, VHDX dinâmico de 50 GiB em `L:\HyperV\VHDX`. A ISO Debian 13.7 foi anexada e validada pelo script. `devops-k3s` também existe, mas deve permanecer desligada durante esta instalação. O laboratório de backup não foi alterado.

## 1. Abrir a VM no host Windows

No PowerShell como administrador:

```powershell
Start-VM -Name 'devops-ci'
vmconnect.exe $env:COMPUTERNAME 'devops-ci'
```

Se o console não abrir, use o Gerenciador do Hyper-V, clique com o botão direito em `devops-ci` e escolha **Conectar**. Não inicie `devops-k3s` ainda.

## 2. Instalar o sistema

1. Na tela do Debian, escolha **Graphical install** ou **Install**.
2. Idioma Português do Brasil, região Brasil e teclado adequado ao seu equipamento. O idioma não altera os comandos de administração.
3. Se houver seleção de interface de rede para o instalador, escolha a conectada ao `Default Switch` (DHCP). A interface `MGMT` não deve receber gateway.
4. Nome da máquina: `devops-ci`. Domínio pode ficar vazio.
5. Deixe **vazia** a senha de `root` se quiser que o instalador desative login direto de root e configure `sudo` para o usuário comum. Crie o usuário `glaucojunior` e guarde a senha localmente; nunca a publique no GitHub/Notion.
6. Particionamento: **Guiado — usar disco inteiro**, confirme que o único disco de destino é o VHDX virtual de **50 GiB**. Escolha **Todos os arquivos em uma partição**. Essa operação formata apenas o disco virtual da VM.
7. Selecione um mirror Debian padrão para baixar pacotes. Na seleção de software, desmarque ambiente gráfico e marque somente **SSH server** e **standard system utilities**.
8. Conclua a instalação do GRUB no disco virtual e reinicie.

Se após o reinício a VM voltar ao instalador, desligue **somente `devops-ci`** pelo Hyper-V e faça, no host:

```powershell
Set-VMDvdDrive -VMName 'devops-ci' -Path $null
$osDisk = Get-VMHardDiskDrive -VMName 'devops-ci' |
    Where-Object Path -eq 'L:\HyperV\VHDX\devops-ci-os.vhdx'
if ($null -eq $osDisk) { throw 'Disco de sistema não encontrado; não altere o boot.' }
Set-VMFirmware -VMName 'devops-ci' -FirstBootDevice $osDisk
Start-VM -Name 'devops-ci'
```

Não rode o bloco de correção durante o particionamento ou a instalação; ele só trata uma VM que **já concluiu** o instalador e tentou reiniciar.

## 3. Conferir a instalação dentro do Debian

Entre com `glaucojunior` no console e execute:

```bash
hostnamectl
ip -br -4 address
ip route
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
systemctl is-active ssh
free -h
cat /etc/network/interfaces
```

**Aceite:** hostname `devops-ci`, disco de sistema em torno de 50 GiB, SSH ativo, uma interface recebendo endereço DHCP e rota de saída. A segunda interface pode aparecer `DOWN`; configuraremos o endereço estático da rede `LAB-MGMT` após identificar com segurança seu nome e MAC. Não publique a senha ou dados sensíveis ao compartilhar a saída.

## Depois

Configurar `LAB-MGMT` sem gateway/DNS, validar SSH do Windows ao IP estático, habilitar chave pública, instalar Docker/Forgejo e runner. Instalar `devops-k3s` em etapa separada; somente então iniciar a implantação do cluster e monitoramento.
