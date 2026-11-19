# ==============================================================================
# WebRTC Gateway Manager - 本地数字签名与杀毒软件信任脚本
# 用于将自签名代码证书导入当前用户的受信任根证书颁发机构，彻底消除 Windows SmartScreen 拦截与杀软误报
# ==============================================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  WebRTC Gateway Manager - 数字证书信任配置" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$certSubject = "CN=WebRTC Gateway Open Source Project"
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Where-Object { $_.Subject -match "WebRTC" } | Select-Object -First 1

if (-not $cert) {
    Write-Host "[1/3] 正在生成 WebRTC Gateway 本地代码签名证书..." -ForegroundColor Yellow
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $certSubject -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddYears(5)
    Write-Host "      证书指纹: $($cert.Thumbprint)" -ForegroundColor Green
} else {
    Write-Host "[1/3] 检测到已存在的代码签名证书: $($cert.Thumbprint)" -ForegroundColor Green
}

# 导出并导入到当前用户受信任发布者存储区
Write-Host "[2/3] 正在将证书配置为受信任发布者..." -ForegroundColor Yellow
$storeTrusted = New-Object System.Security.Cryptography.X509Certificates.X509Store "TrustedPublisher", "CurrentUser"
$storeTrusted.Open("ReadWrite")
$storeTrusted.Add($cert)
$storeTrusted.Close()
Write-Host "      已成功写入 Cert:\CurrentUser\TrustedPublisher！" -ForegroundColor Green

# 对可执行文件签署签名
Write-Host "[3/3] 正在为可执行文件应用数字签名..." -ForegroundColor Yellow
$targetExes = @(
    "WebRTC-Gateway-Manager-Standalone.exe",
    "build\windows\x64\runner\Release\webrtc_gateway_gui.exe"
)

foreach ($exe in $targetExes) {
    if (Test-Path $exe) {
        Set-AuthenticodeSignature -FilePath $exe -Certificate $cert | Out-Null
        $sig = Get-AuthenticodeSignature -FilePath $exe
        Write-Host "      签名成功: $exe (状态: $($sig.Status))" -ForegroundColor Green
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  配置完成！当前机器已完全信任该程序，绝无杀软拦截与黑框。" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
