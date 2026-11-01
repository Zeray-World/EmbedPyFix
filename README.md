# EmbedPyFix · 嵌入式 Python 一键改造

把 Windows 官方的 **embeddable（嵌入版）Python** 改造成 `pip` 可用、第三方库可导入的便携环境。

不下载新的 Python，不写 PATH，不改注册表，不动系统里已有的解释器——
只修复你手上这个文件夹。

---

## 要解决的三件事

嵌入版为了体积做了三刀，每一刀都会让你装完包却 `ModuleNotFoundError`：

| 缺什么 | 表现 | 这个脚本做什么 |
|---|---|---|
| `pip` | `No module named pip` / 没有 `pip.exe` | 用 `get-pip.py` 装，失败则借本机 Python 的 pip 灌进来 |
| `import site` | `._pth` 里被注释掉，site 机制不启动 | 自动取消注释，缺失则补上 |
| `Lib\site-packages` | 不在 `._pth` 白名单里，装了也找不到 | 补进 `._pth`，目录不存在就创建 |

改完 `._pth` 后，嵌入版的模块搜索就从"只认白名单"变成和完整版一致。

---

## 它做什么

1. **定位**：`python.exe` 必须在你指定的那一层；选错会告诉你该选哪层
2. **识别**：跑一次 `python.exe` 拿版本、位数、`python312` 这种标签；文件损坏或缺 `vcruntime` 会直接报出来
3. **改 `._pth`**：解锁 `import site`、补 `Lib\site-packages`；文件缺失就按标准结构新建
4. **备份**：第一次改动前存一份 `pythonXX._pth.bak`，之后重复运行**不会覆盖**最初那份
5. **装 pip**：见下一节的两条路
6. **自检**：打印 pip 版本、解释器路径、位数、库目录和完整 `sys.path`，并给出以后怎么用的命令

全程幂等：改对了再跑一遍只会输出"无需改动"。

---

## 用法

把嵌入式 Python 文件夹拖到 `修复嵌入式Python.bat` 上，或者双击后粘贴路径回车。

```text
修复嵌入式Python.bat  →  fix_embedded_python.ps1
```

也可以命令行直接调：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\fix_embedded_python.ps1 "D:\Agent\runtime"
```

兼容 Windows PowerShell 5.1 和 PowerShell 7+。

---

## pip 是怎么装上的

**方案 A：官方 `get-pip.py`**

依次尝试 `bootstrap.pypa.io/pip/get-pip.py` 和 `bootstrap.pypa.io/get-pip.py`；
有 `curl.exe` 就用 curl，没有就用 `Invoke-WebRequest`；下载后先走清华镜像，失败再回官方源。

**方案 B：借本机已有的 Python**

A 走不通时，自动找 `py.exe` 和 PATH 里（排除 WindowsApps 假货）的 `python.exe`，
用它的 pip 执行：

```powershell
python.exe -m pip install --target="...\Lib\site-packages" --upgrade pip setuptools wheel
```

这条路绕开了 get-pip.py 的下载，也绕开"本机 pip 装错解释器"的老问题。
注意它仍然需要联网拉包（除非本机 pip 缓存里已有）。

两条都失败时，会打印手动方案并给出确切的命令，不会静默退出。

---

## 改造后的目录

```text
runtime\
├─ python.exe
├─ python312.dll
├─ python312._pth          # import site + Lib\site-packages
├─ python312._pth.bak      # 原始配置，只备份一次
├─ Lib\
│  └─ site-packages\       # 第三方库装在这里
└─ Scripts\                # get-pip.py 装出来的入口脚本
```

---

## 之后怎么用

嵌入式版**不在 PATH 里**，`where python` 和 `py -0p` 都找不到它。只能用绝对路径：

```bat
:: 跑脚本
"D:\Agent\runtime\python.exe" "D:\Agent\main.py"

:: 装库（必须 -m pip，裸写 pip 会装到系统 Python）
"D:\Agent\runtime\python.exe" -m pip install requests

:: 国内加速
"D:\Agent\runtime\python.exe" -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple requests

:: 确认装到哪个解释器（输出里的路径就是答案）
"D:\Agent\runtime\python.exe" -m pip -V
```

不想写死盘符，用 `%~dp0`：

```bat
"%~dp0runtime\python.exe" "%~dp0main.py"
```

---

## 它不修什么

- **tkinter**：嵌入版不带 `_tkinter.pyd` / Tcl/Tk，需要另从对应版本的安装包或 `tcltk.msi` 里取
- **ssl**：部分嵌入包缺 `_ssl.pyd` 和 OpenSSL DLL，`pip` 会报 SSL 错误，本脚本不处理
- **venv**：嵌入版移除了 `ensurepip` 和 `venv`，装完 pip 也建不了虚拟环境
- **C 扩展**：本地编译的包必须和解释器版本、位数严格匹配，装不上是版本问题不是脚本问题
- **PATH / 注册表**：刻意不碰，保证可移植、可回滚

---

## 相关项目

| 项目 | 差异 |
|---|---|
| [PythonEmbed4Win](https://github.com/jtmoon79/PythonEmbed4Win) | 从 `embed.zip` 新建环境，不就地修复已有目录 |
| [PyStand](https://github.com/skywind3000/PyStand) | 只管启动嵌入式运行时，不负责装 pip |

---
