import { CategoryViewModel } from '../viewmodel/CategoryViewModel';
import { CategoryItem } from '../model/CategoryItem';
import { CATEGORY_COLORS } from '../constant/CommonConstants';
import { Breakpoint } from '../common/BreakpointConstants';

/**
 * 分类管理页面
 * 创建、重命名、删除分类
 * sm: 单列全宽行，md/lg: 双列卡片网格
 */

@ComponentV2
export struct CategoryPage {
  @Require @Param vm: CategoryViewModel;
  @Param breakpoint: Breakpoint = Breakpoint.SM;
  @Local private showAddDialog: boolean = false;
  @Local private showEditDialog: boolean = false;
  @Local private showDeleteDialog: boolean = false;
  @Local private editingCategory: CategoryItem | null = null;
  @Local private inputName: string = '';
  @Local private selectedColor: string = CATEGORY_COLORS[0];

  build() {
    Stack() {
      Column() {
        // 标题行
        Row() {
          Text('分类管理')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          Blank()
          Text('＋ 新建分类')
            .fontSize(13)
            .fontColor('#FF6B6B')
            .fontWeight(FontWeight.Medium)
            .onClick(() => {
              this.inputName = '';
              this.selectedColor = this.vm.getDefaultColor();
              this.showAddDialog = true;
            })
        }
        .width('100%')
        .padding({
          left: this.breakpoint === Breakpoint.SM ? 18 : 24,
          right: this.breakpoint === Breakpoint.SM ? 18 : 24,
          top: 16,
          bottom: 12
        })

        // 分类列表（内联布局，确保 @Trace 数据变化时 UI 正确刷新）
        if (this.vm.categories.length === 0) {
          this.buildEmptyView()
        } else if (this.breakpoint === Breakpoint.SM) {
          // 手机：单列行
          Scroll() {
            Column() {
              ForEach(this.vm.categories, (cat: CategoryItem) => {
                Row() {
                  Text('●')
                    .fontSize(24)
                    .fontColor(cat.color)
                    .margin({ right: 12 })

                  Text(cat.name)
                    .fontSize(15)
                    .fontColor('#333333')
                    .layoutWeight(1)

                  if (cat.name !== '默认') {
                    Text('✎')
                      .fontSize(16)
                      .fontColor('#999999')
                      .padding(8)
                      .onClick(() => {
                        this.editingCategory = cat;
                        this.inputName = cat.name;
                        this.selectedColor = cat.color;
                        this.showEditDialog = true;
                      })

                    Text('🗑')
                      .fontSize(16)
                      .fontColor('#CCCCCC')
                      .padding(8)
                      .onClick(() => {
                        this.editingCategory = cat;
                        this.showDeleteDialog = true;
                      })
                  }
                }
                .width('100%')
                .height(56)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .padding({ left: 16, right: 12 })
                .margin({ left: 16, right: 16, top: 4, bottom: 4 })
              }, (cat: CategoryItem): string => {
                return cat.id.toString() + '_' + cat.name;
              })
            }
            .width('100%')
          }
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        } else {
          // 平板/PC：双列卡片网格
          Scroll() {
            Row() {
              // 左列
              Column() {
                ForEach(this.getLeftCategories(), (cat: CategoryItem) => {
                  Column() {
                    Row() {
                      Text('●')
                        .fontSize(24)
                        .fontColor(cat.color)
                        .margin({ right: 12 })

                      Text(cat.name)
                        .fontSize(15)
                        .fontColor('#333333')
                        .layoutWeight(1)

                      if (cat.name !== '默认') {
                        Text('✎')
                          .fontSize(14)
                          .fontColor('#999999')
                          .padding(6)
                          .onClick(() => {
                            this.editingCategory = cat;
                            this.inputName = cat.name;
                            this.selectedColor = cat.color;
                            this.showEditDialog = true;
                          })

                        Text('🗑')
                          .fontSize(14)
                          .fontColor('#CCCCCC')
                          .padding(6)
                          .onClick(() => {
                            this.editingCategory = cat;
                            this.showDeleteDialog = true;
                          })
                      }
                    }
                    .width('100%')
                  }
                  .width('100%')
                  .backgroundColor(Color.White)
                  .borderRadius(14)
                  .padding(14)
                  .margin({ top: 4, bottom: 4 })
                }, (cat: CategoryItem): string => {
                  return 'left_' + cat.id.toString();
                })
              }
              .layoutWeight(1)
              .margin({ right: 4 })

              // 右列
              Column() {
                ForEach(this.getRightCategories(), (cat: CategoryItem) => {
                  Column() {
                    Row() {
                      Text('●')
                        .fontSize(24)
                        .fontColor(cat.color)
                        .margin({ right: 12 })

                      Text(cat.name)
                        .fontSize(15)
                        .fontColor('#333333')
                        .layoutWeight(1)

                      if (cat.name !== '默认') {
                        Text('✎')
                          .fontSize(14)
                          .fontColor('#999999')
                          .padding(6)
                          .onClick(() => {
                            this.editingCategory = cat;
                            this.inputName = cat.name;
                            this.selectedColor = cat.color;
                            this.showEditDialog = true;
                          })

                        Text('🗑')
                          .fontSize(14)
                          .fontColor('#CCCCCC')
                          .padding(6)
                          .onClick(() => {
                            this.editingCategory = cat;
                            this.showDeleteDialog = true;
                          })
                      }
                    }
                    .width('100%')
                  }
                  .width('100%')
                  .backgroundColor(Color.White)
                  .borderRadius(14)
                  .padding(14)
                  .margin({ top: 4, bottom: 4 })
                }, (cat: CategoryItem): string => {
                  return 'right_' + cat.id.toString();
                })
              }
              .layoutWeight(1)
              .margin({ left: 4 })
            }
            .width('100%')
            .padding({ left: 18, right: 18 })
            .alignItems(VerticalAlign.Top)
          }
          .scrollable(ScrollDirection.Vertical)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8F8F8')

      // 添加分类弹窗
      if (this.showAddDialog) {
        this.buildAddEditDialog('新建分类', '', () => {
          if (this.inputName.trim()) {
            this.vm.addCategory(this.inputName.trim(), this.selectedColor);
          }
          this.showAddDialog = false;
        })
      }

      // 编辑分类弹窗
      if (this.showEditDialog && this.editingCategory) {
        this.buildAddEditDialog('编辑分类', this.editingCategory.name, () => {
          if (this.inputName.trim() && this.editingCategory) {
            this.vm.updateCategory(this.editingCategory.id, this.inputName.trim(), this.selectedColor);
          }
          this.showEditDialog = false;
          this.editingCategory = null;
        })
      }

      // 删除确认弹窗
      if (this.showDeleteDialog && this.editingCategory) {
        this.buildDeleteConfirm()
      }
    }
    .width('100%')
    .height('100%')
  }

  // 奇偶拆分：左列取偶数索引
  private getLeftCategories(): CategoryItem[] {
    const result: CategoryItem[] = [];
    for (let i: number = 0; i < this.vm.categories.length; i += 2) {
      result.push(this.vm.categories[i]);
    }
    return result;
  }

  // 奇偶拆分：右列取奇数索引
  private getRightCategories(): CategoryItem[] {
    const result: CategoryItem[] = [];
    for (let i: number = 1; i < this.vm.categories.length; i += 2) {
      result.push(this.vm.categories[i]);
    }
    return result;
  }

  @Builder buildEmptyView() {
    Column() {
      Text('📂').fontSize(48).margin({ bottom: 12 })
      Text('暂无分类')
        .fontSize(16)
        .fontColor('#999999')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder buildAddEditDialog(title: string, initialName: string, onConfirm: () => void) {
    Stack() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .onClick(() => {
          this.showAddDialog = false;
          this.showEditDialog = false;
        })

      // 弹窗内容
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 20, bottom: 16 })

        // 名称输入
        TextInput({ text: this.inputName, placeholder: '分类名称' })
          .fontSize(15)
          .width('100%')
          .height(44)
          .borderRadius(10)
          .backgroundColor('#F5F5F5')
          .border({ width: 1, color: '#E8E8E8' })
          .padding({ left: 12, right: 12 })
          .margin({ left: 20, right: 20, bottom: 16 })
          .onChange((value: string) => {
            this.inputName = value;
          })

        // 颜色选择
        Text('选择颜色')
          .fontSize(13)
          .fontColor('#999999')
          .width('100%')
          .padding({ left: 20, bottom: 10 })

        Row() {
          ForEach(CATEGORY_COLORS, (color: string) => {
            Column() {
              Text('●')
                .fontSize(this.selectedColor === color ? 28 : 24)
                .fontColor(color)
            }
            .width(40)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .borderRadius(20)
            .border({
              width: this.selectedColor === color ? 2 : 0,
              color: color
            })
            .onClick(() => { this.selectedColor = color; })
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
        .justifyContent(FlexAlign.SpaceEvenly)

        // 按钮
        Row() {
          Text('取消')
            .fontSize(15)
            .fontColor('#999999')
            .layoutWeight(1)
            .height(44)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.showAddDialog = false;
              this.showEditDialog = false;
            })

          Text('确认')
            .fontSize(15)
            .fontColor(Color.White)
            .layoutWeight(1)
            .height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor('#FF6B6B')
            .borderRadius(22)
            .onClick(onConfirm)
        }
        .width('100%')
        .padding({ left: 30, right: 30, bottom: 20 })
      }
      .width(this.breakpoint === Breakpoint.SM ? '85%' : '400')
      .backgroundColor(Color.White)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
  }

  @Builder buildDeleteConfirm() {
    Stack() {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.4)')
        .onClick(() => { this.showDeleteDialog = false; })

      // 弹窗内容
      Column() {
        Text('确认删除分类？')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
          .padding({ top: 20, bottom: 8 })

        Text('该分类下的内容将移至「默认」分类')
          .fontSize(13)
          .fontColor('#999999')
          .textAlign(TextAlign.Center)
          .padding({ left: 20, right: 20, bottom: 16 })

        Row() {
          Text('取消')
            .fontSize(15)
            .fontColor('#999999')
            .layoutWeight(1)
            .height(44)
            .textAlign(TextAlign.Center)
            .onClick(() => { this.showDeleteDialog = false; })

          Text('确认删除')
            .fontSize(15)
            .fontColor(Color.White)
            .layoutWeight(1)
            .height(44)
            .textAlign(TextAlign.Center)
            .backgroundColor('#FF4444')
            .borderRadius(22)
            .onClick(() => {
              if (this.editingCategory) {
                this.vm.deleteCategory(this.editingCategory.id);
              }
              this.showDeleteDialog = false;
              this.editingCategory = null;
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, bottom: 16 })
      }
      .width(this.breakpoint === Breakpoint.SM ? '80%' : '380')
      .backgroundColor(Color.White)
      .borderRadius(16)
    }
    .width('100%')
    .height('100%')
  }
}
