import { ClipboardViewModel } from '../viewmodel/ClipboardViewModel';
import { CategoryViewModel } from '../viewmodel/CategoryViewModel';
import { ClipItem } from '../model/ClipItem';
import { CategoryItem } from '../model/CategoryItem';
import { SearchBar } from '../component/SearchBar';
import { ClipCard } from '../component/ClipCard';

/**
 * 剪贴板页面 — 首页时间线
 * 显示所有剪贴内容的卡片列表，支持搜索、分类筛选、置顶、删除
 */

@ComponentV2
export struct ClipboardPage {
  @Require @Param vm: ClipboardViewModel;
  @Require @Param categoryVM: CategoryViewModel;
  @Local private showActionSheet: boolean = false;
  @Local private selectedClip: ClipItem | null = null;
  @Local private showMoveDialog: boolean = false;
  @Local private copyToast: string = '';

  aboutToAppear(): void {
    // 页面初始化由父组件完成
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 搜索栏
        Row() {
          SearchBar({
            placeholder: '搜索剪贴内容...',
            onChange: (value: string) => { this.vm.onSearch(value); }
          })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 8, bottom: 4 })

        // 分类筛选横滑标签
        this.buildCategoryFilter()

        // 内容列表 — Scroll + Column，避免 List 回收导致的翻页/消失问题
        if (this.vm.clips.length === 0) {
          this.buildEmptyState()
        } else {
          Scroll() {
            Column() {
              ForEach(this.vm.clips, (clip: ClipItem) => {
                ClipCard({
                  clipItem: clip,
                  categoryName: this.getCategoryName(clip.categoryId),
                  categoryColor: this.getCategoryColor(clip.categoryId),
                  onCopy: (item: ClipItem): void => { this.handleCopy(item); }
                })
                .gesture(
                  LongPressGesture()
                    .onAction(() => {
                      this.selectedClip = clip;
                      this.showActionSheet = true;
                    })
                )
              }, (clip: ClipItem): string => {
                return clip.id.toString();
              })
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
          }
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8F8F8')

      // 复制成功提示
      if (this.copyToast.length > 0) {
        Text(this.copyToast)
          .fontSize(13)
          .fontColor(Color.White)
          .padding({ left: 20, right: 20, top: 10, bottom: 10 })
          .borderRadius(20)
          .backgroundColor('#FF6B6B')
          .margin({ bottom: 40 })
      }

      // 长按操作面板
      if (this.showActionSheet && this.selectedClip) {
        this.buildActionSheet()
      }

      // 移动到分类弹窗
      if (this.showMoveDialog && this.selectedClip) {
        this.buildMoveDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  // ==================== 私有的构建器 ====================

  @Builder buildCategoryFilter() {
    Row() {
      Scroll() {
        Row() {
          ForEach(this.getFilterCategories(), (cat: CategoryItem | null, index: number) => {
            if (index > 0) { Blank().width(8); }
            Text(cat ? cat.name : '全部')
              .fontSize(12)
              .fontWeight(this.isFilterActive(cat) ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.isFilterActive(cat) ? Color.White : '#666666')
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .borderRadius(16)
              .backgroundColor(this.isFilterActive(cat)
                ? (cat ? cat.color : '#FF6B6B')
                : '#EEEEEE')
              .onClick(() => {
                this.vm.onFilterCategory(cat ? cat.id : 0);
              })
          })
        }
        .padding({ left: 14, right: 14 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .height(44)
    .margin({ bottom: 8 })
  }

  @Builder buildEmptyState() {
    Column() {
      Text('📋').fontSize(48).margin({ bottom: 12 })
      Text('还没有剪贴记录')
        .fontSize(16)
        .fontColor('#999999')
        .margin({ bottom: 4 })
      Text('复制一些文字或图片开始使用吧')
        .fontSize(13)
        .fontColor('#BBBBBB')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder buildActionSheet() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .layoutWeight(1)
        .onClick(() => { this.showActionSheet = false; })

      // 操作面板
      Column() {
        Row() {
          Text(this.selectedClip?.isPinned ? '📌 取消置顶' : '📌 置顶')
            .fontSize(16)
            .fontColor('#333333')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.selectedClip) {
            this.vm.togglePin(this.selectedClip);
          }
          this.showActionSheet = false;
        })

        Divider().height(1).color('#F0F0F0').width('100%')

        Row() {
          Text('📂 移动到...')
            .fontSize(16)
            .fontColor('#333333')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showActionSheet = false;
          this.showMoveDialog = true;
        })

        Divider().height(1).color('#F0F0F0').width('100%')

        Row() {
          Text('🗑 删除')
            .fontSize(16)
            .fontColor('#FF4444')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.selectedClip) {
            this.vm.deleteClip(this.selectedClip.id);
          }
          this.showActionSheet = false;
        })

        Divider().height(6).color('#F0F0F0').width('100%')

        Row() {
          Text('取消')
            .fontSize(16)
            .fontColor('#999999')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.showActionSheet = false; })
      }
      .width('100%')
      .backgroundColor(Color.White)
      .borderRadius({ topLeft: 16, topRight: 16 })
      .padding({ bottom: 20 })
    }
    .width('100%')
    .height('100%')
  }

  // 分类选择弹窗
  @Builder buildMoveDialog() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0,0,0,0.4)')
        .onClick(() => { this.showMoveDialog = false; })

      Column()
        .width('1%')
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)

    Column() {
      Text('移动到分类')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 16, bottom: 12 })

      ForEach(this.categoryVM.categories, (cat: CategoryItem) => {
        Row() {
          Text('●')
            .fontSize(14)
            .fontColor(cat.color)
            .margin({ right: 10 })
          Text(cat.name)
            .fontSize(15)
            .fontColor('#333333')
        }
        .width('100%')
        .height(44)
        .padding({ left: 20 })
        .onClick(() => {
          if (this.selectedClip) {
            this.vm.moveToCategory(this.selectedClip.id, cat.id);
          }
          this.showMoveDialog = false;
        })
      })

      Divider().height(8).color('#F0F0F0').width('100%')

      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor('#999999')
      }
      .width('100%')
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => { this.showMoveDialog = false; })
    }
    .width('80%')
    .backgroundColor(Color.White)
    .borderRadius(14)
    .padding({ bottom: 8 })
  }

  // ==================== 辅助方法 ====================

  private getFilterCategories(): (CategoryItem | null)[] {
    const list: (CategoryItem | null)[] = [null]; // null = 全部
    return list.concat(this.categoryVM.categories);
  }

  private isFilterActive(cat: CategoryItem | null): boolean {
    if (!cat) return this.vm.selectedCategoryId === 0;
    return this.vm.selectedCategoryId === cat.id;
  }

  private getCategoryName(categoryId: number): string {
    const cat = this.categoryVM.getCategoryById(categoryId);
    return cat ? cat.name : '';
  }

  private getCategoryColor(categoryId: number): string {
    const cat = this.categoryVM.getCategoryById(categoryId);
    return cat ? cat.color : '#FF6B6B';
  }

  private async handleCopy(clip: ClipItem): Promise<void> {
    await this.vm.copyToClipboard(clip);
    this.copyToast = '已复制!';
    setTimeout(() => { this.copyToast = ''; }, 1500);
  }

  private handleDelete(clip: ClipItem): void {
    this.vm.deleteClip(clip.id);
  }
}
