# HeardVoice 工程文件描述

## 一、项目概述

本项目基于开源项目 [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) 的 HarmonyOS 示例工程 SherpaOnnxVadAsr，实现本地语音识别功能。

### 1.1 项目来源
- **原始仓库**: https://github.com/k2-fsa/sherpa-onnx
- **基础工程**: harmony-os/SherpaOnnxVadAsr
- **开源协议**: Apache-2.0

### 1.2 核心功能
- VAD（语音活动检测）：自动检测语音片段
- ASR（自动语音识别）：将语音转换为文字
- 支持麦克风实时录音识别
- 支持本地 wav 文件识别

## 二、技术架构

### 2.1 技术栈
- **开发平台**: HarmonyOS / OpenHarmony
- **开发语言**: ArkTS
- **UI 框架**: ArkUI
- **音频处理**: @kit.AudioKit
- **语音识别**: sherpa_onnx 三方库


## 三、核心模块说明

### 3.1 Index.ets（主页面）
- 功能：应用主界面，包含三个标签页
  - From file：选择 wav 文件进行语音识别
  - From mic：麦克风录音实时识别
  - Help：帮助信息
- 关键组件：Tabs、Button、TextArea、AudioCapturer

### 3.2 NonStreamingAsrWithVadWorker.ets（Worker 线程）
- 功能：在后台线程执行语音识别，避免阻塞 UI
- 核心函数：
  - `initVad()`：初始化 VAD 模型
  - `initNonStreamingAsr()`：初始化 ASR 模型
  - `decodeFile()`：文件识别
  - `decodeMic()`：麦克风录音识别

### 3.3 NonStreamingAsrModels.ets（模型配置）
- 功能：管理多种语音识别模型配置
- 支持模型：Paraformer、Whisper、SenseVoice 等 23 种
- 当前配置：type=15（SenseVoice 中文多语言模型）

## 四、模型说明

| 模型 | 文件 | 用途 | 大小 |
|------|------|------|------|
| silero_vad.onnx | VAD 模型 | 语音活动检测 | ~1MB |
| model.int8.onnx | ASR 模型 | 语音识别（SenseVoice） | ~239MB |
| tokens.txt | 词表 | 文本解码 | ~300KB |

### 4.1 SenseVoice 模型特性
- 支持语言：中文、英文、日文、韩文、粤语
- 模型格式：ONNX INT8 量化
- 运行方式：本地离线运行，无需网络

## 五、运行环境

- **DevEco Studio**: 4.0 Release 及以上
- **HarmonyOS SDK**: API 11 及以上
- **设备**: 鸿蒙模拟器或真机
- **权限**: 麦克风权限（ohos.permission.MICROPHONE）

## 六、修改记录

### 6.1 模型配置修改
- **修改文件**: NonStreamingAsrWithVadWorker.ets
- **修改内容**: 将 `const type = 2` 改为 `const type = 15`
- **修改原因**: 切换为 SenseVoice 中文模型，支持中文语音识别

### 6.2 模型文件部署
- **操作**: 下载并放置模型文件到 `rawfile` 目录
- **文件**: silero_vad.onnx、model.int8.onnx、tokens.txt

---

## 七、参考文档

- [sherpa-onnx 官方文档](https://k2-fsa.github.io/sherpa/onnx/)
- [鸿蒙语音识别开发指南](https://developer.harmonyos.com/)
- [sherpa-onnx HarmonyOS 示例](https://github.com/k2-fsa/sherpa-onnx/tree/master/harmony-os)
