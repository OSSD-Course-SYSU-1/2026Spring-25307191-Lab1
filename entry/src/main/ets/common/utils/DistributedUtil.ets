import { distributedDeviceManager } from '@kit.DistributedServiceKit';
import { Want, common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';

/**
 * 应用接续状态接口
 * 定义需要在设备间传递的状态数据
 */
export interface ContinueState {
  /** 当前Tab索引 */
  currentTabIndex?: number;
  /** 当前断点 */
  currentBreakpoint?: string;
  /** 源设备类型 */
  sourceDeviceType?: string;
  /** 识别结果 */
  recognitionResult?: string;
}

/**
 * 设备信息接口
 */
export interface DeviceInfo {
  deviceId: string;
  deviceName: string;
  deviceType?: string;
}

/**
 * 分布式流转管理器
 * 提供设备发现、应用接续（流转）、状态恢复能力
 */
export class DistributedUtil {
  private static instance: DistributedUtil;
  private deviceManager: distributedDeviceManager.DeviceManager | null = null;

  static getInstance(): DistributedUtil {
    if (!DistributedUtil.instance) {
      DistributedUtil.instance = new DistributedUtil();
    }
    return DistributedUtil.instance;
  }

  /**
   * 初始化设备管理器
   */
  private initDeviceManager(): void {
    if (this.deviceManager === null) {
      try {
        this.deviceManager = distributedDeviceManager.createDeviceManager('com.example.sherpaonnxvadasr');
      } catch (e) {
        console.error('初始化设备管理器失败:', e);
      }
    }
  }

  /**
   * 获取可流转设备列表
   * @returns 设备列表，包含deviceId和deviceName
   */
  async getAvailableDevices(): Promise<DeviceInfo[]> {
    this.initDeviceManager();
    if (this.deviceManager === null) {
      return [];
    }
    
    try {
      const devices: distributedDeviceManager.DeviceBasicInfo[] = this.deviceManager.getAvailableDeviceListSync();
      const result: DeviceInfo[] = [];
      
      for (let i = 0; i < devices.length; i++) {
        const device = devices[i];
        const info: DeviceInfo = {
          deviceId: device.deviceId,
          deviceName: device.deviceName,
          deviceType: device.deviceType
        };
        result.push(info);
      }
      
      return result;
    } catch (error) {
      console.error('获取可流转设备列表失败:', error);
      return [];
    }
  }

  /**
   * 发起应用接续（流转）到目标设备
   * @param targetDeviceId 目标设备ID
   * @param state 需要传递的应用状态
   */
  async continueAbility(targetDeviceId: string, state: ContinueState): Promise<void> {
    // 构造参数对象，避免使用展开运算符
    const params: Record<string, Object> = {
      'currentTabIndex': state.currentTabIndex !== undefined ? state.currentTabIndex : 0,
      'currentBreakpoint': state.currentBreakpoint !== undefined ? state.currentBreakpoint : '',
      'sourceDeviceType': deviceInfo.deviceType,
      'recognitionResult': state.recognitionResult !== undefined ? state.recognitionResult : ''
    };

    const want: Want = {
      deviceId: targetDeviceId,
      bundleName: 'com.example.sherpaonnxvadasr',
      abilityName: 'EntryAbility',
      parameters: params
    };

    try {
      const context = getContext(this) as common.UIAbilityContext;
      // 使用startAbility替代continueAbility进行跨设备启动
      await context.startAbility(want);
      console.info('应用接续成功，目标设备:', targetDeviceId);
    } catch (error) {
      console.error('应用接续失败:', error);
      throw new Error('应用接续失败: ' + String(error));
    }
  }

  /**
   * 接收流转状态（在目标设备的EntryAbility中调用）
   * @param want 启动参数
   * @returns 解析后的状态对象，如非流转启动则返回null
   */
  onContinue(want: Want): ContinueState | null {
    const params = want.parameters;
    if (params === null || params === undefined) {
      return null;
    }
    
    const tabIndex = params['currentTabIndex'];
    if (tabIndex === undefined) {
      return null;
    }

    const result: ContinueState = {
      currentTabIndex: tabIndex as number,
      currentBreakpoint: params['currentBreakpoint'] as string,
      sourceDeviceType: params['sourceDeviceType'] as string,
      recognitionResult: params['recognitionResult'] as string
    };
    
    return result;
  }

  /**
   * 查找指定类型的设备
   * @param deviceType 设备类型，如 'phone', 'tablet', 'car'
   */
  async findDeviceByType(deviceType: string): Promise<DeviceInfo | null> {
    const devices = await this.getAvailableDevices();
    for (let i = 0; i < devices.length; i++) {
      const d = devices[i];
      if (d.deviceType === deviceType || d.deviceName.includes(deviceType)) {
        return d;
      }
    }
    return null;
  }
}
