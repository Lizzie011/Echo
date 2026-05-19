import { common } from '@kit.AbilityKit';
import { AppStorageV2 } from '@kit.ArkUI';
import { ClipboardViewModel } from '../viewmodel/ClipboardViewModel';
import { CategoryViewModel } from '../viewmodel/CategoryViewModel';
import { ClipboardPage } from './ClipboardPage';
import { CategoryPage } from './CategoryPage';
import { SettingsPage } from './SettingsPage';

/**
 * 应用主页面 — 底部Tab容器
 * 三个Tab页：剪贴板 / 分类管理 / 设置
 */

@Entry
@ComponentV2
struct Index {
  @Local private currentTab: number = 0;
  private context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
  private clipboardVM: ClipboardViewModel = new ClipboardViewModel();
  private categoryVM: CategoryViewModel = new CategoryViewModel();
  private isInitialized: boolean = false;

  async aboutToAppear(): Promise<void> {
    if (this.isInitialized) return;
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
    Tabs({ index: this.currentTab }) {
      // ========================================
      //  Tab 1: 剪贴板
      // ========================================
      TabContent() {
        ClipboardPage({ vm: this.clipboardVM, categoryVM: this.categoryVM })
      }
      .tabBar(this.tabLabel('📋', '剪贴板'))

      // ========================================
      //  Tab 2: 分类管理
      // ========================================
      TabContent() {
        CategoryPage({ vm: this.categoryVM })
      }
      .tabBar(this.tabLabel('📂', '分类'))

      // ========================================
      //  Tab 3: 设置
      // ========================================
      TabContent() {
        SettingsPage({ vm: this.clipboardVM })
      }
      .tabBar(this.tabLabel('⚙', '设置'))
    }
    .barPosition(BarPosition.End)
    .scrollable(false)
    .onChange((index: number) => {
      this.currentTab = index;
      if (index === 0) {
        // 回到剪贴板时刷新列表并清理过期数据
        this.reloadIfNeeded();
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

  private reloadIfNeeded(): void {
    this.clipboardVM.cleanExpired();
  }
}
