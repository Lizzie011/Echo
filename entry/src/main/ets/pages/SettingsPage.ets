import { ClipboardViewModel } from '../viewmodel/ClipboardViewModel';
import { RETENTION_OPTIONS } from '../constant/CommonConstants';

/**
 * 设置页面
 * 存储时效设置、清空所有内容、关于信息
 */

@ComponentV2
export struct SettingsPage {
  @Require @Param vm: ClipboardViewModel;
  @Local private showClearDialog: boolean = false;

  build() {
    Stack() {
      Column() {
        // 标题
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .width('100%')
          .padding({ left: 18, top: 16, bottom: 16 })

        // 存储时效设置
        Column() {
          Text('存储时效')
            .fontSize(14)
            .fontColor('#999999')
            .width('100%')
            .padding({ left: 4, bottom: 10 })

          Row() {
            ForEach(RETENTION_OPTIONS, (days: number) => {
              Text(this.getRetentionLabel(days))
                .fontSize(13)
                .fontWeight(this.vm.retentionDays === days ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.vm.retentionDays === days ? Color.White : '#666666')
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .borderRadius(20)
                .backgroundColor(this.vm.retentionDays === days ? '#FF6B6B' : '#EEEEEE')
                .margin({ right: 8 })
                .onClick(() => {
                  this.vm.saveRetentionSetting(days);
                })
            })
          }
        }
        .width('100%')
        .backgroundColor(Color.White)
        .borderRadius(14)
        .padding(16)
        .margin({ left: 16, right: 16, bottom: 16 })

        // 清空所有内容
        Row() {
          Text('🗑')
            .fontSize(18)
            .margin({ right: 10 })
          Text('清空所有内容')
            .fontSize(15)
            .fontColor('#FF4444')
            .layoutWeight(1)
          Text('>')
            .fontSize(16)
            .fontColor('#CCCCCC')
        }
        .width('100%')
        .height(50)
        .backgroundColor(Color.White)
        .borderRadius(14)
        .padding({ left: 16, right: 16 })
        .margin({ left: 16, right: 16, bottom: 16 })
        .onClick(() => { this.showClearDialog = true; })

        // 关于
        Column() {
          Text('关于')
            .fontSize(14)
            .fontColor('#999999')
            .width('100%')
            .padding({ left: 4, bottom: 10 })

          Row() {
            Text('版本')
              .fontSize(14)
              .fontColor('#333333')
              .layoutWeight(1)
            Text('1.2.0')
              .fontSize(14)
              .fontColor('#999999')
          }
          .width('100%')
          .height(44)
        }
        .width('100%')
        .backgroundColor(Color.White)
        .borderRadius(14)
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .margin({ left: 16, right: 16 })

        Blank()
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F8F8F8')

      // 清空确认弹窗
      if (this.showClearDialog) {
        this.buildClearConfirm()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder buildClearConfirm() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0,0,0,0.4)')
        .onClick(() => { this.showClearDialog = false; })

      Column()
        .width('1%')
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)

    Column() {
      Text('确认清空所有剪贴记录？')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333333')
        .padding({ top: 20, bottom: 8 })

      Text('此操作不可撤销')
        .fontSize(13)
        .fontColor('#999999')
        .padding({ bottom: 16 })

      Row() {
        Text('取消')
          .fontSize(15)
          .fontColor('#999999')
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .onClick(() => { this.showClearDialog = false; })

        Text('确认清空')
          .fontSize(15)
          .fontColor(Color.White)
          .layoutWeight(1)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor('#FF4444')
          .borderRadius(22)
          .onClick(async () => {
            await this.vm.deleteAll();
            this.showClearDialog = false;
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
    }
    .width('80%')
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  private getRetentionLabel(days: number): string {
    switch (days) {
      case 0: return '永不';
      case 1: return '1天';
      case 3: return '3天';
      case 5: return '5天';
      case 7: return '7天';
      default: return `${days}天`;
    }
  }
}
