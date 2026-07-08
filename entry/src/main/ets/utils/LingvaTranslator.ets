/**
 * Lingva 翻译工具类 - HarmonyOS 版本
 * 使用开源翻译服务 Lingva 进行文本翻译
 * 
 * 支持的语言代码: zh(中文), en(英文), ja(日语), ko(韩语), 
 *               fr(法语), de(德语), es(西班牙语), ru(俄语) 等
 */

import { http } from '@kit.NetworkKit';

// 翻译器状态枚举
export enum TranslatorState {
  NOT_INITIALIZED = '未初始化',
  READY = '就绪',
  PREPARING = '准备中',
  DOWNLOADING = '下载模型中',
  TRANSLATING = '翻译中',
  ERROR = '错误'
}

// 翻译结果接口
export interface TranslateResult {
  original: string;      // 原文
  translated: string;    // 译文
  fromLang: string;      // 源语言
  toLang: string;        // 目标语言
  success: boolean;      // 是否成功
  error?: string;        // 错误信息
}

// 语言选项接口
export interface LanguageOption {
  code: string;          // 语言代码 (如 'zh', 'en')
  name: string;          // 显示名称 (如 '中文', 'English')
  flag: string;          // 国旗 emoji
}

// Lingva API 响应接口
interface LingvaResponse {
  translation: string;
}

// 状态回调类型
export type StateCallback = (state: TranslatorState, message: string) => void;

// Lingva 翻译器类
export class LingvaTranslator {
  // 可用的 Lingva 实例列表（备用）
  private static readonly INSTANCES: string[] = [
    'https://lingva.ml',
    'https://translate.drakon.pro',
    'https://lingva.lunar.icu'
  ];
  
  private currentInstanceIndex: number = 0;
  private timeout: number = 30000; // 30秒超时
  private stateCallback?: StateCallback;
  private currentState: TranslatorState = TranslatorState.READY;
  
  /**
   * 设置状态回调
   */
  setStateCallback(callback: StateCallback): void {
    this.stateCallback = callback;
    // 初始状态通知
    callback(this.currentState, '翻译器就绪');
  }
  
  /**
   * 更新状态
   */
  private updateState(state: TranslatorState, message: string): void {
    this.currentState = state;
    if (this.stateCallback) {
      this.stateCallback(state, message);
    }
  }
  
  // 支持的语言列表
  public static readonly LANGUAGES: LanguageOption[] = [
    { code: 'none', name: '不翻译', flag: '🚫' },
    { code: 'zh', name: '中文', flag: '🇨🇳' },
    { code: 'en', name: 'English', flag: '🇬🇧' },
    { code: 'ja', name: '日本語', flag: '🇯🇵' },
    { code: 'ko', name: '한국어', flag: '🇰🇷' },
    { code: 'fr', name: 'Français', flag: '🇫🇷' },
    { code: 'de', name: 'Deutsch', flag: '🇩🇪' },
    { code: 'es', name: 'Español', flag: '🇪🇸' },
    { code: 'ru', name: 'Русский', flag: '🇷🇺' },
    { code: 'pt', name: 'Português', flag: '🇵🇹' },
    { code: 'it', name: 'Italiano', flag: '🇮🇹' },
  ];
  
  /**
   * 翻译文本
   * @param text 要翻译的文本
   * @param to 目标语言代码
   * @param from 源语言代码（默认 'auto' 自动检测）
   * @returns 翻译结果
   */
  async translate(text: string, to: string, from: string = 'auto'): Promise<TranslateResult> {
    console.info('[Lingva] 开始翻译, 目标语言: ' + to + ', 文本长度: ' + text.length);
    
    // 空文本直接返回
    if (!text || text.trim() === '') {
      console.warn('[Lingva] 文本为空');
      return {
        original: text,
        translated: '',
        fromLang: from,
        toLang: to,
        success: false,
        error: '文本为空'
      };
    }
    
    // 不翻译选项
    if (to === 'none') {
      console.info('[Lingva] 选择不翻译');
      return {
        original: text,
        translated: text,
        fromLang: from,
        toLang: to,
        success: true
      };
    }
    
    // 更新状态为翻译中
    this.updateState(TranslatorState.TRANSLATING, '正在翻译...');
    
    // 尝试使用不同的实例
    let lastError: string = '';
    for (let i = 0; i < LingvaTranslator.INSTANCES.length; i++) {
      const instance = LingvaTranslator.INSTANCES[this.currentInstanceIndex];
      console.info('[Lingva] 尝试实例: ' + instance);
      
      try {
        const result = await this.translateWithInstance(instance, text, from, to);
        console.info('[Lingva] 翻译成功');
        // 更新状态为就绪
        this.updateState(TranslatorState.READY, '翻译完成');
        return result;
      } catch (error) {
        let errorMsg: string;
        if (error instanceof Error) {
          errorMsg = error.message;
        } else if (typeof error === 'object' && error !== null) {
          errorMsg = JSON.stringify(error);
        } else {
          errorMsg = String(error);
        }
        lastError = '实例 ' + instance + ' 失败: ' + errorMsg;
        console.error('[Lingva] ' + lastError);
        // 切换到下一个实例
        this.currentInstanceIndex = (this.currentInstanceIndex + 1) % LingvaTranslator.INSTANCES.length;
      }
    }
    
    // 所有实例都失败
    console.error('[Lingva] 所有实例都失败');
    this.updateState(TranslatorState.ERROR, lastError || '翻译服务不可用');
    return {
      original: text,
      translated: '',
      fromLang: from,
      toLang: to,
      success: false,
      error: lastError || '翻译服务不可用'
    };
  }
  
  /**
   * 使用指定实例进行翻译
   */
  private async translateWithInstance(
    instance: string, 
    text: string, 
    from: string, 
    to: string
  ): Promise<TranslateResult> {
    // URL 编码文本
    const encodedText = encodeURIComponent(text);
    const url = instance + '/api/v1/' + from + '/' + to + '/' + encodedText;
    
    console.info('[Lingva] 请求URL: ' + url);
    
    // 创建 HTTP 请求
    const httpRequest = http.createHttp();
    
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': 'Mozilla/5.0 (HarmonyOS) SherpaOnnxVadAsr',
          'Accept': 'application/json',
          'Accept-Language': 'en-US,en;q=0.9',
        },
        connectTimeout: this.timeout,
        readTimeout: this.timeout,
      });
      
      console.info('[Lingva] 响应状态码: ' + response.responseCode);
      console.info('[Lingva] 响应头: ' + JSON.stringify(response.header));
      
      // 检查响应状态
      if (response.responseCode !== 200) {
        const error_msg = 'HTTP错误: ' + response.responseCode;
        console.error('[Lingva] ' + error_msg);
        throw new Error(error_msg);
      }
      
      // 解析响应
      if (!response.result) {
        console.error('[Lingva] 响应体为空');
        throw new Error('响应体为空');
      }
      
      // 获取响应字符串
      let resultStr: string;
      if (typeof response.result === 'string') {
        resultStr = response.result;
      } else {
        resultStr = JSON.stringify(response.result);
      }
      
      console.info('[Lingva] 响应内容: ' + resultStr.substring(0, 200));
      
      // 解析 JSON
      const json: LingvaResponse = JSON.parse(resultStr) as LingvaResponse;
      const translation = json.translation;
      
      if (!translation) {
        console.error('[Lingva] 翻译结果为空');
        throw new Error('翻译结果为空');
      }
      
      console.info('[Lingva] 翻译成功: "' + text.substring(0, 30) + '" -> "' + translation.substring(0, 30) + '"');
      
      return {
        original: text,
        translated: translation,
        fromLang: from,
        toLang: to,
        success: true
      };
      
    } catch (error) {
      const errorMsg = error instanceof Error ? error.message : String(error);
      console.error('[Lingva] 请求异常: ' + errorMsg);
      throw new Error(errorMsg);
    } finally {
      // 销毁 HTTP 请求对象
      httpRequest.destroy();
    }
  }
  
  /**
   * 获取语言显示名称
   */
  static getLanguageDisplayName(code: string): string {
    const lang = LingvaTranslator.LANGUAGES.find(l => l.code === code);
    return lang ? (lang.flag + ' ' + lang.name) : code;
  }
  
  /**
   * 批量翻译多个文本段
   * @param texts 文本数组
   * @param to 目标语言
   * @param from 源语言
   * @returns 翻译结果数组
   */
  async translateBatch(texts: string[], to: string, from: string = 'auto'): Promise<TranslateResult[]> {
    const results: TranslateResult[] = [];
    
    for (const text of texts) {
      const result = await this.translate(text, to, from);
      results.push(result);
      
      // 添加小延迟避免请求过快
      await new Promise<void>(resolve => setTimeout(resolve, 300));
    }
    
    return results;
  }
}

// 导出单例实例
export const translator = new LingvaTranslator();
