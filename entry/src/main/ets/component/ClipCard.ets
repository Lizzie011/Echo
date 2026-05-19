import { ClipItem } from '../model/ClipItem';

/**
 * 剪贴内容卡片组件
 * 点击复制到剪贴板，长按弹出操作菜单（置顶/移动/删除）
 */

@ComponentV2
export struct ClipCard {
  @Param clipItem: ClipItem = new ClipItem();
  @Param categoryName: string = '';
  @Param categoryColor: string = '#FF6B6B';
  @Event onCopy?: (item: ClipItem) => void;

  build() {
    Column() {
      Row() {
        Text(this.clipItem.type === 'image' ? '🖼' : '📝')
          .fontSize(22)
          .margin({ right: 10 })

        Column() {
          Text(this.clipItem.type === 'text'
            ? this.clipItem.content.substring(0, 200)
            : this.getImageFileName())
            .fontSize(14)
            .fontColor('#1A1A1A')
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Row() {
            Text(this.formatTime(this.clipItem.createdAt))
              .fontSize(11)
              .fontColor('#999999')
            Blank()
            if (this.categoryName.length > 0) {
              Text(this.categoryName)
                .fontSize(10)
                .fontColor(Color.White)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .borderRadius(8)
                .backgroundColor(this.categoryColor)
            }
            if (this.clipItem.isPinned) {
              Text('📌')
                .fontSize(10)
                .margin({ left: 4 })
            }
          }
          .width('100%')
          .margin({ top: 6 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding(14)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(14)
    .border({ width: 1, color: '#F0F0F0' })
    .margin({ top: 4, bottom: 4 })
    .onClick(() => {
      if (this.onCopy) {
        this.onCopy(this.clipItem);
      }
    })
  }

  private getImageFileName(): string {
    const parts: string[] = this.clipItem.content.split('/');
    if (parts.length > 0) {
      return parts[parts.length - 1];
    }
    return '图片';
  }

  private formatTime(timestamp: number): string {
    const date: Date = new Date(timestamp);
    const month: string = (date.getMonth() + 1).toString().padStart(2, '0');
    const day: string = date.getDate().toString().padStart(2, '0');
    const hour: string = date.getHours().toString().padStart(2, '0');
    const minute: string = date.getMinutes().toString().padStart(2, '0');
    return month + '-' + day + ' ' + hour + ':' + minute;
  }
}
