#Requires -Version 5.1
<#
.SYNOPSIS
Inventario somente leitura para o laboratorio Stock SaaS no Hyper-V.
.DESCRIPTION
Nao cria VMs, nao altera switches, nao toca em particoes e nao grava arquivos.
Execute no Windows 11 Pro em PowerShell com o modulo Hyper-V disponivel.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    Import-Module Hyper-V -ErrorAction Stop

    $computador = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $sistema = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $hostVm = Get-VMHost -ErrorAction Stop

    $volumesEsperados = [ordered]@{
        L = 'LAB_VMS'
        M = 'LAB_LUN'
        N = 'LAB_BKP'
    }

    $volumes = foreach ($letra in $volumesEsperados.Keys) {
        $volume = Get-Volume -DriveLetter $letra -ErrorAction Stop
        [pscustomobject]@{
            Letra = $letra
            Rotulo = $volume.FileSystemLabel
            Formato = $volume.FileSystem
            TotalGiB = [math]::Round($volume.Size / 1GB, 1)
            LivreGiB = [math]::Round($volume.SizeRemaining / 1GB, 1)
            Conforme = ($volume.FileSystemLabel -eq $volumesEsperados[$letra] -and $volume.FileSystem -eq 'NTFS')
        }
    }

    $switches = @(Get-VMSwitch -ErrorAction Stop | Sort-Object Name | Select-Object Name, SwitchType)
    $vms = @(Get-VM -ErrorAction Stop | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            Nome = $_.Name
            Estado = [string]$_.State
            Cpu = $_.ProcessorCount
            RamConfiguradaGiB = [math]::Round($_.MemoryStartup / 1GB, 1)
            RamAtribuidaGiB = [math]::Round($_.MemoryAssigned / 1GB, 1)
            Caminho = $_.Path
        }
    })

    $nomesSwitch = @($switches | ForEach-Object { $_.Name })
    $faltamSwitches = @('Default Switch', 'LAB-MGMT') | Where-Object { $_ -notin $nomesSwitch }
    $ramLivreGiB = [math]::Round($sistema.FreePhysicalMemory / 1MB, 1)
    $ramPlanejadaGiB = 10
    $reservaHostGiB = 6

    $verificacoes = [pscustomobject]@{
        VolumesConformes = (@($volumes | Where-Object { -not $_.Conforme }).Count -eq 0)
        SwitchesBasePresentes = (@($faltamSwitches).Count -eq 0)
        CaminhosHostEmL = ($hostVm.VirtualMachinePath -like 'L:\*' -and $hostVm.VirtualHardDiskPath -like 'L:\*')
        RamLivreParaPlano = ($ramLivreGiB -ge ($ramPlanejadaGiB + $reservaHostGiB))
        ColisaoNomes = (@($vms | Where-Object { $_.Nome -in @('devops-ci', 'devops-k3s') }).Count -gt 0)
    }

    [pscustomobject]@{
        ColetadoEm = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
        Host = $env:COMPUTERNAME
        Sistema = $sistema.Caption
        RamTotalGiB = [math]::Round($computador.TotalPhysicalMemory / 1GB, 1)
        RamLivreGiB = $ramLivreGiB
        RamPlanejadaNovasVmsGiB = $ramPlanejadaGiB
        ReservaSugeridaHostGiB = $reservaHostGiB
        RamLivreAposPlanoGiB = [math]::Round(($ramLivreGiB - $ramPlanejadaGiB), 1)
        CaminhosHyperV = [pscustomobject]@{
            Vms = $hostVm.VirtualMachinePath
            Vhdx = $hostVm.VirtualHardDiskPath
        }
        Volumes = @($volumes)
        Switches = $switches
        VmsExistentes = $vms
        Verificacoes = $verificacoes
    }
} catch {
    throw "Preflight interrompido: $($_.Exception.Message)"
}
