import { common, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import pasteboard from '@ohos.pasteboard';
import { BusinessError } from '@kit.BasicServicesKit';
import image from '@ohos.multimedia.image';
import fileIo from '@ohos.file.fs';
import preferences from '@ohos.data.preferences';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { ClipItem } from '../model/ClipItem';

const TAG: string = 'Echo-ClipboardVM';

@ObservedV2
export class ClipboardViewModel {
  @Trace clips: ClipItem[] = [];
  @Trace searchKeyword: string = '';
  @Trace selectedCategoryId: number = 0;
  @Trace retentionDays: number = 3;
  private db: DatabaseHelper = DatabaseHelper.getInstance();
  private systemPasteboard: pasteboard.SystemPasteboard | null = null;
  private context: common.UIAbilityContext | null = null;
  private updateCallback: (() => void) | null = null;
  private skipNextUpdate: boolean = false;
  private lastContent: string = '';
  private pollingTimerId: number = -1;
  private isMonitoringActive: boolean = false;
  private isPermissionGranted: boolean = false;
  private readonly POLL_INTERVAL_MS: number = 2500;
  private needsBaseline: boolean = true;
  private fullClips: ClipItem[] = [];
  private searchTimer: number = -1;
  private defaultCategoryId: number = 1;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    await this.db.init(context);
    this.defaultCategoryId = await this.db.ensureDefaultCategory();
    await this.loadRetentionSetting();
    await this.cleanExpired();
    await this.loadClips();
    await this.requestPermission();
    if (this.isPermissionGranted) {
      this.startMonitoring();
    } else {
      hilog.warn(0x0000, TAG, 'READ_PASTEBOARD permission not granted. Monitoring disabled.');
    }
  }

  private async requestPermission(): Promise<void> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const grantStatus: abilityAccessCtrl.GrantStatus =
        atManager.checkAccessTokenSync(this.context!.applicationInfo.accessTokenId, 'ohos.permission.READ_PASTEBOARD');
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        this.isPermissionGranted = true;
        hilog.info(0x0000, TAG, 'READ_PASTEBOARD already granted');
        return;
      }
      const permissions: Permissions[] = ['ohos.permission.READ_PASTEBOARD'];
      const result = await atManager.requestPermissionsFromUser(this.context!, permissions);
      if (result.authResults[0] === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        this.isPermissionGranted = true;
        hilog.info(0x0000, TAG, 'READ_PASTEBOARD granted by user');
      } else {
        hilog.warn(0x0000, TAG, 'READ_PASTEBOARD denied by user');
      }
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(0x0000, TAG, `Permission request failed: code=${e.code}, msg=${e.message}`);
    }
  }

  release(): void {
    this.stopMonitoring();
  }

  // ==================== 剪贴板监听 ====================

  private startMonitoring(): void {
    if (this.isMonitoringActive) return;
    try {
      this.systemPasteboard = pasteboard.getSystemPasteboard();

      this.updateCallback = (): void => {
        if (this.skipNextUpdate) {
          this.skipNextUpdate = false;
          return;
        }
        hilog.info(0x0000, TAG, 'pasteboard update event received');
        this.readAndSaveClipboard();
      };
      this.systemPasteboard.on('update', this.updateCallback);
      hilog.info(0x0000, TAG, 'update event listener registered');

      // 建立基线：needsBaseline 标志确保无论哪个路径先读到剪贴板，
      // 第一次都只记入 lastContent 不存 DB，防止 App 关闭期间的旧内容被误存
      this.needsBaseline = true;
      this.lastContent = '';
      this.establishBaseline();

      this.scheduleNextPoll();

      this.isMonitoringActive = true;
      hilog.info(0x0000, TAG, 'Clipboard monitoring started (event + polling)');
    } catch (e) {
      hilog.error(0x0000, TAG, 'Failed to start monitoring: ' + String(e));
    }
  }

  private async establishBaseline(): Promise<void> {
    if (!this.systemPasteboard) return;
    try {
      const sp: pasteboard.SystemPasteboard = this.systemPasteboard;
      const pasteData: pasteboard.PasteData = await new Promise<pasteboard.PasteData>(
        (resolve: (value: pasteboard.PasteData) => void, reject: (reason: Error) => void): void => {
          sp.getData((err: Error, data: pasteboard.PasteData): void => {
            if (err) { reject(err); } else { resolve(data); }
          });
        }
      );
      const text: string = pasteData.getPrimaryText();
      if (text.length > 0) {
        this.lastContent = text;
        this.needsBaseline = false;
        hilog.info(0x0000, TAG, `Baseline set explicitly, length=${text.length}`);
      }
    } catch (e) {
      // 基线读取失败不影响后续监听
    }
  }

  private scheduleNextPoll(): void {
    if (this.pollingTimerId !== -1) {
      clearTimeout(this.pollingTimerId);
      this.pollingTimerId = -1;
    }
    this.pollingTimerId = setTimeout((): void => {
      this.pollOnce();
    }, this.POLL_INTERVAL_MS);
  }

  private async pollOnce(): Promise<void> {
    if (!this.isMonitoringActive) return;
    await this.readAndSaveClipboard();
    if (this.isMonitoringActive) {
      this.scheduleNextPoll();
    }
  }

  private stopMonitoring(): void {
    this.isMonitoringActive = false;

    if (this.pollingTimerId !== -1) {
      clearTimeout(this.pollingTimerId);
      this.pollingTimerId = -1;
    }

    if (this.systemPasteboard && this.updateCallback) {
      try {
        this.systemPasteboard.off('update', this.updateCallback);
      } catch (e) {
        hilog.warn(0x0000, TAG, 'Failed to remove update listener: ' + String(e));
      }
      this.updateCallback = null;
    }
  }

  private async readAndSaveClipboard(): Promise<void> {
    if (!this.systemPasteboard) return;
    if (!this.isPermissionGranted) return;

    try {
      const sp: pasteboard.SystemPasteboard = this.systemPasteboard;
      const pasteData: pasteboard.PasteData = await new Promise<pasteboard.PasteData>(
        (resolve: (value: pasteboard.PasteData) => void, reject: (reason: Error) => void): void => {
          sp.getData((err: Error, data: pasteboard.PasteData): void => {
            if (err) { reject(err); } else { resolve(data); }
          });
        }
      );

      const text: string = pasteData.getPrimaryText();
      hilog.info(0x0000, TAG, `getPrimaryText returned, length=${text.length}`);
      if (text.length > 0) {
        if (this.needsBaseline) {
          // 首次读到的是 App 启动前就存在的旧内容，只建基线不存储
          this.lastContent = text;
          this.needsBaseline = false;
          hilog.info(0x0000, TAG, `Baseline captured via event/poll, length=${text.length}`);
          return;
        }
        await this.saveClip('text', text);
        return;
      }

      const recordCount: number = pasteData.getRecordCount();
      hilog.info(0x0000, TAG, `recordCount=${recordCount}`);
      if (recordCount > 0) {
        const record: pasteboard.PasteDataRecord = pasteData.getRecord(0);
        const plainText: string = record.plainText;
        if (plainText.length > 0) {
          hilog.info(0x0000, TAG, `Got text via record.plainText, length=${plainText.length}`);
          if (this.needsBaseline) {
            this.lastContent = plainText;
            this.needsBaseline = false;
            hilog.info(0x0000, TAG, `Baseline captured via record.plainText, length=${plainText.length}`);
            return;
          }
          await this.saveClip('text', plainText);
          return;
        }
        if (record.pixelMap) {
          await this.saveImageClip(record.pixelMap);
        }
      }
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(0x0000, TAG, `readAndSaveClipboard failed: code=${e.code}, msg=${e.message}`);
    }
  }

  private async saveClip(type: string, content: string): Promise<void> {
    if (content === this.lastContent) return;
    this.lastContent = content;

    if (!this.context) return;
    const now: number = Date.now();
    let expiresAt: number = 0;
    if (this.retentionDays > 0) {
      expiresAt = now + this.retentionDays * 24 * 60 * 60 * 1000;
    }

    const clip: ClipItem = new ClipItem();
    clip.type = type;
    clip.content = content;
    clip.categoryId = this.defaultCategoryId;
    clip.isPinned = false;
    clip.createdAt = now;
    clip.expiresAt = expiresAt;

    const rowId: number = await this.db.addClip(clip);
    if (rowId > 0) {
      clip.id = rowId;
      // 更新主列表（prepend）
      const newFull: ClipItem[] = [clip];
      for (const c of this.fullClips) {
        newFull.push(c);
      }
      this.fullClips = newFull;
      // 应用当前筛选条件
      this.applyFilters();
      hilog.info(0x0000, TAG, `Clip saved, id=${rowId}, content length=${content.length}, full=${newFull.length}, filtered=${this.clips.length}`);
    }
  }

  private async saveImageClip(pixelMap: image.PixelMap): Promise<void> {
    if (!this.context) return;
    try {
      const imagePacker: image.ImagePacker = image.createImagePacker();
      const fileName: string = 'echo_img_' + String(Date.now()) + '.png';
      const filePath: string = this.context.filesDir + '/' + fileName;
      const packOpts: image.PackingOption = {
        format: 'image/png',
        quality: 95
      };
      const data: ArrayBuffer = await imagePacker.packing(pixelMap, packOpts);
      const file: fileIo.File = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);

      await this.saveClip('image', filePath);
    } catch (e) {
      console.error(TAG, 'Failed to save image: ' + String(e));
    }
  }

  onForeground(): void {
    hilog.info(0x0000, TAG, 'App came to foreground');
    if (!this.isPermissionGranted) return;
    if (!this.isMonitoringActive) {
      this.startMonitoring();
    }
  }

  // ==================== 数据加载 & 筛选 ====================

  /**
   * 初始加载：从 DB 加载全部数据到 fullClips，无筛选条件时 clips = fullClips
   */
  async loadClips(): Promise<void> {
    const opts: Record<string, number | string | undefined> = {};
    let list: ClipItem[] = await this.db.queryClips(opts);
    if (this.retentionDays > 0) {
      const now: number = Date.now();
      const filtered: ClipItem[] = [];
      for (const c of list) {
        if (c.expiresAt === 0 || c.expiresAt > now) {
          filtered.push(c);
        }
      }
      list = filtered;
    }
    this.fullClips = list;
    this.applyFilters();
  }

  /**
   * 将 fullClips 按当前 searchKeyword / selectedCategoryId 过滤，结果写入 clips
   */
  private applyFilters(): void {
    const result: ClipItem[] = [];
    // pinned 优先
    for (const c of this.fullClips) {
      if (!c.isPinned) continue;
      if (!this.passFilter(c)) continue;
      result.push(c);
    }
    // 非 pinned
    for (const c of this.fullClips) {
      if (c.isPinned) continue;
      if (!this.passFilter(c)) continue;
      result.push(c);
    }
    this.clips = result;
  }

  private passFilter(c: ClipItem): boolean {
    if (this.searchKeyword.length > 0) {
      if (c.type === 'text') {
        // 大小写不敏感搜索
        if (!c.content.toLowerCase().includes(this.searchKeyword.toLowerCase())) {
          return false;
        }
      } else if (c.type === 'image') {
        // 图片用文件名参与搜索过滤
        const fileName: string = this.extractFileName(c.content);
        if (!fileName.toLowerCase().includes(this.searchKeyword.toLowerCase())) {
          return false;
        }
      }
    }
    if (this.selectedCategoryId > 0) {
      if (c.categoryId !== this.selectedCategoryId) {
        return false;
      }
    }
    return true;
  }

  private extractFileName(filePath: string): string {
    const lastSlash: number = filePath.lastIndexOf('/');
    if (lastSlash >= 0 && lastSlash < filePath.length - 1) {
      return filePath.substring(lastSlash + 1);
    }
    return filePath;
  }

  async loadRetentionSetting(): Promise<void> {
    if (!this.context) return;
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(this.context, 'echo_settings');
      const days: number = await prefs.get('retentionDays', 3) as number;
      this.retentionDays = days;
    } catch (e) {
      this.retentionDays = 3;
    }
  }

  async saveRetentionSetting(days: number): Promise<void> {
    if (!this.context) return;
    this.retentionDays = days;
    try {
      const prefs: preferences.Preferences = await preferences.getPreferences(this.context, 'echo_settings');
      await prefs.put('retentionDays', days);
      await prefs.flush();
    } catch (e) {
      // ignore
    }
  }

  // ==================== 搜索 & 筛选 ====================

  onSearch(keyword: string): void {
    // 200ms 防抖，减少快速输入时的频繁过滤
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer);
    }
    this.searchTimer = setTimeout(() => {
      this.searchKeyword = keyword;
      this.applyFilters();
      this.searchTimer = -1;
    }, 200);
  }

  onFilterCategory(categoryId: number): void {
    this.selectedCategoryId = categoryId;
    this.applyFilters();
  }

  // ==================== 操作 ====================

  async copyToClipboard(clip: ClipItem): Promise<void> {
    if (!this.systemPasteboard) return;
    if (clip.type !== 'text' && clip.type !== 'image') return;

    this.skipNextUpdate = true;
    this.lastContent = clip.content;
    try {
      const sp: pasteboard.SystemPasteboard = this.systemPasteboard;
      if (clip.type === 'image') {
        // 检查图片文件是否存在
        try {
          fileIo.statSync(clip.content);
        } catch (e) {
          hilog.warn(0x0000, TAG, `Image file not found: ${clip.content}`);
          throw new Error('Image file missing');
        }
        // 读取图片文件到 PixelMap
        const imgFile: fileIo.File = fileIo.openSync(clip.content, 0o0);
        const stat: fileIo.Stat = fileIo.statSync(clip.content);
        const buf: ArrayBuffer = new ArrayBuffer(stat.size);
        fileIo.readSync(imgFile.fd, buf);
        fileIo.closeSync(imgFile);
        const imgSource: image.ImageSource = image.createImageSource(buf);
        const pixelMap: image.PixelMap = await imgSource.createPixelMap();
        // 用 addRecord 方式构建 PasteData，兼容性更好
        const pData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, '');
        const record: pasteboard.PasteDataRecord = pasteboard.createRecord(pasteboard.MIMETYPE_PIXELMAP, pixelMap);
        pData.addRecord(record);
        await new Promise<void>((resolve: () => void, reject: (reason: Error) => void): void => {
          sp.setData(pData, (err: Error): void => {
            if (err) { reject(err); } else { resolve(); }
          });
        });
        hilog.info(0x0000, TAG, 'Image copied to clipboard successfully');
      } else {
        const pData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, clip.content);
        await new Promise<void>((resolve: () => void, reject: (reason: Error) => void): void => {
          sp.setData(pData, (err: Error): void => {
            if (err) { reject(err); } else { resolve(); }
          });
        });
        hilog.info(0x0000, TAG, 'Text copied to clipboard successfully');
      }
    } catch (err) {
      this.skipNextUpdate = false;
      const e: BusinessError = err as BusinessError;
      hilog.error(0x0000, TAG, `copyToClipboard failed: code=${e.code}, msg=${e.message}`);
    }
  }

  async togglePin(clip: ClipItem): Promise<void> {
    // 从 fullClips 中找到实际对象，避免使用可能过期的参数对象
    let actualPinned: boolean = clip.isPinned;
    for (const c of this.fullClips) {
      if (c.id === clip.id) {
        actualPinned = c.isPinned;
        break;
      }
    }
    const newPinned: boolean = !actualPinned;

    // 1. 乐观更新 UI（即时响应）
    const newFull: ClipItem[] = [];
    for (const c of this.fullClips) {
      if (c.id === clip.id) {
        const item: ClipItem = new ClipItem();
        item.id = c.id;
        item.type = c.type;
        item.content = c.content;
        item.categoryId = c.categoryId;
        item.isPinned = newPinned;
        item.createdAt = c.createdAt;
        item.expiresAt = c.expiresAt;
        newFull.push(item);
      } else {
        newFull.push(c);
      }
    }
    this.fullClips = newFull;
    this.applyFilters();

    // 2. 异步持久化到 DB（不影响 UI 响应速度）
    await this.db.togglePin(clip.id, newPinned);
  }

  async moveToCategory(clipId: number, categoryId: number): Promise<void> {
    // 1. 乐观更新 UI（即时响应）
    const newFull: ClipItem[] = [];
    for (const c of this.fullClips) {
      if (c.id === clipId) {
        const item: ClipItem = new ClipItem();
        item.id = c.id;
        item.type = c.type;
        item.content = c.content;
        item.categoryId = categoryId;
        item.isPinned = c.isPinned;
        item.createdAt = c.createdAt;
        item.expiresAt = c.expiresAt;
        newFull.push(item);
      } else {
        newFull.push(c);
      }
    }
    this.fullClips = newFull;
    this.applyFilters();

    // 2. 异步持久化
    await this.db.moveClip(clipId, categoryId);
    hilog.info(0x0000, TAG, `Clip ${clipId} moved to category ${categoryId}`);
  }

  async deleteClip(clipId: number): Promise<void> {
    // 先找到被删除的条目，如果是图片则清理文件
    for (const c of this.fullClips) {
      if (c.id === clipId && c.type === 'image') {
        try { fileIo.unlinkSync(c.content); } catch (e) { /* ignore */ }
        break;
      }
    }
    // 1. 乐观更新 UI（即时响应）
    const newFull: ClipItem[] = [];
    for (const c of this.fullClips) {
      if (c.id !== clipId) {
        newFull.push(c);
      }
    }
    this.fullClips = newFull;
    this.applyFilters();

    // 2. 异步持久化
    await this.db.deleteClip(clipId);
  }

  async deleteAll(): Promise<void> {
    await this.db.deleteAllClips();
    this.fullClips = [];
    this.clips = [];
  }

  async cleanExpired(): Promise<void> {
    await this.db.deleteExpiredClips();
    if (this.retentionDays > 0) {
      const now: number = Date.now();
      const newFull: ClipItem[] = [];
      for (const c of this.fullClips) {
        if (c.expiresAt === 0 || c.expiresAt > now) {
          newFull.push(c);
        } else {
          // 过期图片清理磁盘文件
          if (c.type === 'image') {
            try { fileIo.unlinkSync(c.content); } catch (e) { /* ignore */ }
          }
        }
      }
      this.fullClips = newFull;
    }
    this.applyFilters();
  }
}
