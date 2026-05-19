/**
 * 剪贴内容数据模型
 */
export class ClipItem {
  id: number = 0;
  type: string = 'text';
  content: string = '';
  categoryId: number = 1;
  isPinned: boolean = false;
  createdAt: number = Date.now();
  expiresAt: number = 0;
}
