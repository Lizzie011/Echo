/**
 * 搜索栏组件（受控模式）
 * 用于剪贴板首页顶部的关键词搜索
 * value 由父组件管理，SearchBar 自身不持有输入状态
 */

@ComponentV2
export struct SearchBar {
  @Param placeholder: string = '搜索剪贴内容...';
  @Param value: string = '';
  @Event onChange?: (value: string) => void;

  build() {
    Row() {
      Text('🔍')
        .fontSize(16)
        .margin({ right: 8 })
      TextInput({ text: this.value, placeholder: this.placeholder })
        .fontSize(14)
        .backgroundColor(Color.Transparent)
        .border({ width: 0 })
        .layoutWeight(1)
        .onChange((val: string) => {
          if (this.onChange) {
            this.onChange(val);
          }
        })
      if (this.value.length > 0) {
        Text('✕')
          .fontSize(14)
          .fontColor('#999999')
          .padding(6)
          .onClick(() => {
            if (this.onChange) {
              this.onChange('');
            }
          })
      }
    }
    .width('100%')
    .height(40)
    .backgroundColor('#F0F0F0')
    .borderRadius(20)
    .padding({ left: 14, right: 10 })
    .alignItems(VerticalAlign.Center)
  }
}
