# WhoAmI

以第二视角，记录事实，检视判断。

原生 SwiftUI iOS Demo。冷白、石墨黑、钢灰；三个底部入口：**总览、记录、对比**。打开即可使用。

![总览、七维轮盘记录、日期对比](design/screenshots/overview.png)

以上为 iPhone 16e 真实模拟器截图，展示不同测试状态。可查看[保存后的七维黑焰](design/screenshots/wheel-saved.png)、[输入与键盘](design/screenshots/record-keyboard.png)和[只读详情](design/screenshots/comparison-detail.png)。

## 当前交互

- **总览：**今日覆盖的维度、七维最新状态、最近七天记录活动。展示依据来自实际记录，示例单独标记。
- **记录：**约占屏幕三分之一的七等分轮盘，只显示七个自绘图标。轻点、横滑或沿轮盘拖动选择维度，正文区自动显示名称和引导问题。七个维度各自保留内容与草稿。
- **心境：**按住三段渐深灰色能量条拖动，松手收起，只留下对应黑色火苗；轻点火苗可再次调整。1–33 淡漠、34–66 平静、67–99 冲动，数值在记录页隐藏。
- **保存：**保存当前维度的正文和心境，轮盘对应区外缘出现动态黑焰，页面回到轮盘。每次变更形成带日期的快照；没有变更时重复保存不增加重复记录。
- **对比：**按日期显示维度、火焰和数值。点击查看正文与状态，详情只读。

心境是个人自评，不是模型推断。首次需要拖选心境再保存，不自动代填；旧记录没有数值时显示“—”。已有记录和旧草稿保留，新版存储兼容上一版 JSON。

## 语音

记录页麦克风按钮使用 Apple Speech 与 AVAudioEngine，将语音转成可编辑文字。仅点按语音时请求系统麦克风和语音识别权限。

支持设备端识别时优先设备端处理；其他设备可能使用 Apple 语音识别服务。系统权限被拒绝、音频不可用或识别服务不可用时，会给出状态说明，仍可打字。语音没有接入独立云端模型，也不持久保存原始音频。

## Xcode 运行

1. 打开 `WhoAmI.xcodeproj`。
2. 选择 `WhoAmI` Scheme 和 iPhone 模拟器，运行。
3. 真机调试选择自己的签名 Team；语音识别建议在真机验证。

支持 iOS 17+，以 iPhone 竖屏、浅色主题为主。无第三方包依赖。

```sh
xcodebuild -project WhoAmI.xcodeproj -scheme WhoAmI \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

```sh
xcodebuild -project WhoAmI.xcodeproj -scheme WhoAmI \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -derivedDataPath build/DerivedData -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test
```

测试会重置专用测试模拟器中的本 App 数据。运行结果、当前截图及未覆盖范围见 [验证记录](design-qa.md)。

本轮完整 UI 测试 **4/4 通过**；最终布局调整后，键盘/快照与轮盘/三 Tab 两项相关测试再次 **2/2 通过**。语音转写尚未进行真机实测。

## 实现

- `DimensionRecordView`：七页内容、语音转写、心境与保存流程。
- `ObservationControls`：轮盘、自绘七维图标、三档动态火焰与拖动能量条。
- `DashboardView` / `ComparisonView`：总览与只读对比。
- `SpeechRecorder`：按需权限、语音识别与音频会话清理。
- `AppStore`：本地 JSON、独立草稿、历史快照及旧版数据兼容。

AI 分析、云同步、后台提醒与备份导入尚未实现。旧版日记/复盘/档案视图代码保留，但不再作为底栏入口。

- [项目描述](项目描述.md)
- [UI 设计说明](design/UI设计说明.md)
