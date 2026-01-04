# Script para restaurar os arquivos originais dos stubs

Write-Host "=========================================="
Write-Host "RESTORING STONE PAYMENTS FILES"
Write-Host "=========================================="

$filesToRestore = @(
    @{
        Original = "lib/data/adapters/payment/providers/stone_pos_adapter.dart"
        Backup = "lib/data/adapters/payment/providers/stone_pos_adapter.dart.bak"
    }
)

foreach ($file in $filesToRestore) {
    $originalPath = $file.Original
    $backupPath = $file.Backup
    
    if (Test-Path $backupPath) {
        Write-Host "   Restaurando: $originalPath"
        Copy-Item $backupPath $originalPath -Force
        Remove-Item $backupPath
        Write-Host "     ✅ Arquivo restaurado"
    } else {
        Write-Host "   ⚠️ Backup não encontrado: $backupPath"
    }
}

Write-Host "✅ Arquivos restaurados com sucesso"

