/**
 * 断点系统常量定义
 * 用于"一次开发，多端部署"的响应式布局
 *
 * sm: < 600vp  — 手机竖屏（保持现有布局）
 * md: 600-840vp — 平板竖屏 / 折叠展开 / 小窗 PC
 * lg: > 840vp  — 平板横屏 / PC 大窗
 */

export enum Breakpoint {
  SM = 'sm',
  MD = 'md',
  LG = 'lg'
}

/**
 * 断点范围接口
 */
export interface BreakpointRange {
  min: number;
  max: number;
}

export function getBreakpointRange(bp: Breakpoint): BreakpointRange {
  switch (bp) {
    case Breakpoint.SM:
      return { min: 0, max: 599 } as BreakpointRange;
    case Breakpoint.MD:
      return { min: 600, max: 840 } as BreakpointRange;
    case Breakpoint.LG:
      return { min: 841, max: Infinity } as BreakpointRange;
  }
}

/**
 * 根据宽度计算当前断点
 */
export function calcBreakpoint(width: number): Breakpoint {
  if (width < 600) {
    return Breakpoint.SM;
  }
  if (width <= 840) {
    return Breakpoint.MD;
  }
  return Breakpoint.LG;
}

/**
 * 根据断点计算剪贴板卡片列数
 */
export function calcGridColumns(bp: Breakpoint): number {
  switch (bp) {
    case Breakpoint.SM:
      return 1;
    case Breakpoint.MD:
      return 2;
    case Breakpoint.LG:
      return 3;
  }
}

/**
 * 判断是否使用侧边导航（宽屏布局）
 */
export function isWideLayout(bp: Breakpoint): boolean {
  return bp === Breakpoint.MD || bp === Breakpoint.LG;
}

/**
 * 侧边导航栏宽度（vp）
 */
export function sideNavWidth(bp: Breakpoint): number {
  return bp === Breakpoint.MD ? 60 : 180;
}

/**
 * 弹窗在宽屏下的最大宽度（vp）
 */
export function dialogMaxWidth(bp: Breakpoint): number {
  if (bp === Breakpoint.SM) {
    return 340;
  }
  return 420;
}
