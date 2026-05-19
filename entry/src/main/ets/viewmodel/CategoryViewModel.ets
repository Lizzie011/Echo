import { common } from '@kit.AbilityKit';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { CategoryItem } from '../model/CategoryItem';
import { CATEGORY_COLORS } from '../constant/CommonConstants';

@ObservedV2
export class CategoryViewModel {
  @Trace categories: CategoryItem[] = [];
  private db: DatabaseHelper = DatabaseHelper.getInstance();

  async init(context: common.UIAbilityContext): Promise<void> {
    await this.db.init(context);
    await this.loadCategories();
  }

  async loadCategories(): Promise<void> {
    this.categories = await this.db.getAllCategories();
  }

  async addCategory(name: string, color: string): Promise<boolean> {
    if (!name || name.trim().length === 0) return false;
    const exists = this.categories.some(c => c.name === name.trim());
    if (exists) return false;

    // 1. 乐观更新 UI（即时响应，不等待 DB）
    const tempId: number = -Date.now(); // 临时负 id，DB 返回真实 id 后替换
    const newCat: CategoryItem = new CategoryItem();
    newCat.id = tempId;
    newCat.name = name.trim();
    newCat.color = color;
    newCat.createdAt = Date.now();
    const updated: CategoryItem[] = [newCat];
    for (const c of this.categories) {
      updated.push(c);
    }
    this.categories = updated;

    // 2. 异步持久化
    const rowId: number = await this.db.addCategory(name.trim(), color);
    if (rowId > 0) {
      // 替换临时 id 为真实 id
      const fixed: CategoryItem[] = [];
      for (const c of this.categories) {
        if (c.id === tempId) {
          c.id = rowId;
        }
        fixed.push(c);
      }
      this.categories = fixed;
    }
    return true;
  }

  async updateCategory(id: number, name: string, color: string): Promise<void> {
    // 1. 乐观更新 UI（即时响应）
    const updated: CategoryItem[] = [];
    for (const c of this.categories) {
      const item: CategoryItem = new CategoryItem();
      item.id = c.id;
      item.name = (c.id === id) ? name : c.name;
      item.color = (c.id === id) ? color : c.color;
      item.createdAt = c.createdAt;
      updated.push(item);
    }
    this.categories = updated;

    // 2. 异步持久化
    await this.db.updateCategory(id, name, color);
  }

  async deleteCategory(id: number): Promise<void> {
    // 1. 乐观更新 UI（即时响应）
    const updated: CategoryItem[] = [];
    for (const c of this.categories) {
      if (c.id !== id) {
        updated.push(c);
      }
    }
    this.categories = updated;

    // 2. 异步持久化
    await this.db.deleteCategory(id);
  }

  getCategoryById(id: number): CategoryItem | undefined {
    return this.categories.find(c => c.id === id);
  }

  getDefaultColor(): string {
    const usedColors = this.categories.map(c => c.color);
    const available = CATEGORY_COLORS.find(c => !usedColors.includes(c));
    return available || CATEGORY_COLORS[this.categories.length % CATEGORY_COLORS.length];
  }
}
