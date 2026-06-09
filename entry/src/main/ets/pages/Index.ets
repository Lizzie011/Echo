import { common } from '@kit.AbilityKit';
import { AppStorageV2, window, display } from '@kit.ArkUI';
import { ClipboardViewModel } from '../viewmodel/ClipboardViewModel';
import { CategoryViewModel } from '../viewmodel/CategoryViewModel';
import { ClipboardPage } from './ClipboardPage';
import { CategoryPage } from './CategoryPage';
import { SettingsPage } from './SettingsPage';
import { SideNav } from '../component/SideNav';
import { Breakpoint, calcBreakpoint, isWideLayout, sideNavWidth } from '../common/BreakpointConstants';

/**
 * 应用主页面 — 响应式导航容器
 * sm（手机竖屏）：底部 Tab 导航
 * md/lg（平板/PC）：左侧 SideNav 侧边导航 + 右侧内容区
 */

@Entry
@ComponentV2
struct Index {
  @Local private currentTab: number = 0;
  @Local private currentBreakpoint: Breakpoint = Breakpoint.SM;
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private clipboardVM: ClipboardViewModel = new ClipboardViewModel();
  private categoryVM: CategoryViewModel = new CategoryViewModel();
  private isInitialized: boolean = false;

  async aboutToAppear(): Promise<void> {
    if (this.isInitialized) {
      return;
    }
    this.isInitialized = true;
    // 主动获取窗口宽度初始化断点，避免首次渲染 SM→MD/LG 布局跳变
    // windowRect.width 返回物理像素(px)，需转换为 vp 再计算断点
    try {
      const windowStage: window.Window = await window.getLastWindow(this.context);
      const props: window.WindowProperties = windowStage.getWindowProperties();
      const pxW: number = props.windowRect.width;
      if (pxW > 0) {
        const density: number = display.getDefaultDisplaySync().densityPixels;
        const vpW: number = density > 0 ? pxW / density : pxW;
        this.currentBreakpoint = calcBreakpoint(vpW);
      }
    } catch (e) {
      // 获取窗口失败则保持默认 SM，后续由 onAreaChange 更新
    }
    try {
      await this.categoryVM.init(this.context);
      await this.clipboardVM.init(this.context);
    } catch (e) {
      console.error('Echo-Index', `Init failed: ${JSON.stringify(e)}`);
    }
  }

  onPageShow(): void {
    if (this.isInitialized) {
      this.clipboardVM.onForeground();
    }
  }

  build() {
    Column() {
      if (isWideLayout(this.currentBreakpoint)) {
        // ============================================================
        // 平板/PC：侧边导航布局
        // ============================================================
        Row() {
          // 左侧垂直导航栏
          SideNav({
            currentTab: this.currentTab,
            breakpoint: this.currentBreakpoint,
            onTabChange: (index: number): void => {
              this.currentTab = index;
              if (index === 0) {
                this.clipboardVM.cleanExpired();
              }
            }
          })
          .width(sideNavWidth(this.currentBreakpoint))
          .height('100%')

          // 分隔线
          Divider()
            .vertical(true)
            .height('100%')
            .width(1)
            .color('#F0F0F0')

          // 右侧内容区 — 条件渲染：ViewModels 保留在 Index，子组件通过 @Param 读取最新状态
          if (this.currentTab === 0) {
            ClipboardPage({
              vm: this.clipboardVM,
              categoryVM: this.categoryVM,
              breakpoint: this.currentBreakpoint
            })
            .layoutWeight(1)
            .height('100%')
          } else if (this.currentTab === 1) {
            CategoryPage({
              vm: this.categoryVM,
              breakpoint: this.currentBreakpoint
            })
            .layoutWeight(1)
            .height('100%')
          } else {
            SettingsPage({
              vm: this.clipboardVM,
              breakpoint: this.currentBreakpoint
            })
            .layoutWeight(1)
            .height('100%')
          }
        }
        .width('100%')
        .height('100%')
      } else {
        // ============================================================
        // 手机：底部 Tab 导航（保持原有布局）
        // ============================================================
        Tabs({ index: this.currentTab }) {
          TabContent() {
            ClipboardPage({
              vm: this.clipboardVM,
              categoryVM: this.categoryVM,
              breakpoint: this.currentBreakpoint
            })
          }
          .tabBar(this.tabLabel('📋', '剪贴板'))

          TabContent() {
            CategoryPage({
              vm: this.categoryVM,
              breakpoint: this.currentBreakpoint
            })
          }
          .tabBar(this.tabLabel('📂', '分类'))

          TabContent() {
            SettingsPage({
              vm: this.clipboardVM,
              breakpoint: this.currentBreakpoint
            })
          }
          .tabBar(this.tabLabel('⚙', '设置'))
        }
        .barPosition(BarPosition.End)
        .scrollable(false)
        .onChange((index: number) => {
          this.currentTab = index;
          if (index === 0) {
            this.clipboardVM.cleanExpired();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldValue: Area, newValue: Area) => {
      const w: number = newValue.width as number;
      if (w > 0) {
        this.currentBreakpoint = calcBreakpoint(w);
      }
    })
  }

  @Builder tabLabel(icon: string, text: string) {
    Column() {
      Text(icon).fontSize(20);
      Text(text).fontSize(10).margin({ top: 2 });
    }
    .padding({ top: 6, bottom: 4 });
  }
}
