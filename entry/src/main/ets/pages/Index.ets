import { LengthUnit } from '@kit.ArkUI';
import worker, { MessageEvents } from '@ohos.worker';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { picker } from '@kit.CoreFileKit';

import { Permissions } from '@kit.AbilityKit';
import { allAllowed, requestPermissions } from './Permission';
import { audio } from '@kit.AudioKit';
import { LingvaTranslator, translator, LanguageOption, TranslateResult, TranslatorState } from '../utils/LingvaTranslator';
import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';

// 导入响应式布局工具类
import { BreakpointUtil, Breakpoint } from '../common/utils/BreakpointUtil';
import { DeviceUtil } from '../common/utils/DeviceUtil';
import { ContinueState } from '../common/utils/DistributedUtil';


@Entry
@Component
struct Index {
  @State title: string = 'Next-gen Kaldi: VAD + ASR';
  @State currentIndex: number = 0;
  @State resultForFile: string = '';
  @State progressForFile: number = 0;
  @State selectFileBtnEnabled: boolean = false;
  @State lang: string = 'Auto-detect(中文/English/日本語/한국어/粤语)';
  @State resultForMic: string = '';
  @State micStarted: boolean = false;
  @State message: string = 'Start recording';
  @State micInitDone: boolean = false;

  // ====== 响应式布局状态 ======
  @State currentBreakpoint: string = Breakpoint.SM;
  @State deviceType: string = 'phone';
  @State isLandscape: boolean = false;

  // ====== 翻译相关状态 ======
  @State targetLang: string = 'none';  // 目标翻译语言，默认不翻译
  @State isTranslatingFile: boolean = false;  // 文件翻译中状态
  @State isTranslatingMic: boolean = false;   // 麦克风翻译中状态
  @State translatedResultForFile: string = ''; // 文件翻译结果
  @State translatedResultForMic: string = '';  // 麦克风翻译结果
  @State originalTextForFile: string = '';     // 文件原文（用于翻译）
  @State originalTextForMic: string = '';      // 麦克风原文（用于翻译）
  @State translatorState: TranslatorState = TranslatorState.NOT_INITIALIZED;  // 翻译器状态
  @State translatorMessage: string = '';  // 翻译器状态消息

  // ====== 错误处理状态 ======
  @State isVadInitializing: boolean = true;  // VAD 初始化中
  @State isAsrInitializing: boolean = true;  // ASR 初始化中
  @State vadErrorMessage: string = '';  // VAD 错误消息
  @State asrErrorMessage: string = '';  // ASR 错误消息

  // 语言选项
  private languageOptions: LanguageOption[] = LingvaTranslator.LANGUAGES;
  private controller: TabsController = new TabsController();
  private workerInstance?: worker.ThreadWorker
  private readonly scriptURL: string = 'entry/ets/workers/NonStreamingAsrWithVadWorker.ets'
  private mic?: audio.AudioCapturer;
  private sampleList: Float32Array[] = []

  flatten(samples: Float32Array[]): Float32Array {
    let n = 0;
    for (let i = 0; i < samples.length; ++i) {
      n += samples[i].length;
    }

    const ans: Float32Array = new Float32Array(n);
    let offset: number = 0;
    for (let i = 0; i < samples.length; ++i) {
      ans.set(samples[i], offset);
      offset += samples[i].length;
    }

    return ans;
  }

  async initMic(): Promise<void> {
    const permissions: Permissions[] = ["ohos.permission.MICROPHONE"];
    let allowed: boolean = await allAllowed(permissions);
    if (!allowed) {
      console.log("request to access the microphone");
      const status: boolean = await requestPermissions(permissions);

      if (!status) {
        console.error('access to microphone is denied')
        this.resultForMic = "Failed to get microphone permission. Please retry";
        return;
      }

      allowed = await allAllowed(permissions);
      if (!allowed) {
        console.error('failed to get microphone permission');
        this.resultForMic = "Failed to get microphone permission. Please retry";
        return;
      }
    } else {
      console.log("allowed to access microphone");
    }

    const audioStreamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,
    };

    const audioCapturerInfo: audio.AudioCapturerInfo = {
      source: audio.SourceType.SOURCE_TYPE_MIC, capturerFlags: 0
    };

    const audioCapturerOptions: audio.AudioCapturerOptions = {
      streamInfo: audioStreamInfo, capturerInfo: audioCapturerInfo

    };
    audio.createAudioCapturer(audioCapturerOptions, (err, data) => {
      if (err) {
        console.error(`error code is ${err.code}, error message is ${err.message}`);
        this.resultForMic = 'Failed to init microphone';
      } else {
        console.info(`init mic successfully`);
        this.mic = data;
        if (deviceInfo.sdkApiVersion >= 11) {
          try {
            this.mic.on('readData', this.micCallback);
          } catch (error) {
            // TODO: Implement error handling.
          }
        } else {
          // Fallback to an earlier version
        }

        if (this.workerInstance) {
          try {
            this.workerInstance.postMessage({ msgType: 'init-vad-mic', context: getContext() });
          } catch (error) {
            // TODO: Implement error handling.
          }
        }
      }
    });
  }

  async aboutToAppear(): Promise<void> {
    // ====== 初始化响应式布局 ======
    this.deviceType = DeviceUtil.getDeviceType();
    this.isLandscape = DeviceUtil.isLandscape();
    console.info(`[页面初始化] 设备类型: ${this.deviceType}, 横屏: ${this.isLandscape}`);

    // 检查是否有流转过来的状态
    this.checkContinueState();

    // 设置翻译器状态回调
    translator.setStateCallback((state: TranslatorState, message: string) => {
      this.translatorState = state;
      this.translatorMessage = message;
    });

    this.workerInstance = new worker.ThreadWorker(this.scriptURL, {
      name: 'NonStreaming ASR worker'
    });

    this.workerInstance.onmessage = (e: MessageEvents) => {
      const msgType = e.data['msgType'] as string;
      console.log(`received msg from worker: ${msgType}`);

      // ====== VAD 初始化消息 ======
      if (msgType == 'init-vad-done') {
        this.isVadInitializing = false;
        this.vadErrorMessage = '';
        console.log('[VAD初始化] VAD 初始化成功');
      }

      if (msgType == 'init-vad-error') {
        const error = e.data['error'] as string;
        this.isVadInitializing = false;
        this.vadErrorMessage = error;
        console.error(`[VAD初始化错误] ${error}`);
        this.resultForFile = `VAD初始化失败: ${error}`;
      }

      if (msgType == 'init-vad-mic-done') {
        this.micInitDone = true;
        console.log('[VAD初始化] 麦克风 VAD 初始化成功');
      }

      if (msgType == 'init-vad-mic-error') {
        const error = e.data['error'] as string;
        console.error(`[麦克风VAD初始化错误] ${error}`);
        this.resultForMic = `麦克风VAD初始化失败: ${error}`;
      }

      // ====== ASR 初始化消息 ======
      if (msgType == 'init-non-streaming-asr-done') {
        this.isAsrInitializing = false;
        this.asrErrorMessage = '';
        this.selectFileBtnEnabled = true;
        this.resultForFile = `Initializing done.\n\nPlease select a wave file of 16kHz in language ${this.lang}`;
        console.log('[ASR初始化] ASR 初始化成功');
      }

      if (msgType == 'init-non-streaming-asr-error') {
        const error = e.data['error'] as string;
        this.isAsrInitializing = false;
        this.asrErrorMessage = error;
        console.error(`[ASR初始化错误] ${error}`);
        this.resultForFile = `ASR初始化失败: ${error}`;
      }

      // ====== 文件识别消息 ======
      if (msgType == 'non-streaming-asr-vad-decode-done') {
        const text = e.data['text'] as string;
        console.log(`[识别完成] 文件识别结果: ${text}`);
        this.resultForFile = text;
        this.originalTextForFile = text;
        // 识别完成后自动翻译
        this.autoTranslateFileResult(text);
      }

      if (msgType == 'non-streaming-asr-vad-decode-partial') {
        const partialText = e.data['text'] as string;
        console.log(`[识别进行中] 文件识别部分结果: ${partialText}`);
        if (this.resultForFile == '') {
          this.resultForFile = partialText;
        } else {
          this.resultForFile += '\n\n' + partialText;
        }
        this.originalTextForFile = this.resultForFile;
      }

      if (msgType == 'non-streaming-asr-vad-decode-error') {
        const errorText = e.data['text'] as string;
        console.error(`[识别错误] 文件识别错误: ${errorText}`);
        this.resultForFile = errorText;
      }

      if (msgType == 'non-streaming-asr-vad-decode-progress') {
        this.progressForFile = e.data['progress'] as number;
        this.selectFileBtnEnabled = this.progressForFile >= 100;
      }

      // ====== 麦克风识别消息 ======
      if (msgType == 'non-streaming-asr-vad-mic-partial') {
        const partialText = e.data['text'] as string;
        console.log(`[识别进行中] 麦克风识别部分结果: ${partialText}`);
        if (this.resultForMic == '') {
          this.resultForMic = partialText;
        } else {
          this.resultForMic += '\n\n' + partialText;
        }
        this.originalTextForMic = this.resultForMic;
      }

      if (msgType == 'non-streaming-asr-vad-mic-done') {
        const text = e.data['text'] as string;
        console.log(`[识别完成] 麦克风识别结果: ${text}`);
        this.resultForMic = text;
        this.originalTextForMic = text;
        // 识别完成后自动翻译
        this.onMicRecordingStopped();
      }

      if (msgType == 'non-streaming-asr-vad-mic-error') {
        const errorText = e.data['text'] as string;
        console.error(`[识别错误] 麦克风识别错误: ${errorText}`);
        this.resultForMic = errorText;
      }
    }

    const context = getContext();
    
    // 显示初始化状态
    this.resultForFile = 'Initializing models...\n- VAD: 初始化中...\n- ASR: 等待中...';
    
    try {
      this.workerInstance.postMessage({ msgType: 'init-vad', context });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('Failed to send init-vad message:', errorMsg);
      this.vadErrorMessage = errorMsg;
    }
    
    this.resultForFile = 'Initializing models...\n- VAD: 初始化中...\n- ASR: 初始化中...';
    try {
      this.workerInstance.postMessage({ msgType: 'init-non-streaming-asr', context });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('Failed to send init-non-streaming-asr message:', errorMsg);
      this.asrErrorMessage = errorMsg;
    }

    await this.initMic();
  }

  /**
   * 复制文本到剪贴板
   */
  copyToClipboard(text: string): void {
    if (!text || text.trim() === '') {
      try {
        promptAction.showToast({ message: '没有可复制的内容', duration: 2000 });
      } catch (error) {
        // TODO: Implement error handling.
      }
      return;
    }

    try {
      const pasteboardData = pasteboard.createPlainTextData(text);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      systemPasteboard.setData(pasteboardData).then(() => {
        promptAction.showToast({ message: '已复制到剪贴板', duration: 2000 });
      }).catch((error: Error) => {
        const errorMsg = error.message || String(error);
        promptAction.showToast({ message: '复制失败: ' + errorMsg, duration: 2000 });
      });
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      promptAction.showToast({ message: '复制失败: ' + errorMsg, duration: 2000 });
    }
  }

  /**
   * 清空文件识别结果
   */
  clearFileResult(): void {
    this.resultForFile = '';
    this.translatedResultForFile = '';
    this.originalTextForFile = '';
    this.progressForFile = 0;
  }

  /**
   * 清空麦克风识别结果
   */
  clearMicResult(): void {
    this.resultForMic = '';
    this.translatedResultForMic = '';
    this.originalTextForMic = '';
  }

  /**
   * 自动翻译文件识别结果
   */
  async autoTranslateFileResult(text: string): Promise<void> {
    if (this.targetLang === 'none' || !text || text.trim() === '') {
      this.translatedResultForFile = '';
      return;
    }

    this.isTranslatingFile = true;
    this.translatedResultForFile = '翻译中...';

    try {
      console.info('[翻译] 开始翻译文件结果, 目标语言: ' + this.targetLang);
      const result: TranslateResult = await translator.translate(text, this.targetLang, 'auto');
      if (result.success) {
        this.translatedResultForFile = result.translated;
        console.info('[翻译] 文件翻译成功');
      } else {
        const errorMsg = result.error || '未知错误';
        this.translatedResultForFile = '(翻译失败: ' + errorMsg + ')';
        console.error('[翻译] 文件翻译失败: ' + errorMsg);
        promptAction.showToast({ message: '翻译失败: ' + errorMsg, duration: 3000 });
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      this.translatedResultForFile = '(翻译异常: ' + errorMsg + ')';
      console.error('[翻译] 文件翻译异常: ' + errorMsg);
      promptAction.showToast({ message: '翻译异常: ' + errorMsg, duration: 3000 });
    } finally {
      this.isTranslatingFile = false;
    }
  }

  /**
   * 自动翻译麦克风识别结果
   */
  async autoTranslateMicResult(text: string): Promise<void> {
    if (this.targetLang === 'none' || !text || text.trim() === '') {
      this.translatedResultForMic = '';
      return;
    }

    this.isTranslatingMic = true;
    this.translatedResultForMic = '翻译中...';

    try {
      console.info('[翻译] 开始翻译麦克风结果, 目标语言: ' + this.targetLang);
      const result: TranslateResult = await translator.translate(text, this.targetLang, 'auto');
      if (result.success) {
        this.translatedResultForMic = result.translated;
        console.info('[翻译] 麦克风翻译成功');
      } else {
        const errorMsg = result.error || '未知错误';
        this.translatedResultForMic = '(翻译失败: ' + errorMsg + ')';
        console.error('[翻译] 麦克风翻译失败: ' + errorMsg);
        promptAction.showToast({ message: '翻译失败: ' + errorMsg, duration: 3000 });
      }
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      this.translatedResultForMic = '(翻译异常: ' + errorMsg + ')';
      console.error('[翻译] 麦克风翻译异常: ' + errorMsg);
      promptAction.showToast({ message: '翻译异常: ' + errorMsg, duration: 3000 });
    } finally {
      this.isTranslatingMic = false;
    }
  }

  /**
   * 手动触发翻译（用户切换语言时）
   */
  async onLanguageChange(): Promise<void> {
    if (this.currentIndex === 0 && this.originalTextForFile) {
      await this.autoTranslateFileResult(this.originalTextForFile);
    } else if (this.currentIndex === 1 && this.originalTextForMic) {
      await this.autoTranslateMicResult(this.originalTextForMic);
    }
  }

  /**
   * 麦克风录音停止后自动翻译
   */
  async onMicRecordingStopped(): Promise<void> {
    if (this.targetLang !== 'none' && this.originalTextForMic) {
      await this.autoTranslateMicResult(this.originalTextForMic);
    }
  }

  /**
   * 检查应用接续状态（分布式流转）
   */
  private checkContinueState(): void {
    const continueState: ContinueState | undefined = AppStorage.get('continueState');
    if (continueState) {
      this.currentIndex = continueState.currentTabIndex ?? 0;
      this.currentBreakpoint = continueState.currentBreakpoint ?? Breakpoint.SM;

      // 清除状态避免重复应用
      AppStorage.delete('continueState');
      console.info('[状态恢复] 应用接续状态:' + JSON.stringify(continueState));
    }
  }

  /**
   * 获取响应式字体大小
   */
  private getTitleFontSize(): number {
    switch (this.currentBreakpoint) {
      case Breakpoint.XS:
        return 16;
      case Breakpoint.SM:
        return 20;
      case Breakpoint.MD:
        return 22;
      case Breakpoint.LG:
        return 24;
      case Breakpoint.XL:
        return 28;
      default:
        return 20;
    }
  }

  /**
   * 获取响应式按钮宽度
   */
  private getButtonWidth(): number | string {
    switch (this.currentBreakpoint) {
      case Breakpoint.XS:
        return '90%';
      case Breakpoint.SM:
        return 296;
      case Breakpoint.MD:
        return 320;
      case Breakpoint.LG:
        return 360;
      case Breakpoint.XL:
        return 400;
      default:
        return 296;
    }
  }

  /**
   * 获取响应式按钮高度
   */
  private getButtonHeight(): number {
    switch (this.currentBreakpoint) {
      case Breakpoint.XS:
        return 48;
      case Breakpoint.SM:
        return 60;
      case Breakpoint.MD:
        return 56;
      case Breakpoint.LG:
        return 52;
      case Breakpoint.XL:
        return 56;
      default:
        return 60;
    }
  }

  /**
   * 获取响应式文本区域高度
   */
  private getTextAreaHeight(hasTranslation: boolean): number {
    const baseHeight = hasTranslation ? 150 : 250;
    switch (this.currentBreakpoint) {
      case Breakpoint.XS:
        return Math.min(120, baseHeight);
      case Breakpoint.SM:
        return baseHeight;
      case Breakpoint.MD:
        return Math.min(180, baseHeight);
      case Breakpoint.LG:
        return Math.min(200, baseHeight);
      case Breakpoint.XL:
        return Math.min(220, baseHeight);
      default:
        return baseHeight;
    }
  }

  @Builder
  TabBuilder(title: string, targetIndex: number, selectedImg: Resource, normalImg: Resource) {
    Column() {
      Image(this.currentIndex == targetIndex ? selectedImg : normalImg).size({ width: 25, height: 25 })
      Text(title).fontColor(this.currentIndex == targetIndex ? '#28bff1' : '#8a8a8a')
    }.width('100%').height(50).justifyContent(FlexAlign.Center).onClick(() => {
      this.currentIndex = targetIndex;
      this.controller.changeIndex(this.currentIndex);
    })
  }

  /**
   * 语言选择下拉菜单构建器
   */
  @Builder
  LanguageSelector() {
    Column() {
      Row() {
        Text('翻译为: ')
          .fontSize(14)
          .fontColor('#666666');

        Select(this.languageOptions.map(l => ({ value: l.flag + ' ' + l.name } as SelectOption)))
          .selected(this.languageOptions.findIndex(l => l.code === this.targetLang))
          .value(LingvaTranslator.getLanguageDisplayName(this.targetLang))
          .font({ size: 14 })
          .fontColor('#333333')
          .selectedOptionFont({ size: 14 })
          .optionFont({ size: 14 })
          .onSelect((index: number) => {
            this.targetLang = this.languageOptions[index].code;
            console.log('选择目标语言: ' + this.targetLang);
            this.onLanguageChange();
          })
          .width(180)
          .height(35);
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: 16, right: 16 });

      // 翻译器状态提示
      if (this.targetLang !== 'none' && this.translatorState !== TranslatorState.READY) {
        Row() {
          if (this.translatorState === TranslatorState.TRANSLATING) {
            LoadingProgress()
              .width(16)
              .height(16)
              .color('#28bff1');
          }
          Text(this.translatorMessage || this.translatorState)
            .fontSize(12)
            .fontColor(this.translatorState === TranslatorState.ERROR ? '#F44336' : '#FF9800')
            .margin({ left: 4 });
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4 });
      }
    }
    .width('100%')
    .margin({ top: 8, bottom: 8 });
  }

  /**
   * 结果显示区域构建器（提取公共组件）
   */
  @Builder
  ResultDisplayArea(
    result: string,
    translatedResult: string,
    isTranslating: boolean,
    clearFunc: () => void
  ) {
    Column() {
      // 翻译状态指示器
      if (isTranslating) {
        Row() {
          LoadingProgress()
            .width(20)
            .height(20)
            .color('#28bff1');
          Text(' 正在翻译...')
            .fontSize(14)
            .fontColor('#28bff1');
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .margin({ top: 4, bottom: 4 });
      }

      // 原文区域
      if (result) {
        Column() {
          Row() {
            Text('📝 识别结果 (原文)')
              .fontSize(14)
              .fontColor('#666666')
              .layoutWeight(1);

            // 操作按钮
            Row({ space: 8 }) {
              Button('复制')
                .fontSize(12)
                .height(28)
                .padding({ left: 8, right: 8 })
                .onClick(() => {
                  this.copyToClipboard(result);
                });

              Button('清空')
                .fontSize(12)
                .height(28)
                .padding({ left: 8, right: 8 })
                .backgroundColor('#FF5722')
                .onClick(() => {
                  clearFunc();
                });
            }
          }
          .width('100%')
          .padding({ left: 8, right: 8 });

          TextArea({ text: result })
            .width('100%')
            .height(this.getTextAreaHeight(translatedResult !== '' && this.targetLang !== 'none'))
            .enabled(false);
        }
        .width('100%');
      } else {
        // 显示等待识别的提示
        Column() {
          Text('等待识别...')
            .fontSize(14)
            .fontColor('#999999')
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 20, bottom: 20 });
        }
        .width('100%');
      }

      // 译文区域
      if (translatedResult && this.targetLang !== 'none') {
        Column() {
          Row() {
            Text('🔤 翻译结果 (' + LingvaTranslator.getLanguageDisplayName(this.targetLang) + ')')
              .fontSize(14)
              .fontColor('#28bff1')
              .layoutWeight(1);

            Button('复制')
              .fontSize(12)
              .height(28)
              .padding({ left: 8, right: 8 })
              .onClick(() => {
                this.copyToClipboard(translatedResult);
              });
          }
          .width('100%')
          .padding({ left: 8, right: 8, top: 8 });

          TextArea({ text: translatedResult })
            .width('100%')
            .height(150)
            .fontColor('#333333')
            .enabled(false);
        }
        .width('100%');
      }
    }
    .width('100%')
    .layoutWeight(1);
  }

  build() {
    // 使用GridRow实现响应式布局
    GridRow({
      columns: BreakpointUtil.COLUMNS,
      gutter: { x: 12, y: 12 },
      breakpoints: {
        value: BreakpointUtil.BREAKPOINTS,
        reference: BreakpointsReference.WindowSize
      }
    }) {
      GridCol({ span: BreakpointUtil.getCardSpan(this.currentBreakpoint) }) {
        Column() {
          Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
            // ====== Tab 1: From file ======
            TabContent() {
              Column({ space: 10 }) {
                Text(this.title)
                  .fontSize(this.getTitleFontSize())
                  .fontWeight(FontWeight.Bold);

                if (canIUse("SystemCapability.FileManagement.UserFileService")) {
                  Button('Select .wav file (16kHz) ')
                    .enabled(this.selectFileBtnEnabled)
                    .fontSize(13)
                    .width(this.getButtonWidth())
                    .height(this.getButtonHeight())
                    .onClick(() => {
                      this.resultForFile = '';
                      this.progressForFile = 0;

                      const documentSelectOptions = new picker.DocumentSelectOptions();
                      documentSelectOptions.maxSelectNumber = 1;
                      documentSelectOptions.fileSuffixFilters = ['.wav'];
                      const documentViewPicker = new picker.DocumentViewPicker();
                      documentViewPicker.select(documentSelectOptions).then((result: Array<string>) => {
                        console.log(`Result: ${result}`);

                        if (!result[0]) {
                          this.resultForFile = 'Please select a file to decode';
                          this.selectFileBtnEnabled = true;
                          return;
                        }

                        if (this.workerInstance) {
                          try {
                            this.workerInstance.postMessage({
                              msgType: 'non-streaming-asr-vad-decode', filename: result[0],
                            });
                          } catch (error) {
                            // TODO: Implement error handling.
                          }
                        } else {
                          console.log(`this worker instance is undefined ${this.workerInstance}`);
                        }
                      }).catch((err: BusinessError) => {
                        console.error(`Failed to select file, code is ${err.code}, message is ${err.message}`);
                      })
                    })
                } else {
                  // Fallback for unsupported SystemCapability
                }

                Text(`Supported languages: ${this.lang}`)

                // 语言选择器
                this.LanguageSelector();

                if (this.progressForFile > 0) {
                  Row() {
                    Progress({ value: 0, total: 100, type: ProgressType.Capsule })
                      .width('80%')
                      .height(20)
                      .value(this.progressForFile);

                    Text(`${this.progressForFile.toFixed(2)}%`).width('15%')
                  }.width('100%').justifyContent(FlexAlign.Center)
                }

                // 结果显示区域（使用公共组件）
                this.ResultDisplayArea(
                  this.resultForFile,
                  this.translatedResultForFile,
                  this.isTranslatingFile,
                  () => this.clearFileResult()
                );
              }
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Start)
            }
            .tabBar(this.TabBuilder('From file', 0, $r('app.media.icon_doc'), $r('app.media.icon_doc')))

            // ====== Tab 2: From mic ======
            TabContent() {
              Column({ space: 10 }) {
                Text(this.title)
                  .fontSize(this.getTitleFontSize())
                  .fontWeight(FontWeight.Bold);

                Button(this.message)
                  .enabled(this.micInitDone)
                  .width(this.getButtonWidth())
                  .height(this.getButtonHeight())
                  .onClick(() => {
                    console.log('clicked mic button');
                    this.resultForMic = '';
                    this.translatedResultForMic = '';
                    this.originalTextForMic = '';
                    if (this.mic) {
                      if (this.micStarted) {
                        this.mic.stop();
                        this.message = "Start recording";
                        this.micStarted = false;
                        console.log('mic stopped');

                        const samples = this.flatten(this.sampleList);
                        let s = 0;
                        for (let i = 0; i < samples.length; ++i) {
                          s += samples[i];
                        }
                        console.log(`samples ${samples.length}, sum: ${s}`);

                        if (this.workerInstance) {
                          console.log('decode mic');
                          this.workerInstance.postMessage({
                            msgType: 'non-streaming-asr-vad-mic', samples,
                          });
                        } else {
                          console.log(`this worker instance is undefined ${this.workerInstance}`);
                        }
                      } else {
                        this.sampleList = [];
                        this.mic.start();
                        this.message = "Stop recording";
                        this.micStarted = true;
                        console.log('mic started');
                      }
                    }
                  });

                // 录音指示器
                if (this.micStarted) {
                  Row() {
                    Circle()
                      .width(12)
                      .height(12)
                      .fill('#FF0000');
                    Text(' 录音中')
                      .fontSize(12)
                      .fontColor('#FF0000');
                  }
                  .margin({ top: 4 });
                }

                Text(`Supported languages: ${this.lang}`)

                // 语言选择器
                this.LanguageSelector();

                // 结果显示区域（使用公共组件）
                this.ResultDisplayArea(
                  this.resultForMic,
                  this.translatedResultForMic,
                  this.isTranslatingMic,
                  () => this.clearMicResult()
                );
              }
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Start)
            }
            .tabBar(this.TabBuilder('From mic', 1, $r('app.media.icon_mic'), $r('app.media.icon_mic')))

            // ====== Tab 3: Help ======
            TabContent() {
              Column({ space: 10 }) {
                Text(this.title)
                  .fontSize(this.getTitleFontSize())
                  .fontWeight(FontWeight.Bold);

                TextArea({
                  text: 'Everyting is open-sourced.\n\nIt runs locally, without accessing the network\n\nSee also https://github.com/k2-fsa/sherpa-onnx\n\n新一代 Kaldi QQ 和微信交流群: 请看\n\nhttps://k2-fsa.github.io/sherpa/social-groups.html\n\n微信公众号: 新一代 Kaldi'
                })
                  .width('100%')
                  .height('100%')
                  .focusable(false)
              }
              .width('100%')
              .height('100%')
            }
            .tabBar(this.TabBuilder('Help', 2, $r('app.media.info'), $r('app.media.info')))
          }
          .scrollable(false)
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
        .padding(this.currentBreakpoint === Breakpoint.XS || this.currentBreakpoint === Breakpoint.SM ? 8 : 16)
      }
    }
    .onBreakpointChange((breakpoint: string) => {
      this.currentBreakpoint = breakpoint;
      console.info('[断点变化] 当前断点: ' + breakpoint);
    })
  }

  private micCallback = (buffer: ArrayBuffer) => {
    const view: Int16Array = new Int16Array(buffer);

    const samplesFloat: Float32Array = new Float32Array(view.length);
    for (let i = 0; i < view.length; ++i) {
      samplesFloat[i] = view[i] / 32768.0;
    }
    this.sampleList.push(samplesFloat);
  }
}