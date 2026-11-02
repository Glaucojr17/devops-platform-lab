# Etapa 3 — rede de gestão da devops-ci

## Estado observado

Debian 13 iniciou como `devops-ci`. Disco virtual de 50 GiB: EFI, raiz ext4 e swap; SSH está ativo. A interface `eth0` recebeu IPv4 por DHCP do Default Switch e possui a rota padrão. A RAM total exibida é 3,8 GiB. A saída `ip -br -4 address` não exibiu a interface sem endereço IPv4; **ainda não há evidência do nome/MAC da interface MGMT**. `devops-k3s` continua desligada.

## Identificar o adaptador antes de alterar a rede

No host Windows:

```powershell
Get-VMNetworkAdapter -VMName 'devops-ci' |
    Select-Object Name,SwitchName,MacAddress,Status |
    Format-Table -AutoSize
```

No console do Debian:

```bash
ip -br link
for i in /sys/class/net/*; do printf '%s ' "${i##*/}"; cat "$i/address"; done
systemctl is-active networking
```

Compare o MAC da linha `MGMT` / `LAB-MGMT` do Hyper-V com o endereço da interface correspondente no Linux. **Só use os comandos abaixo se essa interface for `eth1`, `networking` estiver ativo e a rota padrão continuar na `eth0`.** Se for outro nome, ajuste a configuração ao nome real; se houver dúvida, pare e registre a saída.

## Configurar 10.77.10.21/24 sem gateway

No console do Debian como root:

```bash
if [ -d /sys/class/net/eth1 ] &&
   [ ! -e /etc/network/interfaces.d/10-lab-mgmt ] &&
   [ "$(ip -4 route show default | awk 'NR==1 { print $5 }')" = eth0 ]; then
    cat > /etc/network/interfaces.d/10-lab-mgmt <<'EOF'
# Gestao do laboratorio; sem gateway e sem DNS.
auto eth1
iface eth1 inet static
    address 10.77.10.21/24
EOF
    chmod 0644 /etc/network/interfaces.d/10-lab-mgmt
    ifquery eth1
    ifup eth1
else
    printf '%s\n' 'Precondicao falhou: confira interface, rota e arquivo existente.' >&2
fi
```

Não altere `/etc/network/interfaces` nem reinicie o serviço de rede inteiro. O arquivo novo só configura a interface de gestão. Depois confira:

```bash
ip -br -4 address
ip route
ip route get 10.77.10.1
ip route get 1.1.1.1
systemctl is-active ssh
```

O acesso à rede `10.77.10.0/24` deve usar `eth1`; a saída externa deve continuar via `eth0` e seu gateway DHCP. No PowerShell Windows:

```powershell
Test-NetConnection -ComputerName 10.77.10.21 -Port 22
```

**Aceite:** `TcpTestSucceeded: True`, endereço de gestão persistente e rota padrão intacta. Antes de anexar evidências públicas, remova MAC, host físico e endereço DHCP transitório da captura.

## Próximo marco

Instalar a chave pública SSH, atualizar Debian e preparar automação. Depois repetir instalação e rede na `devops-k3s` com o endereço planejado `10.77.10.22/24`, validando o MAC dela antes.
