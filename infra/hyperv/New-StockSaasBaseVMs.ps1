#Requires -Version 5.1
<#
.SYNOPSIS
Prepara duas VMs desligadas para o laboratorio local de SaaS de estoque.
.DESCRIPTION
Sem -Apply faz apenas validacoes. Com -Apply cria devops-ci e devops-k3s,
mas nao liga VMs, nao altera discos fisicos e nao modifica VMs existentes.
Em falha parcial, interrompe sem apagar objetos criados: revise antes de repetir.
#>
[CmdletBinding()]
param([switch]$Apply)

$ErrorActionPreference = 'Stop'

try {
    Import-Module Hyper-V -ErrorAction Stop

    $vmRoot = 'L:\HyperV\VMs'
    $vhdRoot = 'L:\HyperV\VHDX'
    $iso = 'L:\HyperV\ISO\debian-13.7.0-amd64-netinst.iso'
    $isoSha256 = 'A7EF94AC2FB9A7FEC454552ABD629B7CC9D5155C886165A45649F5CE6167E355'
    $plano = @(
        [pscustomobject]@{ Name = 'devops-ci'; Cpu = 2; RamGiB = 4; DiskGiB = 50 }
        [pscustomobject]@{ Name = 'devops-k3s'; Cpu = 4; RamGiB = 6; DiskGiB = 100 }
    )

    if ($Apply) {
        $admin = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        if (-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Abra o PowerShell como Administrador para criar as VMs.'
        }
    }

    $esperado = [ordered]@{ L = 'LAB_VMS'; M = 'LAB_LUN'; N = 'LAB_BKP' }
    foreach ($letra in $esperado.Keys) {
        $v = Get-Volume -DriveLetter $letra -ErrorAction Stop
        if ($v.FileSystemLabel -ne $esperado[$letra] -or $v.FileSystem -ne 'NTFS') {
            throw "Volume $($letra): nao confere com o inventario."
        }
    }

    $hostConfig = Get-VMHost -ErrorAction Stop
    if ($hostConfig.VirtualMachinePath -ne $vmRoot -or
        $hostConfig.VirtualHardDiskPath -ne $vhdRoot) {
        throw 'Caminhos padrao do Hyper-V mudaram. Operacao interrompida.'
    }

    foreach ($switchName in @('Default Switch', 'LAB-MGMT')) {
        $sw = Get-VMSwitch -Name $switchName -ErrorAction Stop
        if ([string]$sw.SwitchType -ne 'Internal') {
            throw "Switch $switchName com tipo inesperado."
        }
    }

    if (-not (Test-Path -LiteralPath $iso -PathType Leaf)) {
        throw "ISO Debian nao encontrada: $iso"
    }
    if (-not (Test-Path -LiteralPath $vmRoot -PathType Container) -or
        -not (Test-Path -LiteralPath $vhdRoot -PathType Container)) {
        throw 'Diretorios de VM/VHDX ausentes em L:.'
    }

    $ramLivre = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
    $ramNovas = 10
    $reservaHost = 6
    if ($ramLivre -lt ($ramNovas + $reservaHost)) {
        throw "RAM livre $ramLivre GiB insuficiente para 10 GiB de VMs e 6 GiB de reserva. Feche aplicativos e execute novamente."
    }

    foreach ($config in $plano) {
        if (Get-VM -Name $config.Name -ErrorAction SilentlyContinue) {
            throw "VM $($config.Name) ja existe. Nenhuma VM nova sera criada."
        }
        $vhd = Join-Path $vhdRoot "$($config.Name)-os.vhdx"
        $caminhoVm = Join-Path $vmRoot $config.Name
        if ((Test-Path -LiteralPath $vhd) -or (Test-Path -LiteralPath $caminhoVm)) {
            throw "Destino ja ocupado para $($config.Name). Nenhuma VM nova sera criada."
        }
    }

    $resumo = $plano | Select-Object Name, Cpu, RamGiB, DiskGiB
    $resumo | Format-Table -AutoSize
    Write-Host "Preflight OK. RAM livre: $ramLivre GiB; prevista apos boot das novas VMs: $([math]::Round($ramLivre - $ramNovas, 1)) GiB."

    if (-not $Apply) {
        Write-Host 'Somente validacao. Para criar as duas VMs desligadas, execute com -Apply.'
        return
    }

    $atual = (Get-FileHash -LiteralPath $iso -Algorithm SHA256 -ErrorAction Stop).Hash
    if ($atual -ne $isoSha256) {
        throw 'ISO com SHA256 diferente do validado anteriormente. Nenhuma VM criada.'
    }

    foreach ($config in $plano) {
        try {
            $vhd = Join-Path $vhdRoot "$($config.Name)-os.vhdx"
            New-VM -Name $config.Name -Generation 2 `
                -MemoryStartupBytes ([int64]$config.RamGiB * 1GB) `
                -Path $vmRoot -NewVHDPath $vhd `
                -NewVHDSizeBytes ([int64]$config.DiskGiB * 1GB) `
                -SwitchName 'Default Switch' -ErrorAction Stop | Out-Null

            Set-VMProcessor -VMName $config.Name -Count $config.Cpu -ErrorAction Stop
            Set-VMMemory -VMName $config.Name -DynamicMemoryEnabled $false -ErrorAction Stop
            Set-VM -VMName $config.Name -AutomaticCheckpointsEnabled $false -ErrorAction Stop

            $nic = @(Get-VMNetworkAdapter -VMName $config.Name -ErrorAction Stop)
            if ($nic.Count -ne 1) { throw 'Numero inesperado de adaptadores.' }
            Rename-VMNetworkAdapter -VMName $config.Name -Name $nic[0].Name -NewName 'INSTALL' -ErrorAction Stop
            Add-VMNetworkAdapter -VMName $config.Name -Name 'MGMT' -SwitchName 'LAB-MGMT' -ErrorAction Stop

            Add-VMDvdDrive -VMName $config.Name -Path $iso -ErrorAction Stop
            $dvd = Get-VMDvdDrive -VMName $config.Name -ErrorAction Stop |
                Where-Object { $_.Path -eq $iso } | Select-Object -First 1
            if ($null -eq $dvd) { throw 'Unidade de DVD nao encontrada apos a criacao.' }
            Set-VMFirmware -VMName $config.Name -EnableSecureBoot On `
                -SecureBootTemplate 'MicrosoftUEFICertificateAuthority' `
                -FirstBootDevice $dvd -ErrorAction Stop

            Write-Host "Criada e DESLIGADA: $($config.Name) ($($config.RamGiB) GiB RAM, $($config.DiskGiB) GiB VHDX)."
        } catch {
            throw "Falha na VM $($config.Name). Pode ter havido criacao parcial; nao execute novamente antes de inspecionar Get-VM, VHDX e adaptadores. Erro: $($_.Exception.Message)"
        }
    }

    Get-VM -Name @($plano | ForEach-Object { $_.Name }) |
        Select-Object Name, State, ProcessorCount, MemoryStartup, Path
} catch {
    throw "Laboratorio interrompido: $($_.Exception.Message)"
}
