#!/usr/bin/env bash
# Primeiro bootstrap da VM devops-ci. Reexecutável após uma falha parcial.
set -Eeuo pipefail
trap 'printf "FALHA na linha %s (exit %s). Corrija o erro e reexecute.\n" "$LINENO" "$?" >&2' ERR

if [[ ${EUID} -ne 0 ]]; then
    printf 'Execute como root.\n' >&2
    exit 1
fi
if [[ $(hostname -s) != devops-ci ]]; then
    printf 'Hostname inesperado; esperado: devops-ci.\n' >&2
    exit 1
fi
if ! ip -4 -o addr show dev eth1 | grep -q 'inet 10\.77\.10\.21/24 '; then
    printf 'A interface eth1 precisa ter 10.77.10.21/24.\n' >&2
    exit 1
fi
if [[ $(ip -4 route show default | awk 'NR==1 { print $5 }') != eth0 ]]; then
    printf 'Rota de saída inesperada; esperado: eth0.\n' >&2
    exit 1
fi

admin=glaucojunior
pubkey=${1:-/home/glaucojunior/devops-ci-admin.pub}
getent passwd "$admin" >/dev/null
[[ -s "$pubkey" ]] || { printf 'Chave pública ausente ou vazia: %s\n' "$pubkey" >&2; exit 1; }
[[ $(wc -l < "$pubkey") -eq 1 ]] || { printf 'Esperada exatamente uma chave pública.\n' >&2; exit 1; }
ssh-keygen -lf "$pubkey"

home=$(getent passwd "$admin" | cut -d: -f6)
install -d -m 700 -o "$admin" -g "$admin" "$home/.ssh"
auth="$home/.ssh/authorized_keys"
touch "$auth"
chmod 600 "$auth"
if ! grep -Fqx -- "$(cat "$pubkey")" "$auth"; then
    cat "$pubkey" >> "$auth"
fi
chown "$admin:$admin" "$auth"

printf 'Chave cadastrada; atualizando pacotes e ferramentas de automação.\n'
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl git python3 ansible-core

systemctl is-active --quiet ssh
dpkg --audit
printf '\nBootstrap concluído: %s; MGMT %s\n' "$(hostname -s)" "$(ip -4 -o addr show dev eth1 | awk '{ print $4 }')"
git --version
ansible --version | head -1
printf 'Teste o acesso por chave em outra janela antes de alterar a autenticação SSH.\n'
