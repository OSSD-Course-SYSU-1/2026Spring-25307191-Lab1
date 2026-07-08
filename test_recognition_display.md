# 语音识别结果显示问题分析

## 问题现象
用户反馈"没有显示出识别的原文"

## 代码流程分析

### 1. 文件识别流程
1. 用户点击"Select .wav file (16kHz)"按钮（第 651 行）
2. onClick 事件中：
   - 清空 `resultForFile`（第 657 行）
   - 打开文件选择器（第 663-664 行）
   - 选择文件后，发送 'non-streaming-asr-vad-decode' 消息给 worker（第 676 行）

3. Worker 处理：
   - 解码音频文件（第 86-149 行）
   - 发送 partial 结果（第 142 行）
   - 发送 done 结果（第 232 行）

4. Index.ets 接收消息：
   - 处理 'non-streaming-asr-vad-decode-partial'（第 179-186 行）
   - 处理 'non-streaming-asr-vad-decode-done'（第 171-177 行）

### 2. 麦克风识别流程
1. 用户点击录音按钮（第 728 行）
2. 录音过程中：
   - 实时发送音频数据给 worker
   - Worker 发送 partial 结果（第 188 行）

3. 录音停止后：
   - Worker 发送 done 结果（第 245 行）
   - Index.ets 接收并更新 `resultForMic`（第 207-213 行）

### 3. 结果显示逻辑
在 `ResultDisplayArea` 组件中（第 534-628 行）：
- 第 558 行：`if (result)` - 只有当 result 不为空时才显示原文区域
- 第 589 行：`TextArea({ text: result })` - 显示识别原文
- 第 598 行：`if (translatedResult && this.targetLang !== 'none')` - 显示译文区域

## 可能的问题

### 问题 1：resultForFile 被覆盖
在第 173 行：
```typescript
this.resultForFile = text + '\n';
```
这会覆盖之前的 partial 结果。如果 `text` 是空字符串，那么 `resultForFile` 就会是 `'\n'`，TextArea 会显示一个空行。

### 问题 2：resultList 为空
在 worker 中，如果没有识别到语音段，`resultList` 就会是空的，`resultList.join('\n\n')` 会返回空字符串。

### 问题 3：显示条件不满足
在第 558 行，条件 `if (result)` 要求 `result` 不为空。如果 `result` 是空字符串或 `'\n'`，可能会有问题。

## 建议的修复方案

### 方案 1：改进空结果处理
在 worker 中，如果没有识别到语音段，应该返回一个提示消息，而不是空字符串。

### 方案 2：改进显示逻辑
在 ResultDisplayArea 中，改进显示条件，确保即使识别结果为空也能给出提示。

### 方案 3：添加调试日志
在关键位置添加 console.log，帮助定位问题。
