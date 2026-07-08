/**
 * 断点枚举
 * 对应官方标准断点：xs(0-320), sm(320-600), md(600-840), lg(840-1440), xl(1440+)
 */
export enum Breakpoint {
  XS = 'xs',
  SM = 'sm',
  MD = 'md',
  LG = 'lg',
  XL = 'xl'
}

/**
 * 栅格列数配置接口
 */
interface ColumnsConfig {
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
}

/**
 * 卡片列数配置接口
 */
interface CardColumnsConfig {
  xs: number;
  sm: number;
  md: number;
  lg: number;
  xl: number;
}

/**
 * 断点工具类
 * 提供断点判断、响应式值获取、列数配置等核心能力
 */
export class BreakpointUtil {
  // 标准断点阈值（vp）
  static readonly BREAKPOINTS: string[] = ['320vp', '600vp', '840vp', '1440vp'];

  // 各断点对应的栅格列数
  static readonly COLUMNS: ColumnsConfig = {
    xs: 4,   // 手表
    sm: 4,   // 手机
    md: 8,   // 折叠屏
    lg: 12,  // 平板
    xl: 12   // 车机/PC
  };

  // 各断点对应的每行显示卡片数
  static readonly CARD_COLUMNS: CardColumnsConfig = {
    xs: 1,  // 手表单列
    sm: 1,  // 手机单列
    md: 2,  // 折叠屏双列
    lg: 3,  // 平板三列
    xl: 4   // 车机四列
  };

  /**
   * 根据断点获取对应值
   * @param breakpoint 当前断点字符串
   * @param values 各断点对应的值映射
   * @returns 当前断点对应的值，如不存在则返回sm默认值
   */
  static getValue<T>(breakpoint: string, values: Record<Breakpoint, T>): T {
    return values[breakpoint as Breakpoint] ?? values[Breakpoint.SM];
  }

  /**
   * 判断是否为紧凑设备（手机/手表）
   */
  static isCompact(breakpoint: string): boolean {
    return breakpoint === Breakpoint.XS || breakpoint === Breakpoint.SM;
  }

  /**
   * 判断是否为中等设备（折叠屏/小平板）
   */
  static isMedium(breakpoint: string): boolean {
    return breakpoint === Breakpoint.MD;
  }

  /**
   * 判断是否为大屏设备（平板/车机/PC）
   */
  static isExpanded(breakpoint: string): boolean {
    return breakpoint === Breakpoint.LG || breakpoint === Breakpoint.XL;
  }

  /**
   * 获取当前断点对应的卡片跨度（GridCol span）
   */
  static getCardSpan(breakpoint: string): number {
    let totalCols: number = 4;
    let cardCols: number = 1;
    
    // 使用switch语句避免索引访问
    switch (breakpoint) {
      case Breakpoint.XS:
        totalCols = BreakpointUtil.COLUMNS.xs;
        cardCols = BreakpointUtil.CARD_COLUMNS.xs;
        break;
      case Breakpoint.SM:
        totalCols = BreakpointUtil.COLUMNS.sm;
        cardCols = BreakpointUtil.CARD_COLUMNS.sm;
        break;
      case Breakpoint.MD:
        totalCols = BreakpointUtil.COLUMNS.md;
        cardCols = BreakpointUtil.CARD_COLUMNS.md;
        break;
      case Breakpoint.LG:
        totalCols = BreakpointUtil.COLUMNS.lg;
        cardCols = BreakpointUtil.CARD_COLUMNS.lg;
        break;
      case Breakpoint.XL:
        totalCols = BreakpointUtil.COLUMNS.xl;
        cardCols = BreakpointUtil.CARD_COLUMNS.xl;
        break;
      default:
        totalCols = 4;
        cardCols = 1;
        break;
    }
    
    return Math.floor(totalCols / cardCols);
  }

  /**
   * 根据窗口宽度计算断点
   */
  static calcBreakpoint(widthVp: number): string {
    if (widthVp < 320) return Breakpoint.XS;
    if (widthVp < 600) return Breakpoint.SM;
    if (widthVp < 840) return Breakpoint.MD;
    if (widthVp < 1440) return Breakpoint.LG;
    return Breakpoint.XL;
  }
}
