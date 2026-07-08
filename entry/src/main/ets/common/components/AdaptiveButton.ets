import { BreakpointUtil, Breakpoint } from '../utils/BreakpointUtil';
import { DeviceUtil } from '../utils/DeviceUtil';

/**
 * 响应式按钮组件
 * 根据断点自动调整尺寸和字体大小
 */
@Component
export struct AdaptiveButton {
  @Prop text: string = '';
  @Prop breakpoint: string = Breakpoint.SM;
  @Prop enabled: boolean = true;
  @Prop backgroundColor: string = '#28bff1';
  @Prop onClick?: () => void;

  build() {
    Button(this.text)
      .enabled(this.enabled)
      .fontSize(this.getButtonFontSize())
      .width(this.getButtonWidth())
      .height(this.getButtonHeight())
      .backgroundColor(this.enabled ? this.backgroundColor : '#CCCCCC')
      .borderRadius(this.getButtonRadius())
      .focusable(DeviceUtil.isCarDevice())
      .onClick(() => {
        if (this.onClick) {
          this.onClick();
        }
      })
  }

  private getButtonFontSize(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 12,
      [Breakpoint.SM]: 13,
      [Breakpoint.MD]: 14,
      [Breakpoint.LG]: 16,
      [Breakpoint.XL]: 18
    });
  }

  private getButtonWidth(): string | number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: '80%',
      [Breakpoint.SM]: 296,
      [Breakpoint.MD]: 320,
      [Breakpoint.LG]: 360,
      [Breakpoint.XL]: 400
    });
  }

  private getButtonHeight(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 40,
      [Breakpoint.SM]: 60,
      [Breakpoint.MD]: 56,
      [Breakpoint.LG]: 52,
      [Breakpoint.XL]: 56
    });
  }

  private getButtonRadius(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 8,
      [Breakpoint.SM]: 12,
      [Breakpoint.MD]: 12,
      [Breakpoint.LG]: 16,
      [Breakpoint.XL]: 16
    });
  }
}
