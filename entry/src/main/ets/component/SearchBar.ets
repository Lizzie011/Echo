/**
 * 搜索栏组件
 * 用于剪贴板首页顶部的关键词搜索
 */

@ComponentV2
export struct SearchBar {
  @Param placeholder: string = '搜索剪贴内容...';
  @Event onChange?: (value: string) => void;
  @Local private inputValue: string = '';

  build() {
    Row() {
      Text('🔍')
        .fontSize(16)
        .margin({ right: 8 })
      TextInput({ text: this.inputValue, placeholder: this.placeholder })
        .fontSize(14)
        .backgroundColor(Color.Transparent)
        .border({ width: 0 })
        .layoutWeight(1)
        .onChange((value: string) => {
          this.inputValue = value;
          if (this.onChange) {
            this.onChange(value);
          }
        })
      if (this.inputValue.length > 0) {
        Text('✕')
          .fontSize(14)
          .fontColor('#999999')
          .padding(6)
          .onClick(() => {
            this.inputValue = '';
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
