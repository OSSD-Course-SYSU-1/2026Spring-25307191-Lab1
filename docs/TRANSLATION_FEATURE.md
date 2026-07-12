# 翻译功能说明文档

## 概述

本应用在原有的语音识别（VAD + ASR）功能基础上，新增了**实时翻译功能**，支持将识别出的语音内容自动翻译为多种目标语言。

---

## 功能特点

### 1. 多语言支持

支持 **11 种语言** 的翻译：

| 语言 | 代码 | 国旗 |
|------|------|------|
| 中文 | zh | 🇨🇳 |
| 英语 | en | 🇬🇧 |
| 日语 | ja | 🇯🇵 |
| 韩语 | ko | 🇰🇷 |
| 法语 | fr | 🇫🇷 |
| 德语 | de | 🇩🇪 |
| 西班牙语 | es | 🇪🇸 |
| 俄语 | ru | 🇷🇺 |
| 葡萄牙语 | pt | 🇵🇹 |
| 意大利语 | it | 🇮🇹 |

### 2. 自动翻译流程

```
语音输入 → VAD检测 → ASR识别 → 自动翻译 → 结果展示
```

- 语音识别完成后**自动触发翻译**
- 切换目标语言后**自动重新翻译**
- 无需手动点击翻译按钮

### 3. 双模式支持

| 模式 | 说明 |
|------|------|
| **文件模式** | 选择 .wav 音频文件进行识别和翻译 |
| **麦克风模式** | 实时录音识别并翻译 |

### 4. 智能源语言检测

- 自动检测源语言（中文/英语/日语/韩语/粤语等）
- 无需手动指定源语言

### 5. 服务高可用

- 内置 **3 个 Lingva 翻译服务实例**
- 自动故障切换
- 单个实例失败时自动尝试下一个

---

## 实现方式

### 架构设计

```
┌─────────────────────────────────────────────────────────────┐
│                        UI 层 (Index.ets)                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ 语言选择器   │  │ 翻译状态    │  │ 结果显示区域        │  │
│  │ (Select)    │  │ (Loading)   │  │ (原文 + 译文)       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  翻译工具层 (LingvaTranslator.ets)           │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  translate(text, to, from) → TranslateResult        │    │
│  │  - 多实例轮询                                        │    │
│  │  - HTTP 请求封装                                     │    │
│  │  - JSON 响应解析                                     │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    网络层 (@kit.NetworkKit)                  │
│                    HTTP GET 请求                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Lingva 翻译服务 API                       │
│         https://lingva.ml/api/v1/{from}/{to}/{text}         │
└─────────────────────────────────────────────────────────────┘
```

### 核心文件

| 文件路径 | 说明 |
|----------|------|
| `entry/src/main/ets/utils/LingvaTranslator.ets` | 翻译工具类，封装 Lingva API 调用 |
| `entry/src/main/ets/pages/Index.ets` | 主界面，集成翻译 UI 和逻辑 |
| `entry/src/main/module.json5` | 网络权限配置 |

### 关键接口定义

```typescript
// 翻译结果
interface TranslateResult {
  original: string;      // 原文
  translated: string;    // 译文
  fromLang: string;      // 源语言
  toLang: string;        // 目标语言
  success: boolean;      // 是否成功
  error?: string;        // 错误信息
}

// 语言选项
interface LanguageOption {
  code: string;          // 语言代码
  name: string;          // 显示名称
  flag: string;          // 国旗 emoji
}
```

### 翻译流程

```typescript
// 1. 用户选择目标语言
onLanguageChange() {
  this.targetLang = selectedLanguage;
}

// 2. 语音识别完成后自动触发翻译
onRecognitionResult(text) {
  this.originalText = text;
  this.autoTranslate(text);
}

// 3. 调用翻译 API
async autoTranslate(text: string) {
  const result = await translator.translate(text, this.targetLang, 'auto');
  if (result.success) {
    this.translatedText = result.translated;
  }
}
```

### HTTP 请求实现

```typescript
// 使用 HarmonyOS NetworkKit
import { http } from '@kit.NetworkKit';

const httpRequest = http.createHttp();
const response = await httpRequest.request(url, {
  method: http.RequestMethod.GET,
  header: {
    'User-Agent': 'Mozilla/5.0 (HarmonyOS) SherpaOnnxVadAsr',
    'Accept': 'application/json',
  },
  connectTimeout: 30000,
  readTimeout: 30000,
});
```

### 多实例故障切换

```typescript
private static readonly INSTANCES: string[] = [
  'https://lingva.ml',
  'https://translate.drakon.pro',
  'https://lingva.lunar.icu'
];

// 当前实例失败时自动切换下一个
for (let i = 0; i < INSTANCES.length; i++) {
  try {
    return await translateWithInstance(INSTANCES[currentIndex]);
  } catch (error) {
    currentIndex = (currentIndex + 1) % INSTANCES.length;
  }
}
```

---

## API 说明

### Lingva 翻译 API

**请求格式：**
```
GET https://lingva.ml/api/v1/{source_lang}/{target_lang}/{text}
```

**参数说明：**

| 参数 | 说明 | 示例 |
|------|------|------|
| source_lang | 源语言代码，`auto` 表示自动检测 | `auto` |
| target_lang | 目标语言代码 | `en` |
| text | URL 编码的待翻译文本 | `%E4%BD%A0%E5%A5%BD` |

**响应格式：**
```json
{
  "translation": "Hello"
}
```

**示例请求：**
```
https://lingva.ml/api/v1/auto/en/你好世界
```

**示例响应：**
```json
{
  "translation": "Hello world"
}
```

---

## 权限配置

### 网络权限

在 `module.json5` 中添加：

```json
{
  "requestPermissions": [
    {
      "name": "ohos.permission.INTERNET",
      "reason": "$string:internet_reason",
      "usedScene": {
        "abilities": ["EntryAbility"],
        "when": "inuse"
      }
    }
  ]
}
```

### 权限说明文本

在 `string.json` 中添加：

```json
{
  "name": "internet_reason",
  "value": "access the internet for translation service"
}
```

---

## 使用说明

### 操作步骤

1. **启动应用** - 等待模型初始化完成

2. **选择目标语言**
   - 在"翻译为"下拉菜单中选择目标语言
   - 默认为"不翻译"

3. **进行语音识别**
   - **文件模式**：点击"Select .wav file"选择音频文件
   - **麦克风模式**：点击"Start recording"开始录音，再次点击停止

4. **查看结果**
   - 上方显示识别结果（原文）
   - 下方显示翻译结果（译文）

### 界面说明

```
┌─────────────────────────────────────────┐
│  Next-gen Kaldi: VAD + ASR              │
├─────────────────────────────────────────┤
│  [Select .wav file (16kHz)]             │
│                                         │
│  Supported languages: Auto-detect...    │
│                                         │
│  翻译为: [🇬🇧 English ▼]  ← 语言选择器   │
│                                         │
│  ⏳ 正在翻译...          ← 翻译状态      │
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ 📝 识别结果 (原文)                  ││
│  │ 0.00 -- 2.35 你好世界               ││
│  └─────────────────────────────────────┘│
│                                         │
│  ┌─────────────────────────────────────┐│
│  │ 🔤 翻译结果 (🇬🇧 English)           ││
│  │ Hello world                         ││
│  └─────────────────────────────────────┘│
└─────────────────────────────────────────┘
```

---

## 扩展指南

### 添加新语言

在 `LingvaTranslator.ets` 中修改 `LANGUAGES` 数组：

```typescript
public static readonly LANGUAGES: LanguageOption[] = [
  // ... 现有语言
  { code: 'ar', name: 'العربية', flag: '🇸🇦' },  // 新增阿拉伯语
  { code: 'hi', name: 'हिन्दी', flag: '🇮🇳' },    // 新增印地语
];
```

### 添加备用翻译实例

```typescript
private static readonly INSTANCES: string[] = [
  'https://lingva.ml',
  'https://translate.drakon.pro',
  'https://lingva.lunar.icu',
  // 添加新实例
  'https://your-instance.com',
];
```

### 切换到其他翻译服务

可替换为其他开源翻译 API：

| 服务 | API 格式 | 说明 |
|------|---------|------|
| LibreTranslate | `https://libretranslate.com/translate` | 需要自建服务 |
| MyMemory | `https://api.mymemory.translated.net/get` | 免费限额 |
| DeepL | `https://api-free.deepl.com/v2/translate` | 需要 API Key |

---

## 注意事项

1. **网络依赖** - 翻译功能需要网络连接，语音识别可离线运行

2. **服务稳定性** - Lingva 为公共服务，可能存在不稳定情况，已内置多实例切换

3. **文本长度** - 超长文本可能被截断或翻译失败

4. **特殊字符** - 文本会自动进行 URL 编码

5. **隐私说明** - 翻译文本会发送到第三方服务器，敏感内容请谨慎使用

---

## 技术栈

| 组件 | 技术 |[TRANSLATION_FEATURE.md](TRANSLATION_FEATURE.md)
|------|------|
| 开发框架 | HarmonyOS ArkTS |
| UI 组件 | ArkUI 声明式语法 |
| 网络请求 | @kit.NetworkKit |
| 翻译服务 | Lingva (开源) |
| 语音识别 | Sherpa-ONNX (本地) |

---

## 更新日志

### v1.1.0 

- ✨ 新增翻译功能
- ✨ 支持 11 种语言翻译
- ✨ 自动源语言检测
- ✨ 多实例故障切换
- ✨ 翻译状态指示器
- ✨ 分区域显示原文和译文

---

## 相关链接

- [Lingva Translate (GitHub)](https://github.com/thedaviddelta/lingva-translate)
- [Sherpa-ONNX (GitHub)](https://github.com/k2-fsa/sherpa-onnx)
- [HarmonyOS 开发文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/)
