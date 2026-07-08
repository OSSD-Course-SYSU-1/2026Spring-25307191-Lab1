# HeardVoice - 鸿蒙本地语音识别助手

基于 [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) 的 HarmonyOS 本地语音识别应用，支持全设备响应式适配。

## 功能特性

- 🎙️ 本地语音识别（VAD + ASR），无需网络
- 📝 麦克风实时录音识别
- 📁 本地 wav 文件识别
- 🌐 中文/英文/日文/韩文/粤语自动检测
- 🔒 完全本地运行，保护隐私
- 📱 全设备适配：手机、平板、折叠屏、手表、车机、智慧屏

## 技术栈

- HarmonyOS / OpenHarmony
- ArkTS / ArkUI
- GridRow / GridCol 响应式布局
- 官方断点标准（sm / md / lg）
- sherpa-onnx 三方库

## 项目结构
```
entry/src/main/ets/
├── common/                     # 公共层
│   ├── utils/                  # 工具类层
│   │   ├── BreakpointUtil.ets  # 响应式断点计算 (sm/md/lg)
│   │   ├── DeviceUtil.ets      # 设备类型与屏幕参数
│   │   └── DistributedUtil.ets # 多设备协同流转
│   ├── components/             # 组件层
│   │   ├── AdaptiveButton.ets  # 自适应按钮
│   │   └── AdaptiveTextArea.ets # 自适应文本区域
│   └── models/                 # 数据模型层
├── pages/
│   └── Index.ets               # 主页面 (GridRow 响应式布局)
├── entryability/
│   └── EntryAbility.ets        # 入口 Ability + 分布式流转
└── workers/
    ├── NonStreamingAsrWithVadWorker.ets  # 后台语音识别
    ├── NonStreamingAsrModels.ets         # 模型配置 (23 种)
    └── Permission.ets                    # 权限申请
```
    


## 运行环境

| 项 | 要求 |
|---|---|
| DevEco Studio | 4.0 Release 及以上 |
| HarmonyOS SDK | API 11 及以上 |
| 支持设备 | 手机、平板、折叠屏（2in1）、车机、智慧屏、手表 |
| 所需权限 | `MICROPHONE`、`INTERNET`、`GET_NETWORK_INFO` |

## 模型文件说明

由于模型文件较大（~200MB），未包含在仓库中。

**下载方式：**
1. 从 sherpa-onnx 官方仓库下载 SenseVoice 模型
2. 将以下文件放入 `entry/src/main/resources/rawfile/`：
   - `silero_vad.onnx`（VAD 模型）
   - `model.int8.onnx`（ASR 模型）
   - `tokens.txt`（词表）

**官方模型下载：** https://github.com/k2-fsa/sherpa-onnx/releases

## 项目来源

- 原始仓库: [k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
- 基础工程: `harmony-os/SherpaOnnxVadAsr`
- 开源协议: Apache-2.0

## 更新日志

### 最新
- **多设备适配** — 新增响应式布局架构，支持全设备类型（phone / tablet / 2in1 / car / tv / wearable）
- **Worker 修复** — 修复 VAD 对象错误使用及异常处理缺失

### 历史
- **模型切换** — `const type = 2` → `const type = 15`，切换为 SenseVoice 中文模型
