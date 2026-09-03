# PixelStreaming 插件修改记录

> 基准版本: UE 5.3 | 在 UE 5.1-5.8 上均适用

---

## 使用方法

1. 从 UE 安装目录复制 PixelStreaming 插件到项目 `Plugins/` 文件夹：

   ```
   C:\Program Files\Epic Games\UE_X.X\Engine\Plugins\Media\PixelStreaming
   → 你的项目\Plugins\PixelStreaming
   ```
2. 按下方说明修改 3 个文件即可。

---

## 修改清单

### 1. `Source/PixelStreaming/PixelStreaming.Build.cs`

在 `// When we build a Game target...` 注释之前插入（上下文如下）：

```csharp
// ... 前面是平台相关依赖 ...
    AddEngineThirdPartyPrivateStaticDependencies(Target, "MetalCPP");
}
// 【在这里插入 ↓】
AddEngineThirdPartyPrivateStaticDependencies(Target, "OpenSSL", "libOpus");
if (ReadOnlyBuildVersion.Current.MinorVersion >= 8)
{
    AddEngineThirdPartyPrivateStaticDependencies(Target, "LibVpx");
}

// When we build a Game target we also package the servers with it as runtime dependencies
if (Target.Type == TargetType.Game && Target.ProjectFile != null)
```

---

### 2. `Source/PixelStreamingInput/Private/ApplicationWrapper.h`

**A. 替换 `GetModifierKeys()`：**（位于 `GetCapture` 方法附近）

```cpp
// ... 上下文 ...
    virtual void* GetCapture(void) const { return WrappedApplication->GetCapture(); }
    // 原版这一行 ↓
    virtual FModifierKeysState GetModifierKeys() const { return WrappedApplication->GetModifierKeys(); }
    // 替换为 ↓
    virtual FModifierKeysState GetModifierKeys() const override
    {
        if (bUseBrowserModifierKeys)
        {
            return BrowserModifierKeys;
        }
        return WrappedApplication->GetModifierKeys();
    }
// ... 继续往下 ...
```

**B. 类末尾（`};` 之前）新增 `SetModifierKeyState()` 方法 + 2 个成员变量：**

```cpp
void SetModifierKeyState(uint8 KeyCode, bool bPressed)
{
    bUseBrowserModifierKeys = true;
    switch (KeyCode)
    {
    case 16:  // LeftShift
        BrowserModifierKeys = FModifierKeysState(
            bPressed, BrowserModifierKeys.IsRightShiftDown(),
            BrowserModifierKeys.IsLeftControlDown(), BrowserModifierKeys.IsRightControlDown(),
            BrowserModifierKeys.IsLeftAltDown(), BrowserModifierKeys.IsRightAltDown(),
            false, false, false); break;
    case 17:  // LeftControl
        BrowserModifierKeys = FModifierKeysState(
            BrowserModifierKeys.IsLeftShiftDown(), BrowserModifierKeys.IsRightShiftDown(),
            bPressed, BrowserModifierKeys.IsRightControlDown(),
            BrowserModifierKeys.IsLeftAltDown(), BrowserModifierKeys.IsRightAltDown(),
            false, false, false); break;
    case 18:  // LeftAlt
        BrowserModifierKeys = FModifierKeysState(
            BrowserModifierKeys.IsLeftShiftDown(), BrowserModifierKeys.IsRightShiftDown(),
            BrowserModifierKeys.IsLeftControlDown(), BrowserModifierKeys.IsRightControlDown(),
            bPressed, BrowserModifierKeys.IsRightAltDown(),
            false, false, false); break;
    case 253: // RightShift
        BrowserModifierKeys = FModifierKeysState(
            BrowserModifierKeys.IsLeftShiftDown(), bPressed,
            BrowserModifierKeys.IsLeftControlDown(), BrowserModifierKeys.IsRightControlDown(),
            BrowserModifierKeys.IsLeftAltDown(), BrowserModifierKeys.IsRightAltDown(),
            false, false, false); break;
    case 254: // RightControl
        BrowserModifierKeys = FModifierKeysState(
            BrowserModifierKeys.IsLeftShiftDown(), BrowserModifierKeys.IsRightShiftDown(),
            BrowserModifierKeys.IsLeftControlDown(), bPressed,
            BrowserModifierKeys.IsLeftAltDown(), BrowserModifierKeys.IsRightAltDown(),
            false, false, false); break;
    case 255: // RightAlt
        BrowserModifierKeys = FModifierKeysState(
            BrowserModifierKeys.IsLeftShiftDown(), BrowserModifierKeys.IsRightShiftDown(),
            BrowserModifierKeys.IsLeftControlDown(), BrowserModifierKeys.IsRightControlDown(),
            BrowserModifierKeys.IsLeftAltDown(), bPressed,
            false, false, false); break;
    }
}

bool bUseBrowserModifierKeys = false;
FModifierKeysState BrowserModifierKeys;
```

---

### 3. `Source/PixelStreamingInput/Private/PixelStreamingInputHandler.cpp`

在 `HandleOnKeyDown` 和 `HandleOnKeyUp` 函数内，`FilterKey()` 调用**之前**各插入 5 行：

```cpp
// ========== HandleOnKeyDown 上下文 ==========
    const FKey* AgnosticKey = JavaScriptKeyCodeToFKey[Payload.Param1];

    // 【在这里插入 ↓】
    if (PixelStreamerApplicationWrapper.IsValid())
    {
        PixelStreamerApplicationWrapper->SetModifierKeyState(Payload.Param1, true);
    }

    if (FilterKey(*AgnosticKey))   // ← 这行是原有的
    {
        // ...

// ========== HandleOnKeyUp 上下文 ==========
    const FKey* AgnosticKey = JavaScriptKeyCodeToFKey[Payload.Param1];

    // 【在这里插入 ↓】
    if (PixelStreamerApplicationWrapper.IsValid())
    {
        PixelStreamerApplicationWrapper->SetModifierKeyState(Payload.Param1, false);
    }

    if (FilterKey(*AgnosticKey))   // ← 这行是原有的
    {
        // ...
```

---

## 作用

修复 Linux 无桌面服务器上 Ctrl/Shift/Alt 快捷键（Ctrl+C/V/Z、Shift+方向键等）不生效的问题。

原理：UE 默认通过 OS 键盘驱动读取修饰键状态，headless 服务器没有物理键盘所以永远为空。改为根据浏览器发来的 KeyDown/KeyUp 事件动态维护修饰键状态。

---

## 升级注意事项

- 仅关注以上 3 个文件，其余全部文件直接用新版本覆盖
- `HandleOnKeyDown/Up` 中新增代码在 `FilterKey()` **之前**
- `SetModifierKeyState` 方法和成员变量在 `ApplicationWrapper.h` 类末尾
- `Build.cs` 新增行在 `Target.bBuildEditor` 块后、`// When we build a Game target...` 前
- `ReadOnlyBuildVersion` 版本判断自动适配 5.3~5.8，无需手动选择
