import { Breakpoint } from '../common/BreakpointConstants';

/**
 * 侧边垂直导航栏（平板/PC 使用）
 * md 断点：仅显示图标，宽度 60vp
 * lg 断点：显示图标+文字，宽度 180vp
 */

interface NavItemDef {
  icon: string;
  text: string;
  index: number;
}

@ComponentV2
export struct SideNav {
  @Param currentTab: number = 0;
  @Param breakpoint: Breakpoint = Breakpoint.SM;
  @Event onTabChange?: (index: number) => void;

  private navItems: NavItemDef[] = [
    { icon: '📋', text: '剪贴板', index: 0 },
    { icon: '📂', text: '分类管理', index: 1 },
    { icon: '⚙', text: '设置', index: 2 }
  ];

  build() {
    Column() {
      // App 标题（lg 时显示文字，md 时显示图标）
      if (this.breakpoint === Breakpoint.LG) {
        Text('Echo')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FF6B6B')
          .padding({ top: 20, bottom: 24 })
      } else {
        Text('📋')
          .fontSize(24)
          .padding({ top: 16, bottom: 20 })
      }

      // 导航项
      ForEach(this.navItems, (item: NavItemDef) => {
        this.buildNavItem(item)
      }, (item: NavItemDef): string => item.index.toString())

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder buildNavItem(item: NavItemDef) {
    Row() {
      Text(item.icon)
        .fontSize(20)

      if (this.breakpoint === Breakpoint.LG) {
        Text(item.text)
          .fontSize(14)
          .fontColor(this.currentTab === item.index ? '#FF6B6B' : '#666666')
          .fontWeight(this.currentTab === item.index ? FontWeight.Bold : FontWeight.Normal)
          .margin({ left: 10 })
      }
    }
    .width('100%')
    .height(48)
    .justifyContent(this.breakpoint === Breakpoint.MD ? FlexAlign.Center : FlexAlign.Start)
    .padding({ left: this.breakpoint === Breakpoint.LG ? 20 : 0 })
    .backgroundColor(this.currentTab === item.index ? '#FFF0F0' : Color.Transparent)
    .borderRadius(10)
    .margin({ left: 8, right: 8, bottom: 4 })
    .accessibilityText(item.text)
    .onClick(() => {
      if (this.onTabChange) {
        this.onTabChange(item.index);
      }
    })
  }
}
