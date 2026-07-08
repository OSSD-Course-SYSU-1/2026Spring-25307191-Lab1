import { BreakpointUtil, Breakpoint } from '../utils/BreakpointUtil';
import { LingvaTranslator, LanguageOption } from '../../utils/LingvaTranslator';

/**
 * 响应式语言选择器组件
 * 根据断点自动调整布局和尺寸
 */
@Component
export struct AdaptiveLanguageSelector {
  @Prop breakpoint: string = Breakpoint.SM;
  @Link targetLang: string;
  @Prop onSelect?: (lang: string) => void;

  private languageOptions: LanguageOption[] = LingvaTranslator.LANGUAGES;

  build() {
    Column() {
      Row() {
        Text('翻译为: ')
          .fontSize(this.getLabelFontSize())
          .fontColor('#666666');

        Select(this.languageOptions.map(l => ({ value: l.flag + ' ' + l.name } as SelectOption)))
          .selected(this.languageOptions.findIndex(l => l.code === this.targetLang))
          .value(LingvaTranslator.getLanguageDisplayName(this.targetLang))
          .font({ size: this.getSelectFontSize() })
          .fontColor('#333333')
          .selectedOptionFont({ size: this.getSelectFontSize() })
          .optionFont({ size: this.getSelectFontSize() })
          .onSelect((index: number) => {
            this.targetLang = this.languageOptions[index].code;
            console.log('选择目标语言: ' + this.targetLang);
            if (this.onSelect) {
              this.onSelect(this.targetLang);
            }
          })
          .width(this.getSelectWidth())
          .height(this.getSelectHeight());
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: this.getPadding(), right: this.getPadding() });
    }
    .width('100%')
    .margin({ top: 8, bottom: 8 });
  }

  private getLabelFontSize(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 12,
      [Breakpoint.SM]: 14,
      [Breakpoint.MD]: 14,
      [Breakpoint.LG]: 16,
      [Breakpoint.XL]: 16
    });
  }

  private getSelectFontSize(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 12,
      [Breakpoint.SM]: 14,
      [Breakpoint.MD]: 14,
      [Breakpoint.LG]: 16,
      [Breakpoint.XL]: 16
    });
  }

  private getSelectWidth(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 140,
      [Breakpoint.SM]: 180,
      [Breakpoint.MD]: 200,
      [Breakpoint.LG]: 220,
      [Breakpoint.XL]: 240
    });
  }

  private getSelectHeight(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 30,
      [Breakpoint.SM]: 35,
      [Breakpoint.MD]: 36,
      [Breakpoint.LG]: 40,
      [Breakpoint.XL]: 44
    });
  }

  private getPadding(): number {
    return BreakpointUtil.getValue(this.breakpoint, {
      [Breakpoint.XS]: 8,
      [Breakpoint.SM]: 16,
      [Breakpoint.MD]: 20,
      [Breakpoint.LG]: 24,
      [Breakpoint.XL]: 28
    });
  }
}
