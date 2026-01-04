# Script para preparar o build do Windows removendo stone_payments
# Este script remove o pacote stone_payments do pubspec.yaml e cria stubs dos arquivos

param(
    [string]$Action = "prepare"  # prepare ou restore
)

$pubspecFile = "pubspec.yaml"
$pubspecBackup = "pubspec.yaml.bak"

if ($Action -eq "prepare") {
    Write-Host "=========================================="
    Write-Host "PREPARING WINDOWS BUILD"
    Write-Host "REMOVING STONE_PAYMENTS PACKAGE"
    Write-Host "=========================================="
    
    if (-not (Test-Path $pubspecFile)) {
        Write-Host "❌ Arquivo pubspec.yaml não encontrado"
        exit 1
    }
    
    # Cria backup
    if (Test-Path $pubspecBackup) {
        Write-Host "⚠️ Backup já existe, restaurando primeiro..."
        Copy-Item $pubspecBackup $pubspecFile -Force
    }
    Copy-Item $pubspecFile $pubspecBackup
    Write-Host "   Backup criado: $pubspecBackup"
    
    # Lê o conteúdo
    $content = Get-Content $pubspecFile -Raw
    
    # Remove stone_payments e comentários relacionados
    $content = $content -replace '\s*stone_payments:\s*[^\r\n]+[\r\n]*', ''
    $content = $content -replace '# Payment SDKs \(condicionais por flavor\)[\r\n]*', ''
    $content = $content -replace '# stone_payments: necessário para compilar código Dart[\r\n]*', ''
    $content = $content -replace '# As dependências nativas serão excluídas no build\.gradle\.kts para o flavor mobile[\r\n]*', ''
    
    # Remove linhas vazias duplicadas
    $content = $content -replace "(\r?\n\s*){4,}", "`r`n`r`n`r`n"
    
    # Salva
    Set-Content -Path $pubspecFile -Value $content -NoNewline
    
    Write-Host "✅ stone_payments removido do pubspec.yaml"
    Write-Host "   O pacote não será incluído no build do Windows"
    
} elseif ($Action -eq "restore") {
    Write-Host "=========================================="
    Write-Host "RESTORING PUBSPEC.YAML"
    Write-Host "=========================================="
    
    if (Test-Path $pubspecBackup) {
        Copy-Item $pubspecBackup $pubspecFile -Force
        Remove-Item $pubspecBackup
        Write-Host "✅ pubspec.yaml restaurado"
    } else {
        Write-Host "⚠️ Backup não encontrado: $pubspecBackup"
    }
}

