import relationalStore from '@ohos.data.relationalStore';
import { common } from '@kit.AbilityKit';
import { ClipItem } from '../model/ClipItem';
import { CategoryItem } from '../model/CategoryItem';
import { DB_NAME, DEFAULT_CATEGORY_NAME, DEFAULT_CATEGORY_COLOR } from '../constant/CommonConstants';

const TAG: string = 'Echo-DatabaseHelper';

const SQL_CREATE_CATEGORIES: string = `
  CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    color TEXT NOT NULL DEFAULT '#FF6B6B',
    createdAt INTEGER NOT NULL
  )
`;

const SQL_CREATE_CLIPS: string = `
  CREATE TABLE IF NOT EXISTS clips (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL,
    content TEXT NOT NULL,
    categoryId INTEGER NOT NULL,
    isPinned INTEGER NOT NULL DEFAULT 0,
    createdAt INTEGER NOT NULL,
    expiresAt INTEGER
  )
`;

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1
};

interface QueryOptions {
  categoryId?: number;
  keyword?: string;
}

export class DatabaseHelper {
  private static instance: DatabaseHelper;
  private store: relationalStore.RdbStore | null = null;

  static getInstance(): DatabaseHelper {
    if (!DatabaseHelper.instance) {
      DatabaseHelper.instance = new DatabaseHelper();
    }
    return DatabaseHelper.instance;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.store) return;
    this.store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await this.store.executeSql(SQL_CREATE_CATEGORIES);
    await this.store.executeSql(SQL_CREATE_CLIPS);
    await this.ensureDefaultCategory();
  }

  getStore(): relationalStore.RdbStore {
    if (!this.store) {
      throw new Error('Database not initialized. Call init() first.');
    }
    return this.store;
  }

  // ==================== 分类操作 ====================

  async ensureDefaultCategory(): Promise<number> {
    const store: relationalStore.RdbStore = this.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('name', DEFAULT_CATEGORY_NAME);
    const resultSet: relationalStore.ResultSet = await store.query(predicates);
    if (resultSet.rowCount > 0) {
      resultSet.goToFirstRow();
      const id: number = resultSet.getLong(resultSet.getColumnIndex('id'));
      resultSet.close();
      return id;
    }
    resultSet.close();
    const bucket: relationalStore.ValuesBucket = {
      name: DEFAULT_CATEGORY_NAME,
      color: DEFAULT_CATEGORY_COLOR,
      createdAt: Date.now()
    };
    const rowId: number = await store.insert('categories', bucket);
    return rowId;
  }

  async getAllCategories(): Promise<CategoryItem[]> {
    const store: relationalStore.RdbStore = this.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('categories');
    predicates.orderByAsc('createdAt');
    const resultSet: relationalStore.ResultSet = await store.query(predicates);
    const list: CategoryItem[] = [];
    while (resultSet.goToNextRow()) {
      const item: CategoryItem = new CategoryItem();
      item.id = resultSet.getLong(resultSet.getColumnIndex('id'));
      item.name = resultSet.getString(resultSet.getColumnIndex('name'));
      item.color = resultSet.getString(resultSet.getColumnIndex('color'));
      item.createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'));
      list.push(item);
    }
    resultSet.close();
    return list;
  }

  async addCategory(name: string, color: string): Promise<number> {
    const store: relationalStore.RdbStore = this.getStore();
    const bucket: relationalStore.ValuesBucket = {
      name: name,
      color: color,
      createdAt: Date.now()
    };
    const rowId: number = await store.insert('categories', bucket);
    return rowId;
  }

  async updateCategory(id: number, name: string, color: string): Promise<void> {
    const store: relationalStore.RdbStore = this.getStore();
    const bucket: relationalStore.ValuesBucket = {
      name: name,
      color: color
    };
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('id', id);
    await store.update(bucket, predicates);
  }

  async deleteCategory(id: number): Promise<void> {
    const store: relationalStore.RdbStore = this.getStore();
    const defaultId: number = await this.ensureDefaultCategory();
    const updateBucket: relationalStore.ValuesBucket = { categoryId: defaultId };
    const updatePred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('clips');
    updatePred.equalTo('categoryId', id);
    await store.update(updateBucket, updatePred);

    const deletePred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('categories');
    deletePred.equalTo('id', id);
    await store.delete(deletePred);
  }

  // ==================== 剪贴内容操作 ====================

  async addClip(clip: ClipItem): Promise<number> {
    const store: relationalStore.RdbStore = this.getStore();
    const dupPred: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('clips');
    dupPred.equalTo('content', clip.content);
    dupPred.equalTo('type', clip.type);
    dupPred.greaterThan('createdAt', Date.now() - 60000);
    const dupResult: relationalStore.ResultSet = await store.query(dupPred);
    if (dupResult.rowCount > 0) {
      dupResult.close();
      return -1;
    }
    dupResult.close();

    const bucket: relationalStore.ValuesBucket = {
      type: clip.type,
      content: clip.content,
      categoryId: clip.categoryId,
      isPinned: clip.isPinned ? 1 : 0,
      createdAt: clip.createdAt,
      expiresAt: clip.expiresAt
    };
    const rowId: number = await store.insert('clips', bucket);
    return rowId;
  }

  async queryClips(options: QueryOptions): Promise<ClipItem[]> {
    const store: relationalStore.RdbStore = this.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('clips');

    if (options.categoryId !== undefined && options.categoryId > 0) {
      predicates.equalTo('categoryId', options.categoryId);
    }
    if (options.keyword !== undefined && options.keyword.length > 0) {
      predicates.like('content', '%' + options.keyword + '%');
      predicates.equalTo('type', 'text');
    }

    predicates.orderByDesc('isPinned');
    predicates.orderByDesc('createdAt');

    const resultSet: relationalStore.ResultSet = await store.query(predicates);
    const list: ClipItem[] = [];
    while (resultSet.goToNextRow()) {
      const item: ClipItem = new ClipItem();
      item.id = resultSet.getLong(resultSet.getColumnIndex('id'));
      item.type = resultSet.getString(resultSet.getColumnIndex('type'));
      item.content = resultSet.getString(resultSet.getColumnIndex('content'));
      item.categoryId = resultSet.getLong(resultSet.getColumnIndex('categoryId'));
      item.isPinned = resultSet.getLong(resultSet.getColumnIndex('isPinned')) === 1;
      item.createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'));
      item.expiresAt = resultSet.getLong(resultSet.getColumnIndex('expiresAt'));
      list.push(item);
    }
    resultSet.close();
    return list;
  }

  async togglePin(clipId: number, pinned: boolean): Promise<void> {
    const store: relationalStore.RdbStore = this.getStore();
    const bucket: relationalStore.ValuesBucket = { isPinned: pinned ? 1 : 0 };
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('clips');
    predicates.equalTo('id', clipId);
    await store.update(bucket, predicates);
  }

  async moveClip(clipId: number, categoryId: number): Promise<void> {
    const store: relationalStore.RdbStore = this.getStore();
    const bucket: relationalStore.ValuesBucket = { categoryId: categoryId };
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('clips');
    predicates.equalTo('id', clipId);
    await store.update(bucket, predicates);
  }

  async deleteClip(clipId: number): Promise<void> {
    const store: relationalStore.RdbStore = this.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('clips');
    predicates.equalTo('id', clipId);
    await store.delete(predicates);
  }

  async deleteAllClips(): Promise<void> {
    const store: relationalStore.RdbStore = this.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('clips');
    await store.delete(predicates);
  }

  async deleteExpiredClips(): Promise<number> {
    const store: relationalStore.RdbStore = this.getStore();
    const now: number = Date.now();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('clips');
    predicates.greaterThan('expiresAt', 0);
    predicates.lessThan('expiresAt', now);
    const count: number = await store.delete(predicates);
    return count;
  }

  async getCategoryById(id: number): Promise<CategoryItem | null> {
    const store: relationalStore.RdbStore = this.getStore();
    const predicates: relationalStore.RdbPredicates = new relationalStore.RdbPredicates('categories');
    predicates.equalTo('id', id);
    const resultSet: relationalStore.ResultSet = await store.query(predicates);
    if (resultSet.goToFirstRow()) {
      const item: CategoryItem = new CategoryItem();
      item.id = resultSet.getLong(resultSet.getColumnIndex('id'));
      item.name = resultSet.getString(resultSet.getColumnIndex('name'));
      item.color = resultSet.getString(resultSet.getColumnIndex('color'));
      item.createdAt = resultSet.getLong(resultSet.getColumnIndex('createdAt'));
      resultSet.close();
      return item;
    }
    resultSet.close();
    return null;
  }
}
