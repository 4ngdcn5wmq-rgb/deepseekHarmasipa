# DeepSeek Harness 手机客户端 - 电脑端桥接启动器
# 双击运行,或在 PowerShell 中执行: .\start-bridge.ps1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$nodeExe = $null
$cmd = Get-Command node -ErrorAction SilentlyContinue
if ($cmd) { $nodeExe = $cmd.Source }

if (-not $nodeExe) {
    $bundled = "C:\Users\Lenovo\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\node\bin\node.exe"
    if (Test-Path $bundled) { $nodeExe = $bundled }
}

if (-not $nodeExe) {
    Write-Host "未找到 Node.js。请安装 Node.js 18 或更高版本后重试。" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}

Write-Host "使用 Node: $nodeExe"
& $nodeExe (Join-Path $here 'pc-bridge.mjs')
Read-Host "桥接已停止,按回车退出"
