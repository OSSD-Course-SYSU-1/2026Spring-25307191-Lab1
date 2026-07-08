import { BreakpointUtil, Breakpoint } from '../utils/BreakpointUtil';
import { LengthUnit } from '@kit.ArkUI';

/**
 * 响应式文本区域组件
 * 根据断点自动调整高度和字体大小
 */
@Component
export struct AdaptiveTextArea {
  @Prop text: string = '';
  @Prop breakpoint: string = Breakpoint.SM;
  @Prop placeholder: string = '';
  @Prop enabled: boolean = false;
  @Prop showTranslation: boolean = false;
  @Prop maxHeight: number = 250;

  build() {
    TextArea({ text: this.text, placeholder: this.placeholder })
      .width('100%')
      .height(this.getTextAreaHeight())
      .fontSize(this.getFontSize())
      .lineSpacing({ value: this.getLineSpacing(), unit: LengthUnit.VP })
      .fontColor(this.enabled ? '#333333' : '#666666')
      .enabled(this.enabled)
      .borderRadius(this.getBorderRadius())
  }

  private getTextAreaHeight(): number {
    const baseHeight = BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 120,
      [Breakpoint.SM]: this.showTranslation ? 150 : this.maxHeight,
      [Breakpoint.MD]: this.showTranslation ? 160 : this.maxHeight,
      [Breakpoint.LG]: this.showTranslation ? 180 : this.maxHeight,
      [Breakpoint.XL]: this.showTranslation ? 200 : this.maxHeight
    });
    return Math.min(baseHeight, this.maxHeight);
  }

  private getFontSize(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 12,
      [Breakpoint.SM]: 14,
      [Breakpoint.MD]: 15,
      [Breakpoint.LG]: 16,
      [Breakpoint.XL]: 18
    });
  }

  private getLineSpacing(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 6,
      [Breakpoint.SM]: 10,
      [Breakpoint.MD]: 10,
      [Breakpoint.LG]: 12,
      [Breakpoint.XL]: 14
    });
  }

  private getBorderRadius(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 8,
      [Breakpoint.SM]: 12,
      [Breakpoint.MD]: 12,
      [Breakpoint.LG]: 16,
      [Breakpoint.XL]: 16
    });
  }
}
