# 键盘擦拭锁（KeyboardWipeLock）

macOS 键盘清洁模式小工具：

- 一键进入 **擦拭模式**：全屏黑色遮罩。
- 擦拭模式下，键盘/鼠标事件不传给其他应用。
- 只有输入你设置的密码才能解锁恢复。
- 快捷键：**2 秒内连续按 5 下 Option** 进入擦拭模式。

## 说明

- 这是用户态应用，不会物理关闭显示器电源。
- 通过“黑屏遮罩 + 输入锁定”达到防误触效果。

## 本地构建

```bash
chmod +x build_app.sh make_dmg.sh
./build_app.sh
./make_dmg.sh 1.1.0
```

输出：

- `build/KeyboardWipeLock.app`
- `build/KeyboardWipeLock-1.1.0.dmg`

## GitHub Actions

工作流：`.github/workflows/build-dmg.yml`

- 手动触发（workflow_dispatch）或打 tag（`v*`）触发。
- 自动生成图标并打包 DMG。
- tag 触发时会自动创建 Release 并上传 DMG。

## 使用

1. 启动 App
2. 输入密码并点击 **保存密码**
3. 点击 **进入擦拭模式**（或 2 秒内连按 5 次 Option）
4. 清洁键盘
5. 输入密码并点 **解锁** 退出
