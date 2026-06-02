import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
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

          // 右侧内容区 — 用 Stack + visibility 保活全部页面，避免条件渲染丢失 @Local 状态
          Stack() {
            ClipboardPage({
              vm: this.clipboardVM,
              categoryVM: this.categoryVM,
              breakpoint: this.currentBreakpoint
            })
            .visibility(this.currentTab === 0 ? Visibility.Visible : Visibility.Hidden)

            CategoryPage({
              vm: this.categoryVM,
              breakpoint: this.currentBreakpoint
            })
            .visibility(this.currentTab === 1 ? Visibility.Visible : Visibility.Hidden)

            SettingsPage({
              vm: this.clipboardVM,
              breakpoint: this.currentBreakpoint
            })
            .visibility(this.currentTab === 2 ? Visibility.Visible : Visibility.Hidden)
          }
          .layoutWeight(1)
          .height('100%')
        }
        .width('100%')
        .height('100%')
      } else {
        // ============================================================
        // 手机：底部 Tab 导航（保持原有布局）
        // ============================================================
        Tabs({ index: this.currentTab }) {
          TabContent() {
            this.buildContentPage(0)
          }
          .tabBar(this.tabLabel('📋', '剪贴板'))

          TabContent() {
            this.buildContentPage(1)
          }
          .tabBar(this.tabLabel('📂', '分类'))

          TabContent() {
            this.buildContentPage(2)
          }
          .tabBar(this.tabLabel('⚙', '设置'))
        }
        .barPosition(BarPosition.End)
        .scrollable(false)
        .onChange((index: number) => {
          this.currentTab = index;
          if (index === 0) {
            this.reloadIfNeeded();
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

  // ==================== 构建器 ====================

  @Builder tabLabel(icon: string, text: string) {
    Column() {
      Text(icon).fontSize(20);
      Text(text).fontSize(10).margin({ top: 2 });
    }
    .padding({ top: 6, bottom: 4 });
  }

  /**
   * 侧边导航模式下的内容区（根据 currentTab 切换页面）
   */
  @Builder buildContentArea() {
    if (this.currentTab === 0) {
      ClipboardPage({
        vm: this.clipboardVM,
        categoryVM: this.categoryVM,
        breakpoint: this.currentBreakpoint
      })
    } else if (this.currentTab === 1) {
      CategoryPage({
        vm: this.categoryVM,
        breakpoint: this.currentBreakpoint
      })
    } else {
      SettingsPage({
        vm: this.clipboardVM,
        breakpoint: this.currentBreakpoint
      })
    }
  }

  /**
   * 底部 Tab 模式下的页面构建（供 TabContent 使用）
   */
  @Builder buildContentPage(tabIndex: number) {
    if (tabIndex === 0) {
      ClipboardPage({
        vm: this.clipboardVM,
        categoryVM: this.categoryVM,
        breakpoint: this.currentBreakpoint
      })
    } else if (tabIndex === 1) {
      CategoryPage({
        vm: this.categoryVM,
        breakpoint: this.currentBreakpoint
      })
    } else {
      SettingsPage({
        vm: this.clipboardVM,
        breakpoint: this.currentBreakpoint
      })
    }
  }

  private reloadIfNeeded(): void {
    this.clipboardVM.cleanExpired();
  }
}
