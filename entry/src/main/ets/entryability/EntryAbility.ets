import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import hilog from '@ohos.hilog';
import UIAbility from '@ohos.app.ability.UIAbility';
import Want from '@ohos.app.ability.Want';
import window from '@ohos.window';
import distributedDeviceManager from '@ohos.distributedDeviceManager';

// 分布式流转数据接口
interface ContinueData {
  sourceText?: string;
  translatedText?: string;
  sourceLanguage?: string;
  targetLanguage?: string;
  isRecording?: boolean;
}

export default class EntryAbility extends UIAbility {
  // 存储流转数据
  private continueData: ContinueData = {};
  // 分布式设备管理器
  private deviceManager: distributedDeviceManager.DeviceManager | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    
    // 处理冷启动时的流转恢复
    if (launchParam.launchReason === AbilityConstant.LaunchReason.CONTINUATION) {
      hilog.info(0x0000, 'testTag', '%{public}s', 'Ability launched by continuation');
      this.handleContinueState(want);
    }
  }

  onDestroy(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
    
    // 释放分布式设备管理器
    if (this.deviceManager) {
      try {
        distributedDeviceManager.releaseDeviceManager(this.deviceManager);
        this.deviceManager = null;
      } catch (err) {
        hilog.error(0x0000, 'testTag', 'Failed to release device manager: %{public}s', JSON.stringify(err));
      }
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }

  // ========== 分布式流转相关方法 ==========

  /**
   * 处理应用接续（流转）状态恢复
   * @param want 包含流转数据的Want对象
   */
  private handleContinueState(want: Want): void {
    try {
      // 从want参数中获取流转数据
      const continueDataStr = want.parameters?.continueData as string;
      if (continueDataStr) {
        this.continueData = JSON.parse(continueDataStr) as ContinueData;
        hilog.info(0x0000, 'testTag', 'Continue data restored: %{public}s', JSON.stringify(this.continueData));
        
        // 将流转数据存储到全局AppStorage，供UI层使用
        if (this.continueData.sourceText) {
          AppStorage.setOrCreate('continueSourceText', this.continueData.sourceText);
        }
        if (this.continueData.translatedText) {
          AppStorage.setOrCreate('continueTranslatedText', this.continueData.translatedText);
        }
        if (this.continueData.sourceLanguage) {
          AppStorage.setOrCreate('continueSourceLanguage', this.continueData.sourceLanguage);
        }
        if (this.continueData.targetLanguage) {
          AppStorage.setOrCreate('continueTargetLanguage', this.continueData.targetLanguage);
        }
        if (this.continueData.isRecording !== undefined) {
          AppStorage.setOrCreate('continueIsRecording', this.continueData.isRecording);
        }
      }
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to handle continue state: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 应用接续（流转）回调 - 保存当前状态
   * 当应用发起流转时，系统会调用此方法获取需要迁移的数据
   */
  onContinue(wantParam: Record<string, Object>): AbilityConstant.OnContinueResult {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onContinue');
    
    try {
      // 从AppStorage获取当前应用状态
      const sourceText = AppStorage.get<string>('sourceText') ?? '';
      const translatedText = AppStorage.get<string>('translatedText') ?? '';
      const sourceLanguage = AppStorage.get<string>('sourceLanguage') ?? 'auto';
      const targetLanguage = AppStorage.get<string>('targetLanguage') ?? 'en';
      const isRecording = AppStorage.get<boolean>('isRecording') ?? false;

      // 构建流转数据
      const continueData: ContinueData = {
        sourceText,
        translatedText,
        sourceLanguage,
        targetLanguage,
        isRecording
      };

      // 将流转数据存入wantParam
      wantParam['continueData'] = JSON.stringify(continueData);
      
      hilog.info(0x0000, 'testTag', 'Continue data saved: %{public}s', JSON.stringify(continueData));
      return AbilityConstant.OnContinueResult.AGREE;
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to save continue data: %{public}s', JSON.stringify(err));
      return AbilityConstant.OnContinueResult.REJECT;
    }
  }

  /**
   * 新设备上接续完成回调
   * 当应用在新设备上完成接续后，系统会调用此方法
   */
  onContinueComplete(result: AbilityConstant.OnContinueResult): void {
    hilog.info(0x0000, 'testTag', 'Ability onContinueComplete, result: %{public}d', result);
    
    if (result === AbilityConstant.OnContinueResult.AGREE) {
      hilog.info(0x0000, 'testTag', '%{public}s', 'Continuation completed successfully');
    } else {
      hilog.error(0x0000, 'testTag', '%{public}s', 'Continuation failed');
    }
  }

  /**
   * 初始化分布式设备管理器
   * 用于发现和管理分布式设备
   */
  private initDeviceManager(): void {
    try {
      // 创建设备管理器
      this.deviceManager = distributedDeviceManager.createDeviceManager('SherpaOnnxVadAsr');
      hilog.info(0x0000, 'testTag', '%{public}s', 'Device manager initialized');
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to create device manager: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 获取可用的分布式设备列表
   * @returns 设备信息数组
   */
  getAvailableDevices(): distributedDeviceManager.DeviceBasicInfo[] {
    if (!this.deviceManager) {
      this.initDeviceManager();
    }
    
    try {
      if (this.deviceManager) {
        const devices = this.deviceManager.getAvailableDeviceListSync();
        hilog.info(0x0000, 'testTag', 'Available devices: %{public}d', devices.length);
        return devices;
      }
    } catch (err) {
      hilog.error(0x0000, 'testTag', 'Failed to get available devices: %{public}s', JSON.stringify(err));
    }
    
    return [];
  }
}
