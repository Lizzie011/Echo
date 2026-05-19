/**
 * 应用常量定义
 */

// 分类预设颜色
export const CATEGORY_COLORS: string[] = [
  '#FF6B6B', // 珊瑚红
  '#4ECDC4', // 青绿
  '#FFD93D', // 暖黄
  '#6C5CE7', // 紫罗兰
  '#A8E6CF', // 薄荷绿
  '#FF8A80', // 粉红
  '#80D8FF', // 天蓝
  '#FFB74D', // 橘橙
];

// 默认分类名称
export const DEFAULT_CATEGORY_NAME: string = '默认';

// 默认分类颜色
export const DEFAULT_CATEGORY_COLOR: string = '#FF6B6B';

// 存储时效选项（天数）
export const RETENTION_OPTIONS: number[] = [0, 1, 3, 5, 7];

// 存储时效标签
export const RETENTION_LABELS: Map<number, string> = new Map([
  [0, '永不'],
  [1, '1天'],
  [3, '3天'],
  [5, '5天'],
  [7, '7天'],
]);

// 数据库名
export const DB_NAME: string = 'Echo.db';

// Preferences名
export const PREF_NAME: string = 'echo_settings';

// 设置键
export const KEY_RETENTION_DAYS: string = 'retentionDays';
export const KEY_DEFAULT_CATEGORY: string = 'defaultCategoryId';
