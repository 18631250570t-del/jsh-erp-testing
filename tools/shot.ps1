# jshERP 测试截图工具 v3
# 用法（先 cd 到本目录：cd D:\jsh-erp-test\tools）：
#   .\shot.ps1 B-08                 截当前活动窗口
#   .\shot.ps1 B-08 单位留空          带验证点命名
#   .\shot.ps1 B-08 单位留空 -Zoom 2  先缩小 2 档再截（宽页面必备）
#   .\shot.ps1 B-08 全屏内容 -Mode Full
#
# -Zoom N : 截图前自动发送 N 次 Ctrl+减号（浏览器缩小），截完自动 Ctrl+0 还原

param(
    [Parameter(Mandatory = $true, Position = 0)][string]$CaseId,
    [Parameter(Position = 1)][string]$Point = "",
    [ValidateSet("Window", "Full")]
    [string]$Mode = "Window",
    [int]$Zoom = 0,
    [string]$OutDir = "D:\jsh-erp-test\screenshots",
    [int]$Delay = 3
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$sig = '[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }'

try {
    $Win32 = Add-Type -MemberDefinition $sig -Name Win32Cap3 -Namespace DshCapture3 -PassThru
    $Win32::SetProcessDPIAware() | Out-Null
} catch {
    $Win32 = $null
}

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}

if ($Delay -gt 0) {
    $tip = "[" + $Delay + " 秒后截图"
    if ($Zoom -gt 0) { $tip += "，将自动缩小 " + $Zoom + " 档" }
    Write-Host ($tip + "] 请立刻按 Alt+Tab 切到浏览器") -ForegroundColor Yellow
    Start-Sleep -Seconds $Delay
}

# 自动缩放
if ($Zoom -gt 0) {
    for ($i = 0; $i -lt $Zoom; $i++) {
        [System.Windows.Forms.SendKeys]::SendWait("^-")
        Start-Sleep -Milliseconds 400
    }
    Start-Sleep -Milliseconds 800
}

$rect = $null

if ($Mode -eq "Window" -and $Win32 -ne $null) {
    $h = $Win32::GetForegroundWindow()
    $r = New-Object DshCapture3.Win32Cap3+RECT
    if ($Win32::GetWindowRect($h, [ref]$r)) {
        $w = $r.Right - $r.Left
        $hgt = $r.Bottom - $r.Top
        if ($w -gt 100 -and $hgt -gt 100) {
            $rect = [System.Drawing.Rectangle]::new($r.Left, $r.Top, $w, $hgt)
        }
    }
}

if ($null -eq $rect) {
    $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $rect = [System.Drawing.Rectangle]::new($vs.X, $vs.Y, $vs.Width, $vs.Height)
}

$bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.X, $rect.Y, 0, 0, $bmp.Size)
$g.Dispose()

$safePoint = ($Point -replace '[\\/:*?"<>|]', '_').Trim()
if ($safePoint -ne "") {
    $baseName = $CaseId + "_" + $safePoint
} else {
    $baseName = $CaseId
}

$path = Join-Path $OutDir ($baseName + ".png")
$index = 2
while (Test-Path $path) {
    $path = Join-Path $OutDir ($baseName + "_" + $index + ".png")
    $index++
}

$bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

# 还原缩放
if ($Zoom -gt 0) {
    [System.Windows.Forms.SendKeys]::SendWait("^0")
    Start-Sleep -Milliseconds 300
}

Write-Host "已截图: $path" -ForegroundColor Green
Write-Host ("区域: " + $rect.Width + " x " + $rect.Height) -ForegroundColor DarkGray
if ($Zoom -gt 0) { Write-Host "已自动还原缩放" -ForegroundColor DarkGray }
