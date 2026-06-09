import { ClipboardViewModel } from '../viewmodel/ClipboardViewModel';
import { CategoryViewModel } from '../viewmodel/CategoryViewModel';
import { ClipItem } from '../model/ClipItem';
import { CategoryItem } from '../model/CategoryItem';
import { SearchBar } from '../component/SearchBar';
import { ClipCard } from '../component/ClipCard';
import { Breakpoint, calcGridColumns } from '../common/BreakpointConstants';

/**
 * 剪贴板页面 — 首页时间线
 * 显示所有剪贴内容的卡片列表，支持搜索、分类筛选、置顶、删除
 * sm: 单列卡片，md: 双列网格，lg: 三列网格
 */

@ComponentV2
export struct ClipboardPage {
  @Require @Param vm: ClipboardViewModel;
  @Require @Param categoryVM: CategoryViewModel;
  @Param breakpoint: Breakpoint = Breakpoint.SM;
  @Local private showActionSheet: boolean = false;
  @Local private selectedClip: ClipItem | null = null;
  @Local private showMoveDialog: boolean = false;
  @Local private copyToast: string = '';
  @Local private hoveredClipId: number = -1;
  @Local private showPreview: boolean = false;
  @Local private previewClip: ClipItem | null = null;
  @Local private searchText: string = this.vm.searchKeyword;
  private toastTimer: number = -1;
  private lastTapTime: number = 0;
  private lastTapClipId: number = -1;
  private tapTimer: number = -1;

  aboutToAppear(): void {
    // 从 ViewModel 同步搜索状态，确保 Tab 切换后 SearchBar 显示正确
    this.searchText = this.vm.searchKeyword;
  }

  aboutToDisappear(): void {
    // 清理 toast 定时器，避免对已销毁组件写入 @Local
    if (this.toastTimer !== -1) {
      clearTimeout(this.toastTimer);
      this.toastTimer = -1;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 搜索栏
        Row() {
          SearchBar({
            placeholder: '搜索剪贴内容...',
            value: this.searchText,
            onChange: (value: string) => {
              this.searchText = value;
              this.vm.onSearch(value);
            }
          })
        }
        .width('100%')
        .padding({
          left: this.breakpoint === Breakpoint.SM ? 14 : 24,
          right: this.breakpoint === Breakpoint.SM ? 14 : 24,
          top: 8,
          bottom: 4
        })

        // 分类筛选横滑标签
        this.buildCategoryFilter()

        // 内容区域（内联布局，确保 @Trace 数据变化时 UI 正确刷新）
        if (this.vm.clips.length === 0) {
          this.buildEmptyState()
        } else if (this.breakpoint === Breakpoint.SM) {
          // 手机：单列列表
          Scroll() {
            Column() {
              ForEach(this.vm.clips, (clip: ClipItem) => {
                ClipCard({
                  clipItem: clip,
                  categoryName: this.getCategoryName(clip.categoryId),
                  categoryColor: this.getCategoryColor(clip.categoryId)
                })
                .onClick(() => { this.handleCopy(clip); })
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
        } else {
          // 平板/PC：多列网格（Flex wrap 自动换行，单层 ForEach）
          // LG(PC)：右键菜单 + 右侧预览面板；MD(平板)：长按菜单
          Row() {
            Scroll() {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                ForEach(this.vm.clips, (clip: ClipItem) => {
                  Column() {
                    ClipCard({
                      clipItem: clip,
                      categoryName: this.getCategoryName(clip.categoryId),
                      categoryColor: this.getCategoryColor(clip.categoryId),
                      isHovered: this.hoveredClipId === clip.id,
                      wideLayout: true
                    })
                    .bindContextMenu(this.buildClipContextMenu(clip),
                      this.breakpoint === Breakpoint.LG ? ResponseType.RightClick : ResponseType.LongPress)
                    .onHover((isHover: boolean) => {
                      if (isHover) {
                        this.hoveredClipId = clip.id;
                      } else if (this.hoveredClipId === clip.id) {
                        this.hoveredClipId = -1;
                      }
                    })
                  }
                  .width(this.getCardWidth())
                  .padding({ left: 3, right: 3 })
                  .onClick(() => {
                    if (this.breakpoint === Breakpoint.LG) {
                      const now: number = Date.now();
                      if (now - this.lastTapTime < 280 && this.lastTapClipId === clip.id) {
                        if (this.tapTimer !== -1) {
                          clearTimeout(this.tapTimer);
                          this.tapTimer = -1;
                        }
                        this.handlePreview(clip);
                        this.lastTapTime = 0;
                        return;
                      }
                      this.lastTapTime = now;
                      this.lastTapClipId = clip.id;
                      if (this.tapTimer !== -1) {
                        clearTimeout(this.tapTimer);
                      }
                      this.tapTimer = setTimeout(() => {
                        this.handleCopy(clip);
                        this.tapTimer = -1;
                      }, 280);
                    } else {
                      this.handleCopy(clip);
                    }
                  })
                }, (clip: ClipItem): string => {
                  return clip.id.toString();
                })
              }
              .width('100%')
              .padding({ left: 11, right: 11 })
            }
            .scrollable(ScrollDirection.Vertical)
            .scrollBar(BarState.Off)
            .layoutWeight(1)

            // LG 专属：右侧预览面板
            if (this.breakpoint === Breakpoint.LG && this.showPreview && this.previewClip) {
              Divider().vertical(true).height('100%').width(1).color('#F0F0F0')
              this.buildPreviewPanel()
            }
          }
          .width('100%')
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

      // 长按操作面板（sm 使用）
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
    .focusable(true)
    .onKeyEvent((event: KeyEvent): boolean => {
      return this.handleKeyEvent(event);
    })
  }

  // ---------- 键盘快捷键处理 ----------
  private handleKeyEvent(event: KeyEvent): boolean {
    const key: string = event.keyText;
    // Escape → 关闭弹窗/面板/预览
    if (key === 'Escape') {
      if (this.showPreview) {
        this.showPreview = false;
        this.previewClip = null;
        return true;
      }
      if (this.showActionSheet) {
        this.showActionSheet = false;
        return true;
      }
      if (this.showMoveDialog) {
        this.showMoveDialog = false;
        return true;
      }
      return false;
    }
    // Delete → 删除当前悬停的卡片
    if (key === 'Delete' && this.hoveredClipId >= 0) {
      this.vm.deleteClip(this.hoveredClipId);
      return true;
    }
    return false;
  }

  // ==================== 私有的构建器 ====================

  @Builder buildCategoryFilter() {
    Row() {
      Scroll() {
        Row() {
          ForEach(this.getFilterCategories(), (cat: CategoryItem | null, index: number) => {
            if (index > 0) {
              Blank().width(8);
            }
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
        .padding({
          left: this.breakpoint === Breakpoint.SM ? 14 : 24,
          right: this.breakpoint === Breakpoint.SM ? 14 : 24
        })
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

  // ---------- 右键/长按上下文菜单（平板/PC） ----------
  @Builder buildClipContextMenu(clip: ClipItem) {
    Menu() {
      MenuItem({
        content: clip.isPinned ? '📌 取消置顶' : '📌 置顶'
      })
        .onClick(() => {
          this.vm.togglePin(clip);
        })

      MenuItem({ content: '📂 移动到分类...' })
        .onClick(() => {
          this.selectedClip = clip;
          this.showMoveDialog = true;
        })

      MenuItem({ content: '🗑 删除' })
        .onClick(() => {
          this.vm.deleteClip(clip.id);
        })
    }
  }

  // ---------- LG 预览面板（PC 双击卡片） ----------
  @Builder buildPreviewPanel() {
    Column() {
      // 标题栏
      Row() {
        Text(this.previewClip!.type === 'image' ? '🖼 图片预览' : '📝 内容预览')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
        Text('✕')
          .fontSize(16)
          .fontColor('#999999')
          .padding(4)
          .onClick(() => {
            this.showPreview = false;
            this.previewClip = null;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 12, top: 16, bottom: 12 })

      Divider().height(1).color('#F0F0F0').width('100%')

      // 内容区
      Scroll() {
        Column() {
          if (this.previewClip!.type === 'image') {
            Image(this.previewClip!.content)
              .width('100%')
              .objectFit(ImageFit.Contain)
              .borderRadius(8)
              .margin({ bottom: 16 })
            Text(this.getImageFileName(this.previewClip!.content))
              .fontSize(12)
              .fontColor('#999999')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text(this.previewClip!.content)
              .fontSize(14)
              .fontColor('#333333')
              .lineHeight(22)
              .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Auto)
      .layoutWeight(1)

      Divider().height(1).color('#F0F0F0').width('100%')

      // 元信息
      Column() {
        if (this.previewClip!.categoryId > 0) {
          Row() {
            Text('📂 分类')
              .fontSize(12)
              .fontColor('#999999')
              .width(50)
            Text(this.getCategoryName(this.previewClip!.categoryId))
              .fontSize(12)
              .fontColor(Color.White)
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(8)
              .backgroundColor(this.getCategoryColor(this.previewClip!.categoryId))
          }
          .width('100%')
          .margin({ bottom: 6 })
        }
        Row() {
          Text('🕐 时间')
            .fontSize(12)
            .fontColor('#999999')
            .width(50)
          Text(this.formatTimestamp(this.previewClip!.createdAt))
            .fontSize(12)
            .fontColor('#666666')
        }
        .width('100%')
        .margin({ bottom: 6 })
        Row() {
          Text('📌 状态')
            .fontSize(12)
            .fontColor('#999999')
            .width(50)
          Text(this.previewClip!.isPinned ? '已置顶' : '未置顶')
            .fontSize(12)
            .fontColor(this.previewClip!.isPinned ? '#FF6B6B' : '#666666')
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Divider().height(1).color('#F0F0F0').width('100%')

      // 操作按钮
      Row() {
        Button() {
          Text('复制')
            .fontSize(13)
            .fontColor(Color.White)
        }
        .height(36)
        .layoutWeight(1)
        .backgroundColor('#FF6B6B')
        .borderRadius(8)
        .margin({ right: 6 })
        .onClick(() => {
          if (this.previewClip) {
            this.handleCopy(this.previewClip);
          }
        })

        Button() {
          Text(this.previewClip!.isPinned ? '取消置顶' : '置顶')
            .fontSize(13)
            .fontColor('#333333')
        }
        .height(36)
        .layoutWeight(1)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .margin({ right: 6 })
        .onClick(() => {
          if (this.previewClip) {
            this.vm.togglePin(this.previewClip);
            // 刷新 previewClip 引用
            const actual = this.getSelectedClipActual();
            if (actual) {
              this.previewClip = actual;
            }
          }
        })

        Button() {
          Text('删除')
            .fontSize(13)
            .fontColor('#FF4444')
        }
        .height(36)
        .layoutWeight(1)
        .backgroundColor('#FFF0F0')
        .borderRadius(8)
        .onClick(() => {
          if (this.previewClip) {
            const id: number = this.previewClip.id;
            this.vm.deleteClip(id);
            this.showPreview = false;
            this.previewClip = null;
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 16 })
    }
    .width(300)
    .height('100%')
    .backgroundColor(Color.White)
  }

  // ---------- 根据断点计算卡片宽度百分比 ----------
  private getCardWidth(): string {
    const cols: number = calcGridColumns(this.breakpoint);
    return cols === 2 ? '50%' : '33.33%';
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
          Text(this.getSelectedClipActual()?.isPinned ? '📌 取消置顶' : '📌 置顶')
            .fontSize(16)
            .fontColor('#333333')
        }
        .width('100%')
        .height(50)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          const clip: ClipItem | null = this.getSelectedClipActual();
          if (clip) {
            this.vm.togglePin(clip);
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
    Stack() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .onClick(() => { this.showMoveDialog = false; })

      // 弹窗内容
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
      .width(this.breakpoint === Breakpoint.SM ? '80%' : '420')
      .backgroundColor(Color.White)
      .borderRadius(14)
      .padding({ bottom: 8 })
    }
    .width('100%')
    .height('100%')
  }

  // ==================== 辅助方法 ====================

  private getFilterCategories(): (CategoryItem | null)[] {
    const list: (CategoryItem | null)[] = [null]; // null = 全部
    return list.concat(this.categoryVM.categories);
  }

  private isFilterActive(cat: CategoryItem | null): boolean {
    if (!cat) {
      return this.vm.selectedCategoryId === 0;
    }
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

  // 从当前 clips 数组通过 id 重新查找，防止 selectedClip 引用过期
  private getSelectedClipActual(): ClipItem | null {
    if (!this.selectedClip) return null;
    const id: number = this.selectedClip.id;
    for (const c of this.vm.clips) {
      if (c.id === id) return c;
    }
    return this.selectedClip;
  }

  private handlePreview(clip: ClipItem): void {
    this.previewClip = clip;
    this.showPreview = true;
  }

  private async handleCopy(clip: ClipItem): Promise<void> {
    await this.vm.copyToClipboard(clip);
    this.copyToast = '已复制!';
    if (this.toastTimer !== -1) {
      clearTimeout(this.toastTimer);
    }
    this.toastTimer = setTimeout(() => {
      this.copyToast = '';
      this.toastTimer = -1;
    }, 1500);
  }

  private handleDelete(clip: ClipItem): void {
    this.vm.deleteClip(clip.id);
  }

  private formatTimestamp(timestamp: number): string {
    const date: Date = new Date(timestamp);
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    const hour: string = date.getHours().toString().padStart(2, '0');
    const minute: string = date.getMinutes().toString().padStart(2, '0');
    return month + '-' + day + ' ' + hour + ':' + minute;
  }

  private getImageFileName(filePath: string): string {
    const lastSlash: number = filePath.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < filePath.length - 1) {
      return filePath.substring(lastSlash + 1);
    }
    return filePath;
  }
}
