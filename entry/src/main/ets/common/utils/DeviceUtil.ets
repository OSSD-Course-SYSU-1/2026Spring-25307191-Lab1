import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';

/**
 * 设备类型枚举
 */
export enum DeviceType {
  PHONE = 'phone',
  TABLET = 'tablet',
  TWO_IN_ONE = '2in1',
  TV = 'tv',
  WEARABLE = 'wearable',
  CAR = 'car'
}

/**
 * 设备信息工具类
 * 提供设备类型、屏幕方向、密度等信息查询
 */
export class DeviceUtil {
  /**
   * 获取当前设备类型
   * 返回值：'phone', 'tablet', '2in1', 'tv', 'wearable', 'car'
   */
  static getDeviceType(): string {
    return deviceInfo.deviceType;
  }

  /**
   * 判断当前是否为横屏
   */
  static isLandscape(): boolean {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      return displayInfo.width > displayInfo.height;
    } catch (e) {
      console.error('获取屏幕方向失败:', e);
      return false;
    }
  }

  /**
   * 获取屏幕密度
   */
  static getDensity(): number {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      return displayInfo.densityPixels;
    } catch (e) {
      console.error('获取屏幕密度失败:', e);
      return 3.0; // 默认密度
    }
  }

  /**
   * 获取屏幕宽度（vp）
   */
  static getScreenWidthVp(): number {
    try {
      const displayInfo = display.getDefaultDisplaySync();
      return displayInfo.width / displayInfo.densityPixels;
    } catch (e) {
      console.error('获取屏幕宽度失败:', e);
      return 360;
    }
  }

  /**
   * 是否为车机或智慧屏设备
   */
  static isCarDevice(): boolean {
    const type: string = deviceInfo.deviceType;
    return type === 'car' || type === 'tv';
  }

  /**
   * 是否为穿戴设备
   */
  static isWearable(): boolean {
    return deviceInfo.deviceType === 'wearable';
  }

  /**
   * 是否为手机
   */
  static isPhone(): boolean {
    return deviceInfo.deviceType === 'phone';
  }

  /**
   * 是否为平板
   */
  static isTablet(): boolean {
    const type: string = deviceInfo.deviceType;
    return type === 'tablet' || type === '2in1';
  }
}
