# 怎么用这个 Python(嵌入式版)

## 一句话

嵌入式 Python **不在 PATH 里**,没有 `python` 这个名字可用 —— **只能用绝对路径叫它**。

所以:**不需要 where。你本来就知道它在哪。**

---

## 直接抄这几条

假设你的 python 在 `D:\我的Agent\runtime\python.exe`(**路径要加引号**):

```bat
:: 跑脚本
"D:\我的Agent\runtime\python.exe" "D:\我的Agent\main.py"

:: 装库
"D:\我的Agent\runtime\python.exe" -m pip install requests

:: 看版本
"D:\我的Agent\runtime\python.exe" -V

:: 看它是谁(打印自己的绝对路径)
"D:\我的Agent\runtime\python.exe" -c "import sys;print(sys.executable)"

:: 看装了哪些库
"D:\我的Agent\runtime\python.exe" -m pip list
```

想立刻试一下?用你桌面那个:

```bat
"C:\Users\Administrator\Desktop\嵌入式Python\python-3.12.9-64位\python.exe" -V
```

---

## where 为什么找不到它

| 命令 | 结果 |
|---|---|
| `where python` | ❌ 找不到它(只找到系统那个,甚至 WindowsApps 假货) |
| `py -0p` | ❌ 找不到它(它不写注册表) |
| 绝对路径 | ✅ **唯一可靠的方式** |

`where` 的作用是"在 PATH 里找",而嵌入式版**故意不进 PATH**。所以对它来说 where 是无用功。

**结论:绝对路径不是"绕远路",而是唯一正确的姿势。**

---

## 不想写死盘符?

### .bat 里用 `%~dp0`

`%~dp0` = 这个 bat 自己所在的文件夹:

```bat
@echo off
"%~dp0runtime\python.exe" "%~dp0main.py"
pause
```

整个文件夹搬到任何盘、任何电脑都能跑。

### Python 里用 sys.executable

```python
import sys, pathlib
print(sys.executable)                           # 当前解释器的绝对路径
RUNTIME = pathlib.Path(sys.executable).parent    # 它的文件夹
```

---

## 装库必须这样写

```bat
❌ pip install requests
✅ "D:\我的Agent\runtime\python.exe" -m pip install requests
```

裸写 `pip` 会走 PATH → 装到**系统那个** Python 里去了。

**装完验证(输出里的路径就是答案):**

```bat
"D:\我的Agent\runtime\python.exe" -m pip -V
```

**国内加速:**

```bat
"D:\我的Agent\runtime\python.exe" -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple requests
```
