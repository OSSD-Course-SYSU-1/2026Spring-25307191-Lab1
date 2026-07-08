# HeardVoice - 鸿蒙本地语音识别助手

基于 [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) 的 HarmonyOS 本地语音识别应用。

## 功能特性

- 🎙️ 本地语音识别（VAD + ASR），无需网络
- 📝 支持麦克风实时录音识别
- 📁 支持本地 wav 文件识别
- 🌐 支持中文/英文/日文/韩文/粤语自动检测
- 🔒 完全本地运行，保护隐私

## 技术栈

- HarmonyOS / OpenHarmony
- ArkTS / ArkUI
- sherpa-onnx 三方库

## 核心模块

| 文件 | 功能 |
|------|------|
| `Index.ets` | 主页面 UI，文件识别/麦克风录音/帮助三个标签页 |
| `NonStreamingAsrWithVadWorker.ets` | Worker 线程，后台执行语音识别 |
| `NonStreamingAsrModels.ets` | 模型配置管理，支持 23 种模型 |
| `Permission.ets` | 动态申请麦克风权限 |

## 运行环境

- DevEco Studio: 4.0 Release 及以上
- HarmonyOS SDK: API 11 及以上
- 设备: 鸿蒙模拟器或真机
- 权限: 麦克风权限（`ohos.permission.MICROPHONE`）

## 模型文件说明

由于模型文件较大（~200MB），未包含在仓库中。

**下载方式：**
1. 从 sherpa-onnx 官方仓库下载 SenseVoice 模型
2. 将以下文件放入 `entry/src/main/resources/rawfile/` 目录：
   - `silero_vad.onnx`（VAD 模型）
   - `model.int8.onnx`（ASR 模型）
   - `tokens.txt`（词表）

**官方模型下载：** https://github.com/k2-fsa/sherpa-onnx/releases

## 项目来源

- 原始仓库: [k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)
- 基础工程: `harmony-os/SherpaOnnxVadAsr`
- 开源协议: Apache-2.0

## 修改记录

- 模型配置: 将 `const type = 2` 改为 `const type = 15`，切换为 SenseVoice 中文模型
