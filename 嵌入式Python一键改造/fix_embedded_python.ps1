# ============================================================
#  嵌入式 Python 一键改造 → pip 可用版
#  兼容 Windows PowerShell 5.1 与 PowerShell 7+
#  用法:双击「修复嵌入式Python.bat」,或把嵌入式 Python 文件夹拖到 bat 上
# ============================================================
param([Parameter(Position = 0)][string]$TargetDir)

$ErrorActionPreference = 'Continue'
# 注意:不要在这里强制 [Console]::OutputEncoding = UTF8,
# 否则在 GBK(936)的 cmd 窗口里中文会全变乱码。保持默认即可。

function Say  ($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Ok   ($m) { Say "[ OK ] $m" 'Green' }
function Warn ($m) { Say "[WARN] $m" 'Yellow' }
function Bad  ($m) { Say "[FAIL] $m" 'Red' }
function Head ($m) { Say ""; Say "===== $m =====" 'Cyan' }

Say ""
Say "  嵌入式 Python 一键改造工具" 'White'
Say "  (自动启用 site + 安装 pip,原配置会自动备份)" 'DarkGray'

# ------------------------------------------------------------
Head "1/6 定位嵌入式 Python"

if (-not $TargetDir) {
    Say "把【嵌入式 Python 的文件夹】拖到本窗口(或粘贴路径),然后回车:" 'Yellow'
    $TargetDir = Read-Host "  > "
}
if (-not $TargetDir) { Bad "没有提供路径,已退出"; exit 1 }

$TargetDir = $TargetDir.Trim().Trim('"').Trim("'")
if (-not (Test-Path -LiteralPath $TargetDir -PathType Container)) {
    Bad "目录不存在:$TargetDir"; exit 1
}
$TargetDir = (Resolve-Path -LiteralPath $TargetDir).Path
$py = Join-Path $TargetDir 'python.exe'
if (-not (Test-Path -LiteralPath $py)) {
    Bad "这个目录里没有 python.exe"
    Say "  你选的是:$TargetDir" 'DarkGray'
    Say "  请选【python.exe 所在的那一层】,例如 …\python-3.12.9-64位\" 'Yellow'
    exit 1
}
Ok "解释器:$py"

# ------------------------------------------------------------
Head "2/6 识别版本"

$info = & $py -c "import sys;print(sys.version.split()[0]);print('%d%d' % sys.version_info[:2]);print(64 if sys.maxsize > 2**32 else 32)"
if ($LASTEXITCODE -ne 0 -or $info.Count -lt 3) {
    Bad "无法运行该 python.exe,可能文件损坏或缺少 vcruntime 运行库"
    exit 1
}
$ver  = "$($info[0])".Trim()
$tag  = "$($info[1])".Trim()
$arch = "$($info[2])".Trim()
Ok "版本 $ver / $arch 位 / 标签 python$tag"

# ------------------------------------------------------------
Head "3/6 修正 ._pth(启用 site + site-packages)"

$pthFile = Get-ChildItem -LiteralPath $TargetDir -Filter '*._pth' -File -ErrorAction SilentlyContinue | Select-Object -First 1
$sp = Join-Path $TargetDir 'Lib\site-packages'

if (-not $pthFile) {
    Warn "没找到 ._pth 文件,按标准嵌入式结构新建一个"
    $pthPath = Join-Path $TargetDir "python$tag._pth"
    $seed = "python$tag.zip`r`nLib\site-packages`r`n.`r`n`r`nimport site`r`n"
    Set-Content -LiteralPath $pthPath -Value $seed -Encoding ASCII
    Ok "已新建:python$tag._pth"
} else {
    $pthPath = $pthFile.FullName
    $bakPath = "$pthPath.bak"

    if (-not (Test-Path -LiteralPath $bakPath)) {
        Copy-Item -LiteralPath $pthPath -Destination $bakPath
        Ok "原配置已备份 → $([IO.Path]::GetFileName($bakPath))"
    } else {
        Warn "备份已存在,保留最原始那份不动"
    }

    $text = Get-Content -LiteralPath $pthPath -Raw
    $changed = $false

    # ① 取消 "#import site" 的注释
    if ($text -match '(?m)^\s*#\s*import\s+site\s*$') {
        $text = $text -replace '(?m)^\s*#\s*import\s+site\s*$', 'import site'
        $changed = $true
    }
    # ② 补上 Lib\site-packages 搜索路径
    if ($text -notmatch '(?m)^\s*Lib[\\/]site-packages\s*$') {
        if ($text -match '(?m)^.*\.zip\s*$') {
            $text = $text -replace '(?m)^(.*\.zip\s*)$', "`$1`r`nLib\site-packages"
        } else {
            $text = "Lib\site-packages`r`n" + $text
        }
        $changed = $true
    }
    # ③ 兜底:确保 import site 一定生效
    if ($text -notmatch '(?m)^\s*import\s+site\s*$') {
        $text = $text.TrimEnd() + "`r`nimport site`r`n"
        $changed = $true
    }

    if ($changed) {
        Set-Content -LiteralPath $pthPath -Value $text -Encoding ASCII
        Ok "已更新 $([IO.Path]::GetFileName($pthPath))"
    } else {
        Ok "._pth 已是正确配置,无需改动"
    }
}

if (-not (Test-Path -LiteralPath $sp)) {
    New-Item -ItemType Directory -Force -Path $sp | Out-Null
    Ok "已创建 Lib\site-packages"
} else {
    Ok "Lib\site-packages 已存在"
}

# ------------------------------------------------------------
Head "4/6 检查 pip"

$pipOut = (& $py -m pip --version 2>&1 | Out-String).Trim()
$needPip = $true
if ($LASTEXITCODE -eq 0 -and $pipOut -match '^pip\s') {
    Ok "pip 已可用:$pipOut"
    $needPip = $false
} else {
    Warn "当前没有 pip,准备安装"
}

# ------------------------------------------------------------
if ($needPip) {
    Head "5/6 安装 pip"

    $installed = $false
    $tmp = Join-Path $env:TEMP 'get-pip.py'
    $urls = @(
        'https://bootstrap.pypa.io/pip/get-pip.py',
        'https://bootstrap.pypa.io/get-pip.py'
    )

    # —— 方案 A:官方 get-pip.py ——
    foreach ($u in $urls) {
        if ($installed) { break }
        Say "尝试下载:$u" 'DarkGray'

        $downloaded = $false
        if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
            & curl.exe -L --fail --silent --show-error --connect-timeout 15 -o $tmp $u 2>$null
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $tmp)) {
                if ((Get-Item -LiteralPath $tmp).Length -gt 10000) { $downloaded = $true }
            }
        } else {
            try {
                Invoke-WebRequest -Uri $u -OutFile $tmp -UseBasicParsing -TimeoutSec 30
                if ((Test-Path -LiteralPath $tmp) -and (Get-Item -LiteralPath $tmp).Length -gt 10000) { $downloaded = $true }
            } catch { $downloaded = $false }
        }

        if ($downloaded) {
            Ok "下载成功,正在安装…"
            # 先走国内镜像(快得多),失败再退回官方源
            foreach ($mirror in @('https://pypi.tuna.tsinghua.edu.cn/simple', '')) {
                if ($installed) { break }
                if ($mirror) {
                    Say "  用镜像安装:$mirror" 'DarkGray'
                    & $py $tmp --no-warn-script-location --timeout 60 -i $mirror
                } else {
                    Say "  镜像不通,改用官方源安装…" 'DarkGray'
                    & $py $tmp --no-warn-script-location --timeout 60
                }
                if ($LASTEXITCODE -eq 0) { $installed = $true; Ok "pip 安装完成" }
                else { Warn "这一路失败(退出码 $LASTEXITCODE)" }
            }
        } else {
            Warn "下载失败或文件不完整"
        }
    }

    # —— 方案 B:借本机已有完整版 Python 的 pip,用 --target 直接灌进来 ——
    if (-not $installed) {
        Say ""
        Warn "改用备用方案:借用本机已有 Python 的 pip(无需联网也能成)"
        $donors = @()

        $pyLauncher = Get-Command 'py.exe' -ErrorAction SilentlyContinue
        if ($pyLauncher) {
            $p = (& $pyLauncher.Source -c "import sys;print(sys.executable)" 2>$null | Out-String).Trim()
            if ($p -and (Test-Path -LiteralPath $p)) { $donors += $p }
        }
        foreach ($c in (Get-Command 'python.exe' -All -ErrorAction SilentlyContinue)) {
            if ($c.Source -notmatch 'WindowsApps' -and $c.Source -ne $py) { $donors += $c.Source }
        }
        $donors = $donors | Select-Object -Unique

        foreach ($d in $donors) {
            if ($installed) { break }
            Say "  试:$d" 'DarkGray'
            $okThis = $false
            # 同样先走国内镜像,失败再退回官方源
            foreach ($mirror in @('https://pypi.tuna.tsinghua.edu.cn/simple', '')) {
                if ($okThis) { break }
                if ($mirror) {
                    Say "    用镜像拉取(通常几十秒)…" 'DarkGray'
                    & $d -m pip install --target="$sp" --upgrade --no-warn-script-location --timeout 60 -i $mirror pip setuptools wheel
                } else {
                    Say "    镜像不通,改用官方源(会慢一些)…" 'DarkGray'
                    & $d -m pip install --target="$sp" --upgrade --no-warn-script-location --timeout 60 pip setuptools wheel
                }
                if ($LASTEXITCODE -eq 0) { $okThis = $true }
            }
            if ($okThis) { $installed = $true; Ok "已借 $d 把 pip 装入本目录" }
        }
    }

    if (-not $installed) {
        Bad "两种方案都失败了"
        Say "  手动办法:浏览器打开 https://bootstrap.pypa.io/get-pip.py 另存为 get-pip.py," 'Yellow'
        Say "  然后执行:  `"$py`" `"<get-pip.py 的路径>`"" 'Yellow'
    }

    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

# ------------------------------------------------------------
Head "6/6 自检报告"

$pipOut = (& $py -m pip --version 2>&1 | Out-String).Trim()
if ($LASTEXITCODE -eq 0 -and $pipOut -match '^pip\s') {
    Ok "pip 正常:$pipOut"
} else {
    Bad "pip 仍不可用 → $pipOut"
}

Say ""
Say "  解释器路径 : $py"
Say "  版本 / 架构 : $ver / $arch 位"
Say "  库安装位置 : $sp"
Say "  sys.path  :"
& $py -c "import sys;[print('    ', p) for p in sys.path]"

# ------------------------------------------------------------
Say ""
Say "============ 以后怎么用 ============" 'Cyan'
Say "① 给它装库(必须写全路径 + -m pip,不要裸写 pip):" 'White'
Say "   `"$py`" -m pip install requests" 'Gray'
Say ""
Say "② 国内加速(网络慢时加 -i):" 'White'
Say "   `"$py`" -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple requests" 'Gray'
Say ""
Say "③ 确认装到哪个 Python 了(-V 输出的路径就是答案):" 'White'
Say "   `"$py`" -m pip -V" 'Gray'
Say ""
Say "④ 确认某个库装在哪:" 'White'
Say "   `"$py`" -c `"import requests;print(requests.__file__)`"" 'Gray'
Say ""
Say "⑤ 相对路径调用(在 agent 的启动脚本里,不要写死盘符):" 'White'
Say "   `"%~dp0runtime\python.exe`" `"%~dp0main.py`"" 'Gray'
Say ""
Say "完成。" 'Green'
