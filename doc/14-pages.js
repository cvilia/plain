/* ============================================================
 * 素记 Plain · 全页面高保真 UI —— 页面骨架与交互
 * 蓝本：《03-交互原型.html》（29 屏 / V1.0 11 + V2.0 8 + V3.0 10）
 * 差异：线框态 → 高保真（46 令牌 / 10 主题 / 明暗两态），
 *       色值取自代码权威值 theme_registry.dart，非原型低保真旧值。
 * ============================================================ */
(function () {
  'use strict';

  /* ========== 数据层（照搬原型，色值改为 CSS 变量引用） ========== */
  const D = (d) => `2026-09-${String(d).padStart(2, '0')}`;

  let tx = [
    { id: 1, type: 'e', amt: 12, cat: '餐饮', sub: '早餐', note: '包子豆浆', acc: '现金', date: D(29), time: '08:15', src: '手动', counted: true },
    { id: 2, type: 'e', amt: 4, cat: '交通', sub: '', note: '地铁', acc: '现金', date: D(29), time: '09:02', src: '手动', counted: true },
    { id: 3, type: 'e', amt: 28, cat: '餐饮', sub: '午餐', note: '公司楼下快餐', acc: '招行储蓄', date: D(29), time: '12:20', src: '手动', counted: true },
    { id: 4, type: 'e', amt: 59, cat: '日用', sub: '', note: '洗发水', acc: '招行储蓄', date: D(28), time: '19:40', src: '手动', counted: true },
    { id: 5, type: 'e', amt: 36.5, cat: '食材', sub: '', note: '水果超市', acc: '现金', date: D(28), time: '18:30', src: '手动', counted: true },
    { id: 6, type: 'e', amt: 45, cat: '娱乐', sub: '', note: '电影票', acc: '招行储蓄', date: D(27), time: '20:10', src: '手动', counted: true },
    { id: 7, type: 'e', amt: 23.6, cat: '交通', sub: '', note: '打车', acc: '招行储蓄', date: D(27), time: '22:35', src: '手动', counted: true },
    { id: 8, type: 'i', amt: 15000, cat: '其他', sub: '', note: '8月工资', acc: '招行储蓄', date: D(26), time: '10:00', src: '手动', counted: true },
    { id: 9, type: 'e', amt: 168, cat: '餐饮', sub: '午餐', note: '朋友聚餐', acc: '招行储蓄', date: D(25), time: '19:00', src: '手动', counted: true },
    { id: 10, type: 'e', amt: 50, cat: '通讯', sub: '', note: '话费充值', acc: '招行储蓄', date: D(24), time: '11:00', src: '手动', counted: true },
    { id: 11, type: 'e', amt: 132.8, cat: '食材', sub: '', note: '周末采购', acc: '招行储蓄', date: D(23), time: '15:20', src: '手动', counted: true },
    { id: 12, type: 'e', amt: 32, cat: '餐饮', sub: '饮料', note: '咖啡', acc: '现金', date: D(22), time: '14:45', src: '手动', counted: true },
    { id: 13, type: 'e', amt: 79, cat: '学习', sub: '', note: '一本书', acc: '招行储蓄', date: D(21), time: '16:30', src: '手动', counted: true },
    { id: 14, type: 'e', amt: 10, cat: '餐饮', sub: '早餐', note: '', acc: '现金', date: D(20), time: '08:00', src: '手动', counted: true },
    { id: 15, type: 'e', amt: 399, cat: '购物', sub: '', note: '秋装外套', acc: '招行储蓄', date: D(18), time: '20:00', src: '手动', counted: true },
    { id: 16, type: 'e', amt: 35, cat: '餐饮', sub: '午餐', note: '外卖', acc: '招行储蓄', date: D(15), time: '12:40', src: '手动', counted: true },
    { id: 17, type: 'i', amt: 23.4, cat: '其他', sub: '', note: '零钱通收益', acc: '现金', date: D(15), time: '06:00', src: '手动', counted: true },
    { id: 18, type: 'e', amt: 30, cat: '娱乐', sub: '', note: '视频会员', acc: '招行储蓄', date: D(12), time: '21:00', src: '手动', counted: true },
    { id: 19, type: 'e', amt: 4500, cat: '居住', sub: '', note: '9月房租', acc: '招行储蓄', date: D(10), time: '08:30', src: '手动', counted: true },
    { id: 20, type: 'e', amt: 45, cat: '日用', sub: '', note: '理发', acc: '现金', date: D(8), time: '17:00', src: '手动', counted: true },
    { id: 21, type: 'e', amt: 88.6, cat: '食材', sub: '', note: '菜市场', acc: '现金', date: D(3), time: '09:30', src: '手动', counted: true },
    { id: 22, type: 'e', amt: 26, cat: '餐饮', sub: '午餐', note: '面馆', acc: '现金', date: D(1), time: '12:10', src: '手动', counted: true },
    { id: 23, type: 'e', amt: 328, cat: '交通', sub: '打车', note: '客户拜访', acc: '招行信用卡', date: D(26), time: '14:20', src: '手动', counted: true },
    { id: 24, type: 'e', amt: 820, cat: '餐饮', sub: '请客', note: '团队聚餐', acc: '招行信用卡', date: D(24), time: '19:30', src: '手动', counted: true },
    { id: 25, type: 'e', amt: 399, cat: '购物', sub: '服饰', note: '秋装', acc: '招行信用卡', date: D(20), time: '20:05', src: '手动', counted: true },
    { id: 26, type: 'e', amt: 118, cat: '日用', sub: '个护', note: '洗护套装', acc: '招行信用卡', date: D(16), time: '18:40', src: '手动', counted: true }
  ];

  const cats = [
    { n: '餐饮', i: '餐', subs: ['早餐', '午餐', '晚餐', '请客', '零食', '饮料', '外卖'] },
    { n: '食材', i: '果', subs: ['生鲜', '米面粮油', '调味', '乳品'] },
    { n: '购物', i: '购', subs: ['服饰', '数码', '家居', '美妆'] },
    { n: '日用', i: '日', subs: ['清洁', '个护', '纸品'] },
    { n: '交通', i: '交', subs: ['公交地铁', '打车', '加油', '停车', '火车机票'] },
    { n: '居住', i: '居', subs: ['房租', '房贷', '物业', '水电', '燃气'] },
    { n: '通讯', i: '讯', subs: ['话费', '宽带', '会员'] },
    { n: '娱乐', i: '娱', subs: ['影音', '游戏', '演出', '旅行'] },
    { n: '医疗', i: '医', subs: ['门诊', '药品', '体检', '保险'] },
    { n: '学习', i: '学', subs: ['书籍', '课程', '文具'] },
    { n: '人情', i: '情', subs: ['红包', '礼物', '请客'] },
    { n: '其他', i: '他', subs: [] }
  ];

  /* V3.0：账户分级 —— 资产 / 负债 / 投资，netWorth = Σ资产 − Σ负债 */
  const accounts = [
    { n: '现金', t: '现金', cls: 'asset', bal: 486.20 },
    { n: '招行储蓄', t: '储蓄卡', cls: 'asset', bal: 32540.75 },
    { n: '招行信用卡', t: '信用卡', cls: 'debt', bal: -3280.00, limit: 30000, due: '每月 8 日', billDay: '每月 25 日' },
    { n: '某基金', t: '投资', cls: 'asset', bal: 18600.00, cost: 15000 }
  ];

  /* —— 以下为原型 SCREENS 元数据：29 条，含 SP 编号与说明 —— */
  const SCREENS = [
    ['s-onboard0', 'SP-0-01', '首次启动与权限引导', '三步引导：品牌主张 → 隐私承诺四条 → 通知权限（可选、延后）。对应 AC：全程无权限弹窗，隐私承诺原文展示。'],
    ['s-home', 'SP-0-02', '首页流水', '记账月结余卡（收入 / 支出 / 净资产）+ 按日分组账单流。对应 AC：万条账单 60fps 滚动（此为视觉参考）。'],
    ['s-add', 'SP-1-01', '记账输入页', '核心交互「点分类即保存」：金额非零点分类直接落库、toast 1.5s、自动清零、停留页面连续记账。四则运算：试输入 12.5+7.5 再点分类。金额为零点分类仅高亮。编辑态需显式保存。'],
    ['s-detail', 'SP-1-02', '账单详情', '全字段展示，含「所属记账月」与「计入收支」两个派生字段。编辑进记账页编辑态（显式保存）；删除进回收站保留 30 天。含「分割 / 标记待报销」入口。'],
    ['s-cat', 'SP-1-03', '分类管理', '一级 / 二级体系、新增、隐藏（不删数据）、合并（历史账单随迁，显示影响笔数）。分类备注 ≤30 字，截断不报错。'],
    ['s-asset', 'SP-2-01', '账户管理', '现金 / 储蓄卡 / 信用卡 / 投资四类。净资产 = Σ资产 − Σ负债。对账功能：录入实际余额生成「对账调整」账单，<b>不计入收支统计</b>（G-2）。'],
    ['s-report', 'SP-3-01', '报表页', '分类占比环形图（点击下钻）、日走势、月对比卡。空月显示空态引导（切上月可见）。'],
    ['s-backup', 'SP-4-01', '备份与恢复', '生成加密备份 → 恢复预览（账单数 / 范围 / 版本校验）→ 确认。恢复前自动生成安全备份。'],
    ['s-find', 'SP-5-01', '发现', 'V1.0 功能聚合 + V2.0 / V3.0 功能入口 + 路线图（明确标注版本）。商业化自 V4.0 起。'],
    ['s-me', 'SP-5-03', '我的（设置）', '设置与偏好：主题、外观模式、月起始日（定义 G-1 记账月）、字体三档、音效、连续记账。'],
    ['s-theme', 'SP-5-02', '主题', '10 套内置主题全部免费，点选即切换并即时生效。完整色板与浅深两态见《12-设计规范系统》。'],

    ['s-addplus', 'SP-1-04', '转账 / 借出 / 借入', 'G-6 边界：涉及两个账户的记账不走「点分类即保存」。双账户选择（转出 / 转入），借贷侧自动生成一条镜像分录。<b>转账不计入收支统计</b>（G-2）。'],
    ['s-split', 'SP-1-05', '分割交易编辑器', '一笔消费拆到多个分类。父子结构：父单金额 = Σ子项，<b>不等则不允许保存</b>。子项可各自设分类 / 备注 / 报销标记。'],
    ['s-claim', 'SP-1-06', '报销中心', '待报销 / 已提交 / 已到账三态。报销到账时生成收入并自动冲销原支出（不重复计入收支）。'],
    ['s-cardbill', 'SP-2-02', '信用卡账单详情', '账单周期（账单日 → 还款日）、本期应还、最低还款、账单内明细。欠款余额为唯一权威可写量，可用额度为派生只读量。'],
    ['s-remind', 'SP-5-04', '提醒中心', '三类提醒聚合：预算阈值 / 还款账单 / 周期记账待确认。分级通知（G-3）：静默 = 只进中心不响铃；响铃 = 系统通知。'],
    ['s-rule', 'SP-5-05', '自动规则', 'IF 条件（商户包含 / 金额区间 / 时间 / 账户）→ THEN 动作（归类 / 打标签 / 改账户 / 备注模板）。规则命中可回溯、可撤销。'],
    ['s-goal', 'SP-5-06', '储蓄目标与基金', '沉淀基金（大额支出按月摊存）+ 储蓄目标（目标额 / 期限 / 月需存）。目标隔离于可花余额，不参与「安全可花」计算基数。'],
    ['s-card', 'SP-5-07', '首页卡片自定义', '勾选首页常驻卡片与排序。可选：记账月结余 / 预算进度 / 安全可花 / 目标进度 / 净值 / 近 7 天热力图。'],

    ['s-invest', 'SP-2-04', '投资持仓', '持仓列表：名称 / 份额 / 成本 / 市值 / 浮动盈亏。汇总卡含总市值、总成本、累计收益与收益率。行情数据源为开放问题。'],
    ['s-loan', 'SP-2-05', '贷款摊销', '等额本息 / 等额本金两模式，展示月供、利息总额、已还期数与剩余本金。还款计划表可逐期查看本金 / 利息拆分。'],
    ['s-networth', 'SP-2-06', '净值追踪与资产估值', '净值走势（资产 − 负债）、资产构成变化。非现金资产支持手动估值与折旧（房产 / 车）。'],
    ['s-sankey', 'SP-3-03', '资金流向（Sankey）', '收入 → 各分类 → 结余的三段式流向。直观呈现「钱从哪来、到哪去、剩多少」。'],
    ['s-cross', 'SP-3-04', '交叉分析', '维度 × 维度的透视：分类 × 月份 / 账户 × 分类 / 商户 × 金额。用于回答「哪个账户在哪一类上花得最多」。'],
    ['s-age', 'SP-3-05', '资金年龄', 'FIFO 口径：当前花掉的每一块钱平均在账户里躺了多少天。数值越大说明财务缓冲越厚。'],
    ['s-budget', 'SP-5-09', '预算（四种方法论）', '信封预算 / 零基预算 / 50-30-20 / 分类限额四选一或混用。进度条三级着色（正常 / 接近 / 超支）。'],
    ['s-family', 'SP-5-10', '家庭与成员', '共享账本、成员角色（owner / member / viewer）、成员消费分摊。G-5：家庭共享与记账伙伴是两套边界，不共用。'],
    ['s-api', 'SP-5-11', '开放接口（API / MCP）', '本地 API 开关、访问令牌、可读可写范围限定。MCP 服务供 LLM 客户端读取账本（默认只读）。'],
    ['s-desk', 'SP-6-01', '桌面端与多端', '四端能力矩阵：手机 / 平板 / 桌面 / Web。桌面端侧重批量录入、报表打印与全键盘操作。']
  ];

  /* ========== 10 套主题（色值取自 theme_registry.dart 权威值） ========== */
  const THEMES = [
    ['qingci', '青瓷', '品牌识别色 · 青绿 × 蜜桃', '#14B8A6', '#FF6B6B'],
    ['dianlan', '靛蓝', '沉稳 · 深蓝 × 琥珀', '#3B82F6', '#F59E0B'],
    ['zhuqing', '竹青', '素雅 · 草绿 × 藤紫', '#4ADE80', '#A78BFA'],
    ['haiyan', '海盐', '深邃 · 青蓝 × 珊瑚', '#06B6D4', '#FB7185'],
    ['ouhe', '藕荷', '柔美 · 藕紫 × 沙金', '#A78BFA', '#FBBF24'],
    ['taoyao', '桃夭', '浪漫 · 桃粉 × 青碧', '#F472B6', '#2DD4BF'],
    ['feiying', '绯樱', '古朴 · 绯红 × 松绿', '#EF4444', '#10B981'],
    ['xinghuang', '杏黄', '温暖 · 杏黄 × 湖蓝', '#F59E0B', '#38BDF8'],
    ['doulv', '豆绿', '清新 · 豆绿 × 藤紫', '#84CC16', '#C084FC'],
    ['subai', '素白', '默认主题 · 炭黑 × 橘红', '#3F3F46', '#FB923C']
  ];
  let curTheme = 'subai', curMode = 'system';

  /* ========== 12 分类色（外化为 CSS 变量，值取 categoryColorMap 权威值） ========== */
  const CATVAR = {
    '餐饮': '--cat-food', '食材': '--cat-grocery', '购物': '--cat-shopping', '日用': '--cat-daily',
    '交通': '--cat-transport', '居住': '--cat-housing', '通讯': '--cat-telecom', '娱乐': '--cat-entertainment',
    '医疗': '--cat-medical', '学习': '--cat-learning', '人情': '--cat-social', '其他': '--cat-other'
  };
  const CATCOL = new Proxy({}, {
    get: (_, k) => (CATVAR[k] ? `var(${CATVAR[k]})` : 'var(--cat-other)')
  });
  /* 需要真实色值的地方（SVG stroke / canvas）走这里 */
  const CATHEX = () => {
    const cs = getComputedStyle(document.documentElement);
    const o = {};
    Object.keys(CATVAR).forEach(k => { o[k] = cs.getPropertyValue(CATVAR[k]).trim() || '#888780'; });
    return o;
  };

  /* ========== 工具 ========== */
  const $ = (id) => document.getElementById(id);
  const fmt = (v) => Number(v).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const hex = (h) => { const s = h.replace('#', ''); return [0, 2, 4].map(i => parseInt(s.slice(i, i + 2), 16)); };
  const mix = (a, b, t) => '#' + hex(a).map((v, i) => Math.round(v + (hex(b)[i] - v) * t).toString(16).padStart(2, '0')).join('');
  const isDark = () => curMode === 'dark' || (curMode === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);

  /* G-7 余额遮蔽：单点临时显示 5 秒 */
  let balancesHidden = false, revealUntil = {}, revealTimer = {};
  const isRevealed = (k) => balancesHidden && revealUntil[k] && Date.now() < revealUntil[k];
  function tapReveal(key) {
    if (!balancesHidden) return;
    revealUntil[key] = Date.now() + 5000;
    clearTimeout(revealTimer[key]);
    revealTimer[key] = setTimeout(() => { delete revealUntil[key]; renderAssets(); }, 5000);
    renderAssets();
  }

  let cur = 's-home', editId = null, expr = '', pickedCat = null, txType = 'e', backups = [];
  let detailId = null, keepOnAdd = true;

  /* ========== 页面骨架（照原型 1:1，仅把品牌层换成令牌层） ========== */
  const NAV = (opts) => {
    const o = opts || {};
    const bk = o.bk ? `<span class="bk" onclick="${o.bk.on}">‹</span>` : '<span class="bk" style="visibility:hidden"></span>';
    const ttl = o.pad ? `<span class="ttl" style="padding-left:4px">${o.ttl}</span>` : `<span class="ttl">${o.ttl}</span>`;
    const act = o.act ? `<span class="act" onclick="${o.act.on}">${o.act.label}</span>` : '';
    return `<div class="statusbar"><span>9:41</span><span>5G ▮▮▮</span></div>
      <div class="navbar">${bk}${ttl}${act}</div>`;
  };
  const FAB = `<button class="fab" onclick="go('s-add')">＋</button>`;

  const PAGES = {
    's-onboard0': `<div class="statusbar"><span>9:41</span><span>5G ▮▮▮</span></div>
      <div class="scroll" style="padding:0">
        <div class="onboard" id="onboard">
          <div class="ob-step on">
            <div class="ob-logo">记</div>
            <h2>3 秒，记一笔</h2>
            <p class="sub">点分类即保存，比传统记账少一步<br>支持四则运算 · 离线全功能</p>
            <div class="ob-dots"><i class="on"></i><i></i><i></i></div>
            <button class="btn pri" onclick="obNext(1)">开始使用</button>
          </div>
          <div class="ob-step">
            <div class="ob-logo" style="background:var(--surface-2);color:var(--ink-2)">✓</div>
            <h2>四条承诺</h2>
            <div class="promise-list">
              <div class="mrow"><span class="t1" style="font-size:13px">无广告、无开屏</span></div>
              <div class="mrow"><span class="t1" style="font-size:13px">数据只存在你的手机里</span></div>
              <div class="mrow"><span class="t1" style="font-size:13px">不申请与记账无关的权限</span></div>
              <div class="mrow"><span class="t1" style="font-size:13px">数据随时导出，永不锁定</span></div>
            </div>
            <div class="ob-dots"><i></i><i class="on"></i><i></i></div>
            <button class="btn pri" onclick="obNext(2)">我了解了</button>
          </div>
          <div class="ob-step">
            <div class="ob-logo" style="font-size:22px">🔔</div>
            <h2>需要通知权限吗？</h2>
            <p class="sub">当前版本不需要任何权限。<br>未来的预算超支提醒（V2.0）会用到通知，<br>到时再开启也完全来得及。</p>
            <div class="ob-dots"><i></i><i></i><i class="on"></i></div>
            <button class="btn pri" onclick="obDone()">暂不开启，直接进入</button>
            <button class="btn" style="margin-top:10px" onclick="obDone()">好，现在开启</button>
          </div>
        </div>
      </div>`,

    's-home': `<div class="statusbar"><span>9:41</span><span>5G ▮▮▮</span></div>
      <div class="scroll" id="flowScroll">
        <div class="flow-head">
          <span class="month-pick" onclick="toast('记账月：按「我的 → 月起始日」定义。当前起始日 = 1 号')">2026年9月 ▾</span>
          <span style="font-size:11px;color:var(--muted);margin-left:6px">记账月 · 9/1–9/30</span>
        </div>
        <div class="balance-card">
          <span style="font-size:11px;opacity:.75">本月结余</span>
          <div style="font-size:26px;font-weight:500" id="bc-bal">--</div>
          <div class="bs">
            <div><span>收入</span><b id="bc-in">--</b></div>
            <div><span>支出</span><b id="bc-out">--</b></div>
            <div><span>净资产</span><b id="bc-net">--</b></div>
          </div>
        </div>
        <div id="flowList"></div>
      </div>${FAB}`,

    's-add': `${NAV({ bk: { on: 'cancelAdd()' }, ttl: '记一笔', act: { label: '支出', on: 'toggleType()' } }).replace('class="act"', 'class="act" id="type-sw"').replace('<span class="ttl">记一笔</span>', '<span class="ttl" id="add-title">记一笔</span>')}
      <div class="edit-banner" id="edit-banner">正在编辑已有账单 · 点分类后需按「保存」生效</div>
      <div class="amt-zone">
        <div class="amt-expr" id="amt-expr"></div>
        <div class="amt-main"><span class="cur">¥</span><span id="amt-main">0.00</span></div>
      </div>
      <div class="cat-grid" id="catGrid"></div>
      <div class="more-panel" id="morePanel"></div>
      <div class="prop-bar">
        <span class="pchip" onclick="toast('账户选择（原型演示）')">现金 ▾</span>
        <span class="pchip" onclick="toast('日期选择（原型演示）')">今天 ▾</span>
        <span class="pchip" onclick="toast('备注输入（原型演示）')">＋ 备注</span>
        <span class="pchip" onclick="openAddPlus()">⋯ 更多</span>
      </div>
      <div class="keypad" id="keypad">
        <button class="kb" onclick="kb('7')">7</button><button class="kb" onclick="kb('8')">8</button><button class="kb" onclick="kb('9')">9</button><button class="kb op" onclick="kb('÷')">÷</button>
        <button class="kb" onclick="kb('4')">4</button><button class="kb" onclick="kb('5')">5</button><button class="kb" onclick="kb('6')">6</button><button class="kb op" onclick="kb('×')">×</button>
        <button class="kb" onclick="kb('1')">1</button><button class="kb" onclick="kb('2')">2</button><button class="kb" onclick="kb('3')">3</button><button class="kb op" onclick="kb('−')">−</button>
        <button class="kb" onclick="kb('.')">.</button><button class="kb" onclick="kb('0')">0</button><button class="kb" onclick="kb('⌫')">⌫</button><button class="kb op" onclick="kb('+')">＋</button>
        <button class="kb ok" id="btn-save" onclick="commitEdit()">保存</button>
      </div>`,

    's-detail': `${NAV({ bk: { on: "go('s-home')" }, ttl: '账单详情', act: { label: '编辑', on: 'startEdit()' } })}
      <div class="scroll" id="detailBody"></div>`,

    's-cat': `${NAV({ bk: { on: "go('s-me')" }, ttl: '分类管理', act: { label: '＋ 新增', on: 'addCat()' } })}
      <div class="scroll" id="catBody"></div>`,

    's-asset': `${NAV({ pad: true, ttl: '资产', act: { label: '隐藏余额', on: 'toggleHideBal()' } }).replace('class="act"', 'class="act" id="bal-eye"')}
      <div class="scroll" id="assetBody"></div>${FAB}`,

    's-report': `${NAV({ pad: true, ttl: '<span class="month-pick">2026年9月 ▾</span>' })}
      <div class="scroll" id="reportBody"></div>${FAB}`,

    's-find': `${NAV({ pad: true, ttl: '发现' })}
      <div class="scroll">
        <div class="mcard">
          <div class="mrow" onclick="go('s-backup')"><div class="icoc">备</div><div class="grow"><div class="t1">备份与恢复</div><div class="t2">生成加密备份 · 恢复到任意设备</div></div><span class="rt">›</span></div>
          <div class="mrow" onclick="go('s-cat')"><div class="icoc">类</div><div class="grow"><div class="t1">分类管理</div><div class="t2">12 个一级 · 41 个二级 · 自定义图标与备注</div></div><span class="rt">›</span></div>
        </div>
        <div class="card">
          <div class="sec">V2.0 · 交易精度与主动管家</div>
          <div class="mrow lnk" onclick="go('s-remind')"><div class="grow"><div class="t1">提醒中心</div><div class="t2">预算 / 账单 / 周期记账三类提醒，分级通知</div></div><span class="rt">›</span></div>
          <div class="mrow lnk" onclick="go('s-rule')"><div class="grow"><div class="t1">自动规则</div><div class="t2">商家记忆 · 自动归类 · 自动打标签</div></div><span class="rt">›</span></div>
          <div class="mrow lnk" onclick="go('s-goal')"><div class="grow"><div class="t1">储蓄目标与基金</div><div class="t2">沉淀基金 · 目标进度 · 自动划拨</div></div><span class="rt">›</span></div>
          <div class="mrow lnk" onclick="go('s-card')"><div class="grow"><div class="t1">首页卡片自定义</div><div class="t2">选择首页常驻卡片与顺序</div></div><span class="rt">›</span></div>
        </div>
        <div class="card">
          <div class="sec">V3.0 · 资产完整性与方法论</div>
          <div class="mrow lnk" onclick="go('s-invest')"><div class="grow"><div class="t1">投资持仓</div><div class="t2">持仓成本 · 浮盈浮亏 · 净值曲线</div></div><span class="rt">›</span></div>
          <div class="mrow lnk" onclick="go('s-loan')"><div class="grow"><div class="t1">贷款摊销</div><div class="t2">等额本息 / 等额本金 · 还款计划表</div></div><span class="rt">›</span></div>
          <div class="mrow lnk" onclick="go('s-networth')"><div class="grow"><div class="t1">净值追踪</div><div class="t2">资产 − 负债走势 · 构成变化</div></div><span class="rt">›</span></div>
          <div class="mrow lnk" onclick="go('s-sankey')"><div class="grow"><div class="t1">资金流向图</div><div class="t2">收入 → 分类 → 结余的桑基流向</div></div><span class="rt">›</span></div>
          <div class="mrow lnk" onclick="go('s-age')"><div class="grow"><div class="t1">资金年龄</div><div class="t2">花掉的一块钱平均停留了几天</div></div><span class="rt">›</span></div>
          <div class="mrow lnk" onclick="go('s-family')"><div class="grow"><div class="t1">家庭与成员</div><div class="t2">共享账本 · 成员权限 · 记账伙伴</div></div><span class="rt">›</span></div>
        </div>
        <div class="card">
          <div class="sec">即将到来</div>
          <div class="cmp-row"><span>预算管理 · 周期记账 <span class="tag v2">V2.0</span></span></div>
          <div class="cmp-row"><span>规则引擎 · 提醒中心 <span class="tag v2">V2.0</span></span></div>
          <div class="cmp-row"><span>四端云同步 · 家庭共享 <span class="tag v2">V2.0</span></span></div>
          <div class="cmp-row"><span>投资持仓 · 净值追踪 <span class="tag v3">V3.0</span></span></div>
          <div class="cmp-row"><span>开放 API / MCP · 桌面端 <span class="tag v3">V3.0</span></span></div>
        </div>
        <div class="card note">
          <div class="body">本产品无广告、无开屏、不申请无关权限、数据仅存本地。<b>商业化（付费）自 V4.0 起</b>，V1.0–V3.0 全部功能免费。功能排期以实际发布为准。</div>
        </div>
      </div>${FAB}`,

    's-backup': `${NAV({ bk: { on: "go('s-find')" }, ttl: '备份与恢复', act: { label: '生成备份', on: 'makeBackup()' } })}
      <div class="scroll" id="backupBody"></div>`,

    's-me': `${NAV({ pad: true, ttl: '我的' })}
      <div class="scroll">
        <div class="card hero-soft">
          <div class="icoc" style="background:var(--surface)">本地</div>
          <div>
            <div style="font-size:14px;font-weight:500">本地模式 · 未注册</div>
            <div style="font-size:11px;color:var(--ink-2);margin-top:2px">数据仅保存在这台设备 · 卸载前请先备份</div>
          </div>
        </div>
        <div class="mcard">
          <div class="mrow" onclick="go('s-find')"><div class="icoc">✦</div><div class="grow"><div class="t1">更多功能与路线图</div><div class="t2">V1.0 功能聚合 · V2.0 / V3.0 预告</div></div><span class="rt">›</span></div>
          <div class="mrow"><div class="icoc">月</div><div class="grow"><div class="t1">月起始日</div><div class="t2">定义 G-1 记账月 · 切换即时生效</div></div>
            <select id="monthStart" onchange="toast('月起始日已更新')"></select></div>
          <div class="mrow" onclick="go('s-theme')"><div class="icoc">主</div><div class="grow"><div class="t1">主题</div><div class="t2">10 套内置 · 全部免费 · 含暗色</div></div><span class="rt pk" id="me-theme">素白 ›</span></div>
          <div class="mrow"><div class="icoc">明</div><div class="grow"><div class="t1">外观</div><div class="t2">跟随系统 / 浅色 / 深色</div></div>
            <select id="themeMode" onchange="setThemeMode(this.value)">
              <option value="system" selected>跟随系统</option><option value="light">浅色</option><option value="dark">深色</option></select></div>
          <div class="mrow"><div class="icoc">字</div><div class="grow"><div class="t1">字体大小</div></div>
            <select onchange="setScale(this.value)">
              <option value="0.95">小</option><option value="1" selected>标准</option><option value="1.08">大</option></select></div>
          <div class="mrow"><div class="icoc">音</div><div class="grow"><div class="t1">记账确认音效</div></div><div class="sw" onclick="this.classList.toggle('on')"></div></div>
          <div class="mrow"><div class="icoc">连</div><div class="grow"><div class="t1">保存后留在记账页</div><div class="t2">关闭则保存后返回流水</div></div><div class="sw on" onclick="toggleKeep(this)"></div></div>
        </div>
        <div class="mcard">
          <div class="mrow" onclick="go('s-backup')"><div class="icoc">备</div><div class="grow"><div class="t1">备份与恢复</div></div><span class="rt">›</span></div>
          <div class="mrow" onclick="go('s-cat')"><div class="icoc">类</div><div class="grow"><div class="t1">分类管理</div></div><span class="rt">›</span></div>
        </div>
        <div class="mcard">
          <div class="mrow" onclick="go('s-remind')"><div class="icoc">铃</div><div class="grow"><div class="t1">提醒中心</div><div class="t2">预算 / 账单 / 周期三类 · 分级通知</div></div><span class="rt">5 条待处理 ›</span></div>
          <div class="mrow" onclick="go('s-rule')"><div class="icoc">则</div><div class="grow"><div class="t1">自动规则</div><div class="t2">5 条规则 · 4 条启用中</div></div><span class="rt">›</span></div>
          <div class="mrow" onclick="go('s-budget')"><div class="icoc">预</div><div class="grow"><div class="t1">预算</div><div class="t2">四种方法论 · 本月已用 87%</div></div><span class="rt">›</span></div>
          <div class="mrow" onclick="go('s-goal')"><div class="icoc">标</div><div class="grow"><div class="t1">储蓄目标与基金</div><div class="t2">4 个目标 · 沉淀基金按月摊存</div></div><span class="rt">›</span></div>
          <div class="mrow" onclick="go('s-card')"><div class="icoc">卡</div><div class="grow"><div class="t1">首页卡片自定义</div></div><span class="rt">›</span></div>
        </div>
        <div class="mcard">
          <div class="mrow" onclick="go('s-family')"><div class="icoc">家</div><div class="grow"><div class="t1">家庭与成员</div><div class="t2">共享账本 · 3 名成员（V3.0）</div></div><span class="rt">›</span></div>
          <div class="mrow" onclick="go('s-api')"><div class="icoc">开</div><div class="grow"><div class="t1">开放接口 · MCP</div><div class="t2">本地 API · 默认关闭（V3.0）</div></div><span class="rt">›</span></div>
          <div class="mrow" onclick="go('s-desk')"><div class="icoc">端</div><div class="grow"><div class="t1">桌面端与多端</div><div class="t2">四端能力矩阵（V3.0）</div></div><span class="rt">›</span></div>
        </div>
        <div class="mcard">
          <div class="mrow"><div class="icoc o">隐</div><div class="grow"><div class="t1">隐私承诺</div><div class="t2">无广告 · 无开屏 · 权限最小化</div></div><span class="rt">›</span></div>
          <div class="mrow"><div class="icoc o">版</div><div class="grow"><div class="t1">版本</div></div><span class="rt">v1.0.0 (100)</span></div>
        </div>
      </div>${FAB}`,

    's-theme': `${NAV({ bk: { on: "go('s-me')" }, ttl: '主题' })}
      <div class="scroll" id="themeBody"></div>`,

    /* ---- V2.0 ---- */
    's-addplus': `${NAV({ bk: { on: "go('s-add')" }, ttl: '转账', act: { label: '保存', on: 'saveAddPlus()' } }).replace('<span class="ttl">转账</span>', '<span class="ttl" id="ap-title">转账</span>')}
      <div class="scroll" id="addPlusBody"></div>`,

    's-split': `${NAV({ bk: { on: "go('s-add')" }, ttl: '分割这笔账单', act: { label: '完成', on: 'saveSplit()' } })}
      <div class="scroll" id="splitBody"></div>`,

    's-claim': `${NAV({ bk: { on: "go('s-find')" }, ttl: '报销中心' })}
      <div class="scroll" id="claimBody"></div>`,

    's-cardbill': `${NAV({ bk: { on: "go('s-asset')" }, ttl: '信用卡账单' })}
      <div class="scroll" id="cardBillBody"></div>`,

    's-remind': `${NAV({ bk: { on: "go('s-find')" }, ttl: '提醒中心', act: { label: '设置', on: "toast('提醒设置（原型演示）')" } })}
      <div class="seg" id="remindSeg" style="margin:8px 14px 0">
        <div class="on" onclick="segRemind(this,'全部')">全部</div>
        <div onclick="segRemind(this,'预算')">预算</div>
        <div onclick="segRemind(this,'账单')">账单</div>
        <div onclick="segRemind(this,'周期')">周期</div>
      </div>
      <div class="scroll" id="remindBody" style="padding-top:8px"></div>`,

    's-rule': `${NAV({ bk: { on: "go('s-find')" }, ttl: '自动规则', act: { label: '＋ 新建', on: "toast('新建规则（原型演示）')" } })}
      <div class="scroll" id="ruleBody"></div>`,

    's-goal': `${NAV({ bk: { on: "go('s-find')" }, ttl: '储蓄目标与基金', act: { label: '＋ 新建', on: "toast('新建目标（原型演示）')" } })}
      <div class="scroll" id="goalBody"></div>`,

    's-card': `${NAV({ bk: { on: "go('s-find')" }, ttl: '首页卡片自定义' })}
      <div class="scroll" id="cardCfgBody"></div>`,

    /* ---- V3.0 ---- */
    's-invest': `${NAV({ bk: { on: "go('s-asset')" }, ttl: '投资持仓', act: { label: '＋ 持仓', on: "toast('录入持仓（原型演示）')" } })}
      <div class="scroll" id="investBody"></div>`,

    's-loan': `${NAV({ bk: { on: "go('s-asset')" }, ttl: '贷款摊销' })}
      <div class="scroll" id="loanBody"></div>`,

    's-networth': `${NAV({ bk: { on: "go('s-asset')" }, ttl: '净值追踪' })}
      <div class="scroll" id="netWorthBody"></div>`,

    's-sankey': `${NAV({ bk: { on: "go('s-report')" }, ttl: '资金流向' })}
      <div class="scroll" id="sankeyBody"></div>`,

    's-cross': `${NAV({ bk: { on: "go('s-report')" }, ttl: '交叉分析' })}
      <div class="scroll" id="crossBody"></div>`,

    's-age': `${NAV({ bk: { on: "go('s-report')" }, ttl: '资金年龄' })}
      <div class="scroll" id="ageBody"></div>`,

    's-budget': `${NAV({ bk: { on: "go('s-find')" }, ttl: '预算', act: { label: '方法', on: "toast('切换方法（原型演示）')" } })}
      <div class="scroll" id="budgetBody"></div>`,

    's-family': `${NAV({ bk: { on: "go('s-find')" }, ttl: '家庭与成员', act: { label: '邀请', on: "toast('邀请成员（原型演示）')" } })}
      <div class="scroll" id="familyBody"></div>`,

    's-api': `${NAV({ bk: { on: "go('s-find')" }, ttl: '开放接口' })}
      <div class="scroll" id="apiBody"></div>`,

    's-desk': `${NAV({ bk: { on: "go('s-find')" }, ttl: '桌面端与多端' })}
      <div class="scroll" id="deskBody"></div>`
  };

  function mountPages() {
    const host = $('screens');
    host.innerHTML = SCREENS.map(s => `<div class="screen" id="${s[0]}">${PAGES[s[0]] || ''}</div>`).join('');
  }

  /* ========== 路由 ========== */
  function go(s) {
    document.querySelectorAll('.screen').forEach(el => el.classList.remove('on'));
    const el = $(s); if (!el) return;
    el.classList.add('on');
    const isTab = ['s-home', 's-report', 's-asset', 's-me'].includes(s);
    $('tabbar').style.display = isTab ? 'flex' : 'none';
    document.querySelectorAll('.tab').forEach(t => t.classList.toggle('on', t.dataset.s === s));
    cur = s;
    const R = {
      's-home': renderFlow, 's-report': renderReport, 's-asset': renderAssets, 's-cat': renderCat,
      's-backup': renderBackup, 's-theme': renderTheme, 's-split': renderSplit, 's-claim': renderClaim,
      's-cardbill': renderCardBill, 's-remind': renderRemind, 's-rule': renderRule, 's-goal': renderGoal,
      's-card': renderCardCfg, 's-invest': renderInvest, 's-loan': renderLoan, 's-networth': renderNetWorth,
      's-sankey': renderSankey, 's-cross': renderCross, 's-age': renderAge, 's-budget': renderBudget,
      's-family': renderFamily, 's-api': renderApi, 's-desk': renderDesk
    };
    if (R[s]) R[s]();
    if (s === 's-add' && !editId) { expr = ''; pickedCat = null; updateAmt(); renderGrid(); }
    const meta = SCREENS.find(x => x[0] === s);
    if (meta) { $('side-title').textContent = meta[1] + ' ' + meta[2]; $('side-desc').innerHTML = meta[3]; }
    document.querySelectorAll('.chip').forEach(c => c.classList.toggle('on', c.dataset.s === s));
    if (location.hash.slice(1) !== s) { try { history.replaceState(null, '', '#' + s); } catch (e) { location.hash = s; } }
  }

  function toast(msg) {
    const t = $('toast'); t.textContent = msg; t.classList.add('show');
    clearTimeout(t._tm); t._tm = setTimeout(() => t.classList.remove('show'), 1600);
  }
  function closeModal() { $('mask').classList.remove('show'); }
  function openModal(html) { $('modalBody').innerHTML = html; $('mask').classList.add('show'); }

  /* ========== SP-1-01 记账页 ========== */
  function evalExpr() {
    let e = expr.replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-');
    if (!e) return 0;
    e = e.replace(/[+\-*/.]+$/, '');
    if (!e) return 0;
    if (!/^[0-9+\-*/.]+$/.test(e)) return NaN;
    try { const v = Function('"use strict";return(' + e + ')')(); return isNaN(v) ? NaN : Math.round(v * 100) / 100; } catch (err) { return NaN; }
  }
  function updateAmt() {
    $('amt-expr').textContent = expr || '';
    const v = evalExpr();
    $('amt-main').textContent = isNaN(v) ? '—' : fmt(v || 0);
  }
  function kb(k) {
    if (k === '⌫') { expr = expr.slice(0, -1); }
    else {
      if (expr.length > 18) return;
      if ('÷×−+'.includes(k) && expr === '') { if (k === '−') expr = '-'; return; }
      expr += k;
    }
    updateAmt();
  }
  function renderGrid() {
    const g = $('catGrid'); if (!g) return;
    g.innerHTML = '';
    cats.slice(0, 8).forEach(c => {
      const d = document.createElement('div');
      d.className = 'cat-cell' + (pickedCat === c.n ? ' on' : '');
      d.innerHTML = `<div class="ci" style="${pickedCat === c.n ? '' : 'color:' + CATCOL[c.n] + ';background:color-mix(in srgb, ' + CATCOL[c.n] + ' 13%, transparent)'}">${c.i}</div><span>${c.n}</span>`;
      d.onclick = () => pickCat(c.n);
      g.appendChild(d);
    });
    const more = document.createElement('div');
    more.className = 'cat-cell';
    more.innerHTML = '<div class="ci" style="border:1.5px dashed var(--line);background:var(--surface)">⋯</div><span>更多</span>';
    more.onclick = () => $('morePanel').classList.toggle('show');
    g.appendChild(more);
    const mp = $('morePanel'); mp.innerHTML = '';
    const mpG = document.createElement('div'); mpG.className = 'mp-grid';
    cats.forEach(c => {
      const d = document.createElement('div'); d.className = 'cat-cell';
      d.innerHTML = `<div class="ci" style="color:${CATCOL[c.n]};background:color-mix(in srgb, ${CATCOL[c.n]} 13%, transparent)">${c.i}</div><span style="font-size:10px">${c.n}</span>`;
      d.onclick = () => { pickCat(c.n); mp.classList.remove('show'); };
      mpG.appendChild(d);
    });
    mp.appendChild(mpG);
  }
  function needExplicitConfirm(name) { return ['转账', '借出', '借入', '还款', '报销', '投资'].includes(name); }
  function pickCat(name) {
    const v = evalExpr();
    pickedCat = name; renderGrid();
    if (editId) return;
    if (v > 0) {
      if (needExplicitConfirm(name)) { toast('「' + name + '」涉及多账户，需确认后保存'); openAddPlus('transfer'); return; }
      tx.unshift({ id: Date.now(), type: txType, amt: v, cat: name, sub: '', note: '', acc: '现金', date: D(29), time: '15:08', src: '手动', counted: true });
      expr = ''; pickedCat = null; updateAmt(); renderGrid();
      if (keepOnAdd) toast(`已记 ¥${fmt(v)} ${name}${txType === 'i' ? '（收入）' : ''}`);
      else { toast(`已记 ¥${fmt(v)} ${name}`); go('s-home'); }
    } else toast('请先输入金额');
  }
  function toggleType() {
    txType = txType === 'e' ? 'i' : 'e';
    const el = $('type-sw'); if (!el) return;
    el.textContent = txType === 'e' ? '支出' : '收入';
    el.style.color = txType === 'e' ? 'var(--primary-ink)' : 'var(--ink)';
  }
  function cancelAdd() {
    editId = null;
    $('edit-banner').classList.remove('show');
    $('btn-save').classList.remove('show');
    $('add-title').textContent = '记一笔';
    go('s-home');
  }
  function startEdit() {
    const t = tx.find(x => x.id === detailId); if (!t) return;
    editId = t.id; expr = String(t.amt); pickedCat = t.cat; txType = t.type;
    go('s-add');
    $('edit-banner').classList.add('show'); $('btn-save').classList.add('show');
    $('add-title').textContent = '编辑账单';
    $('type-sw').textContent = t.type === 'e' ? '支出' : '收入';
    updateAmt(); renderGrid();
  }
  function commitEdit() {
    const t = tx.find(x => x.id === editId); const v = evalExpr();
    if (!t || !v || v <= 0) { toast('金额无效'); return; }
    t.amt = v; t.cat = pickedCat || t.cat; t.type = txType;
    toast('账单已更新'); cancelAdd();
  }

  /* ========== SP-1-02 账单详情 ========== */
  function openDetail(id) {
    detailId = id; const t = tx.find(x => x.id === id); if (!t) return;
    const counted = t.counted !== false;
    const rows = [
      ['类型', t.type === 'e' ? '支出' : '收入'],
      ['金额', '¥' + fmt(t.amt)],
      ['分类', t.cat + (t.sub ? ' · ' + t.sub : '')],
      ['账户', t.acc],
      ['记账日', t.date + ' ' + t.time],
      ['所属记账月', '2026年9月（起始日 1 号）'],
      ['备注', t.note || '—'],
      ['来源', t.src],
      ['计入收支', counted ? '是' : '<span class="muted">否 · 仅修正余额</span>']
    ];
    $('detailBody').innerHTML = `
      <div class="card" style="text-align:center;padding:22px">
        <div style="font-size:34px;font-weight:500;color:${t.type === 'e' ? 'var(--ink)' : 'var(--sem-inc)'}">${t.type === 'e' ? '-' : '+'}¥${fmt(t.amt)}</div>
        <div style="font-size:13px;color:var(--muted);margin-top:4px">${t.cat}${t.sub ? ' · ' + t.sub : ''}${t.note ? ' · ' + t.note : ''}</div>
        ${counted ? '' : '<div style="display:inline-block;margin-top:8px;font-size:11px;background:var(--surface-2);color:var(--ink-2);border-radius:6px;padding:3px 10px">不计入收支统计与预算</div>'}
      </div>
      <div class="mcard">${rows.map(r => `<div class="mrow" style="cursor:default"><div class="grow act">${r[0]}</div><div class="act">${r[1]}</div></div>`).join('')}</div>
      <div class="mcard">
        <div class="mrow" onclick="go('s-split')"><div class="icoc">分</div><div class="grow"><div class="t1">分割这笔账单</div><div class="t2">一笔消费拆到多个分类 · 金额须对平</div></div><span class="rt">V2.0 ›</span></div>
        <div class="mrow" onclick="go('s-claim')"><div class="icoc">报</div><div class="grow"><div class="t1">标记为待报销</div><div class="t2">进入报销中心，到账后自动冲销</div></div><span class="rt">V2.0 ›</span></div>
      </div>
      <button class="btn dan" style="width:100%;height:42px;margin-top:6px" onclick="askDel()">删除这笔账单</button>
      <div class="footc">删除后进入回收站（保留 30 天），期间可恢复</div>`;
    go('s-detail');
  }
  function askDel() {
    openModal(`<h3>删除账单？</h3><p>账单将移入回收站并保留 30 天，期间可随时恢复。30 天后自动清除。</p>
      <div class="mins">回收站不进云同步、不占其他设备空间；恢复后重新参与统计。</div>
      <div class="btns"><button class="btn" onclick="closeModal()">取消</button><button class="btn dan" onclick="doDel()">删除</button></div>`);
  }
  function doDel() { tx = tx.filter(x => x.id !== detailId); closeModal(); toast('已移入回收站，30 天内可恢复'); go('s-home'); }

  /* ========== SP-0-02 首页流水 ========== */
  function dayLabel(d) {
    if (d === D(29)) return '今天';
    if (d === D(28)) return '昨天';
    const wd = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return d.slice(5).replace('-', '月') + '日 ' + wd[new Date(d).getDay()];
  }
  function renderFlow() {
    /* G-2：只有 counted === true 的账单进入收支统计与报表 */
    const counted = tx.filter(t => t.counted !== false);
    const tin = counted.filter(t => t.type === 'i').reduce((s, t) => s + t.amt, 0);
    const tout = counted.filter(t => t.type === 'e').reduce((s, t) => s + t.amt, 0);
    const nw = accounts.reduce((s, a) => s + a.bal, 0);
    $('bc-in').textContent = '+' + fmt(tin);
    $('bc-out').textContent = '-' + fmt(tout);
    $('bc-bal').textContent = (tin - tout >= 0 ? '+' : '') + fmt(tin - tout);
    $('bc-net').textContent = '¥' + fmt(nw);
    const dates = [...new Set(tx.map(t => t.date))].sort().reverse();
    $('flowList').innerHTML = dates.map(d => `
      <div class="daygroup"><div class="daylabel">${dayLabel(d)}</div>
        ${tx.filter(t => t.date === d).map(t => `
          <div class="txrow" onclick="openDetail(${t.id})">
            <div class="icoc" style="color:${CATCOL[t.cat]};background:color-mix(in srgb, ${CATCOL[t.cat]} 13%, transparent)">${(cats.find(c => c.n === t.cat) || { i: '他' }).i}</div>
            <div><div class="t1">${t.cat}${t.sub ? ' · ' + t.sub : ''}${t.counted === false ? '<span class="muted" style="font-size:10px;margin-left:5px">不计收支</span>' : ''}</div><div class="t2">${t.note || t.acc}</div></div>
            <div class="amt ${t.type === 'i' ? 'in' : ''}">${t.type === 'e' ? '-' : '+'}${fmt(t.amt)}</div>
          </div>`).join('')}
      </div>`).join('');
  }

  /* ========== SP-3-01 报表 ========== */
  function renderReport() {
    const es = tx.filter(t => t.type === 'e');
    const byCat = {}; es.forEach(t => byCat[t.cat] = (byCat[t.cat] || 0) + t.amt);
    const total = es.reduce((s, t) => s + t.amt, 0);
    const entries = Object.entries(byCat).sort((a, b) => b[1] - a[1]);
    const C = 2 * Math.PI * 54; let off = 0;
    const segs = entries.map(([c, v]) => {
      const len = v / total * C;
      const s = `<circle r="54" cx="70" cy="70" fill="none" stroke="${CATCOL[c]}" stroke-width="22" stroke-dasharray="${len - 2} ${C - len + 2}" stroke-dashoffset="${-off}" transform="rotate(-90 70 70)"/>`;
      off += len; return s;
    }).join('');
    const days = {}; es.forEach(t => { const d = +t.date.slice(8); days[d] = (days[d] || 0) + t.amt; });
    const mx = Math.max(...Object.values(days), 1);
    const bars = Array.from({ length: 29 }, (_, i) => `<div class="bar ${i === 28 ? 'hot' : ''}" style="height:${Math.max((days[i + 1] || 0) / mx * 100, 2)}%" title="9月${i + 1}日 ¥${fmt(days[i + 1] || 0)}"></div>`).join('');
    const lastOut = 6842;
    const pct = (a, b) => b ? Math.round((a - b) / b * 100) : 0;
    $('reportBody').innerHTML = `
      <div class="card">
        <div class="sec">支出分类</div>
        <div class="donut-wrap">
          <svg width="140" height="140" viewBox="0 0 140 140">
            <circle r="54" cx="70" cy="70" fill="none" stroke="var(--surface-2)" stroke-width="22"/>
            ${segs}
            <text x="70" y="66" text-anchor="middle" font-size="11" fill="var(--muted)">本月支出</text>
            <text x="70" y="84" text-anchor="middle" font-size="15" font-weight="500" fill="var(--ink)">¥${Math.round(total).toLocaleString()}</text>
          </svg>
          <div class="legend">${entries.slice(0, 7).map(([c, v]) => `<div class="lg-row"><span class="lg-dot" style="background:${CATCOL[c]}"></span>${c}<b>¥${Math.round(v).toLocaleString()} · ${Math.round(v / total * 100)}%</b></div>`).join('')}</div>
        </div>
        <div class="foot">点击扇区可下钻至二级分类（原型：静态演示）</div>
      </div>
      <div class="card">
        <div class="sec" style="margin-bottom:2px">日支出走势</div>
        <div style="display:flex;justify-content:space-between;font-size:10px;color:var(--muted)"><span>9/1</span><span>9/15</span><span>9/29</span></div>
        <div class="bars">${bars}</div>
      </div>
      <div class="card">
        <div class="sec">月对比</div>
        <div class="cmp-row"><span>支出</span><span><b>¥${fmt(total)}</b><span class="updn ${total > lastOut ? 'up' : 'dn'}">${total > lastOut ? '▲' : '▼'}${Math.abs(pct(total, lastOut))}%</span></span></div>
        <div class="cmp-row"><span>收入</span><span><b>¥${fmt(tx.filter(t => t.type === 'i').reduce((s, t) => s + t.amt, 0))}</b></span></div>
        <div class="cmp-row"><span>上月支出</span><span style="color:var(--muted)">¥6,842.00</span></div>
      </div>`;
  }

  /* ========== SP-2-01 账户管理 ========== */
  function renderAssets() {
    const eye = $('bal-eye'); if (eye) eye.textContent = balancesHidden ? '显示余额' : '隐藏余额';
    const assets = accounts.filter(a => a.cls !== 'debt');
    const debts = accounts.filter(a => a.cls === 'debt');
    const sumA = assets.reduce((s, a) => s + a.bal, 0);
    const sumD = Math.abs(debts.reduce((s, a) => s + a.bal, 0));
    const net = sumA - sumD;
    const M = v => balancesHidden ? '✱✱✱✱' : '¥' + fmt(v);
    const ico = a => a.cls === 'debt' ? '卡' : (a.t === '现金' ? '现' : (a.t === '投资' ? '投' : '储'));
    const cls = a => a.cls === 'debt' ? 'o' : (a.t === '投资' ? 'g' : '');
    $('assetBody').innerHTML = `
      <div class="hero dark">
        <div class="hl">净资产（Σ资产 − Σ负债）</div>
        <div class="hv" onclick="tapReveal('net')" style="cursor:${balancesHidden ? 'pointer' : 'default'}">${balancesHidden && !isRevealed('net') ? '✱✱✱✱✱' : (net < 0 ? '-' : '') + '¥' + fmt(Math.abs(net))}</div>
        <div class="hs">
          <div><span>资产</span><b>${(balancesHidden && !isRevealed('sumA')) ? '✱✱✱' : ('¥' + fmt(sumA))}</b></div>
          <div><span>负债</span><b>${(balancesHidden && !isRevealed('sumD')) ? '✱✱✱' : ('¥' + fmt(sumD))}</b></div>
          <div><span>账户</span><b>${accounts.length} 个</b></div>
        </div>
      </div>
      <div class="mcard">
        ${accounts.map((a, i) => {
      const extra = a.cls === 'debt'
        ? `欠款 ${(balancesHidden && !isRevealed('acc' + i)) ? '✱✱✱✱' : ('¥' + fmt(Math.abs(a.bal)))} · 可用 ${balancesHidden ? '✱✱✱' : ('¥' + fmt(a.limit - Math.abs(a.bal)))}`
        : (a.cost != null ? `${a.t} · 成本 ${M(a.cost)}` : a.t);
      return `<div class="mrow">
            <div class="icoc ${cls(a)}">${ico(a)}</div>
            <div class="grow" onclick="${a.cls === 'debt' ? "go('s-cardbill')" : `reconcile(${i})`}"><div class="t1">${a.n}${a.cls === 'debt' ? '<span class="muted" style="font-size:10px;margin-left:5px">负债</span>' : ''}</div>
            <div class="t2">${extra}</div></div>
            <div onclick="tapReveal('acc${i}')" style="font-size:15px;font-weight:500;cursor:${balancesHidden ? 'pointer' : 'default'};color:${a.cls === 'debt' ? 'var(--sem-neg)' : 'var(--ink)'}">${(balancesHidden && !isRevealed('acc' + i)) ? '✱✱✱✱' : ('¥' + fmt(Math.abs(a.bal)))}</div></div>`;
    }).join('')}
        <div class="mrow" onclick="go('s-invest')"><div class="icoc flat">＋</div>
          <div class="grow"><div class="t1">投资持仓</div><div class="t2">浮盈浮亏 · 净值曲线（V3.0）</div></div><span class="rt">›</span></div>
        <div class="mrow" onclick="go('s-loan')"><div class="icoc flat">＋</div>
          <div class="grow"><div class="t1">贷款摊销</div><div class="t2">房贷 / 车贷还款计划（V3.0）</div></div><span class="rt">›</span></div>
        <div class="mrow" onclick="go('s-networth')"><div class="icoc flat">＋</div>
          <div class="grow"><div class="t1">净值追踪</div><div class="t2">资产 − 负债走势（V3.0）</div></div><span class="rt">›</span></div>
      </div>
      <div class="footbox">
        点击现金 / 储蓄卡行可「对账」：录入实际余额，差额生成可追溯的调整账单（不计入收支）。<br>
        <b>信用卡：欠款余额可写、可用额度只读</b>，由额度派生；账单日 25 日 → 还款日次月 8 日。
      </div>`;
  }
  function toggleHideBal() { balancesHidden = !balancesHidden; revealUntil = {}; renderAssets(); }
  function reconcile(i) {
    const a = accounts[i];
    openModal(`<h3>对账 · ${a.n}</h3>
      <p>账面余额 <b>¥${fmt(a.bal)}</b>。输入当前实际余额，系统将生成一笔「对账调整」账单补齐差额。</p>
      <div class="mins">调整账单标注来源「对账」，在流水中可查、可删。<br><b>不计入收支统计与预算</b>（G-2：它只修正余额，不代表真实收支）。</div>
      <input id="rc-in" type="number" placeholder="实际余额">
      <div class="btns"><button class="btn" onclick="closeModal()">取消</button><button class="btn pri" onclick="doReconcile(${i})">生成调整账单</button></div>`);
  }
  function doReconcile(i) {
    const v = parseFloat($('rc-in').value);
    if (isNaN(v)) { toast('请输入有效金额'); return; }
    const diff = Math.round((v - accounts[i].bal) * 100) / 100;
    if (diff === 0) { toast('账实相符，无需调整'); closeModal(); return; }
    /* counted:false —— 对账调整只修正账户余额，不进入收支统计 / 预算 / 报表 */
    tx.unshift({ id: Date.now(), type: diff < 0 ? 'e' : 'i', amt: Math.abs(diff), cat: '其他', sub: '', note: `对账调整 · ${accounts[i].n}`, acc: accounts[i].n, date: D(29), time: '15:10', src: '对账', counted: false });
    accounts[i].bal = v; closeModal(); renderAssets(); toast(`已生成对账调整 ${diff < 0 ? '-' : '+'}¥${fmt(Math.abs(diff))}（不计入收支）`);
  }

  /* ========== SP-1-03 分类管理 ========== */
  function renderCat() {
    const lv2 = cats.reduce((s, c) => s + c.subs.length, 0);
    $('catBody').innerHTML = `<div class="card soft"><div class="body">共 <b>${cats.length}</b> 个一级分类 · <b>${lv2}</b> 个二级分类。一级名称 ≤6 字、备注 ≤30 字，超长自动截断不报错。</div></div>` +
      cats.map(c => {
        const cnt = tx.filter(t => t.cat === c.n).length;
        return `<div class="mcard">
          <div class="mrow" style="cursor:default">
            <div class="icoc" style="color:${CATCOL[c.n]};background:color-mix(in srgb, ${CATCOL[c.n]} 13%, transparent)">${c.i}</div>
            <div class="grow"><div class="t1">${c.n} <span class="muted" style="font-size:11px">${cnt} 笔</span></div>
            ${c.subs.length ? `<div class="t2">${c.subs.join(' · ')}</div>` : ''}
            ${c.note ? `<div class="t2 faint">备注：${c.note}</div>` : ''}</div>
            <span class="rt pk" onclick="editCat('${c.n}')">编辑</span>
            <span class="rt pk" onclick="hideCat('${c.n}')">隐藏</span>
          </div>
          ${c.subs.length ? `<div class="sub-row2">${c.subs.map(s => `<span class="subchip">${s}</span>`).join('')}<span class="subchip dashed" onclick="toast('新增二级分类（原型演示）')">＋</span></div>` : ''}
        </div>`;
      }).join('') + `<div class="footbox">
        分类备注 ≠ 账单备注，两者是不同实体、不共用字段与组件。<br>
        宫格顺序 = 自定义排序，无自定义时按近 7 天使用频率。改一级名称会同步影响分类色板（12 色跨主题固定）。
      </div>`;
  }
  function editCat(n) {
    const c = cats.find(x => x.n === n) || {};
    openModal(`<h3>编辑分类信息</h3>
      <input id="ec-name" maxlength="6" value="${c.n}" placeholder="分类名称（≤6 字）">
      <input id="ec-note" maxlength="30" value="${c.note || ''}" placeholder="分类备注（选填 · ≤30 字）">
      <p class="fine">备注用于提示自己「这一类包含什么」，如「餐饮 → 工作日午餐和外卖」。备注不参与搜索 / 筛选 / 统计，但会进备份与云同步。</p>
      <div class="btns"><button class="btn" onclick="closeModal()">取消</button><button class="btn pri" onclick="doEditCat('${n}')">保存</button></div>`);
  }
  function doEditCat(n) {
    const c = cats.find(x => x.n === n); if (!c) return;
    const nm = $('ec-name').value.trim(), nt = $('ec-note').value.trim();
    if (!nm) { toast('请输入名称'); return; }
    if (nm !== n && cats.some(x => x.n === nm)) { toast('已有同名分类，请换一个'); return; }
    /* 备注用专用写入口（withNote 语义）：清空备注能真正保存为空 */
    c.n = nm; c.note = nt || undefined;
    closeModal(); renderCat(); toast('分类信息已更新');
  }
  function hideCat(n) {
    openModal(`<h3>隐藏「${n}」？</h3>
      <p>隐藏后该分类不再出现在记账宫格，但<b>历史账单与统计完全不受影响</b>，可随时恢复显示。</p>
      <div class="mins">分类是「隐藏」而不是「删除」——删除会让历史账单变成孤儿。</div>
      <div class="btns"><button class="btn" onclick="closeModal()">取消</button><button class="btn pri" onclick="closeModal();toast('已隐藏「${n}」，历史账单与统计不受影响')">隐藏</button></div>`);
  }
  function mergeCat(n) {
    const cnt = tx.filter(t => t.cat === n).length;
    const subs = (cats.find(c => c.n === n) || {}).subs || [];
    openModal(`<h3>合并「${n}」</h3>
      <p>将「${n}」合并入目标分类，其 <b>${cnt} 笔</b>历史账单将全部迁移至目标分类。</p>
      <div class="mins">
        影响范围：<b>${cnt} 笔账单</b>${subs.length ? `，其中含 <b>${subs.length} 个二级分类</b>（${subs.slice(0, 3).join('、')}${subs.length > 3 ? '…' : ''}）` : ''}<br>
        合并后<b>不可一键撤销</b>（可再次手动合并回去）。<br>
        二级分类不会自动跟随迁移，需为每笔原二级指定归属或降为一级。
      </div>
      <div class="btns"><button class="btn" onclick="closeModal()">取消</button><button class="btn pri" onclick="closeModal();toast('${cnt} 笔账单已迁移（原型演示）')">选择目标并合并</button></div>`);
  }
  function addCat() {
    openModal(`<h3>新增分类</h3>
      <input id="nc-in" maxlength="6" placeholder="分类名称（≤6 字）">
      <input id="nc-note" maxlength="30" placeholder="分类备注（选填 · ≤30 字）">
      <p class="fine">图标：内置图标库 200+ 或上传本地图片裁剪。挂载位置：一级或任一一级分类下的二级。<br>重名校验：同一层级下不允许同名分类。</p>
      <div class="btns"><button class="btn" onclick="closeModal()">取消</button><button class="btn pri" onclick="doAddCat()">保存</button></div>`);
  }
  function doAddCat() {
    const n = $('nc-in').value.trim(), nt = $('nc-note').value.trim();
    if (!n) { toast('请输入名称'); return; }
    if (cats.some(c => c.n === n)) { toast('已有同名分类，请换一个'); return; }
    cats.push({ n, i: n[0], subs: [], note: nt || undefined }); closeModal(); renderCat(); toast(`分类「${n}」已创建`);
  }

  /* ========== SP-4-01 备份与恢复 ========== */
  function renderBackup() {
    $('backupBody').innerHTML = `
      <div class="card">
        <div class="sec">备份说明</div>
        <div class="body">备份为整库加密文件，包含全部账单、分类、账户与设置。通过系统分享保存到网盘或电脑。<b>卸载应用将清除本地数据，请提前备份。</b></div>
      </div>
      <div class="mcard">
        ${backups.length ? backups.map((b, i) => `<div class="mrow" onclick="previewBk(${i})">
          <div class="icoc">备</div>
          <div class="grow"><div class="t1">${b.time}</div><div class="t2">${b.count} 笔账单 · ${b.ver} · 已加密</div></div>
          <span class="rt">恢复 ›</span></div>`).join('') :
        `<div class="mrow" style="cursor:default"><div class="icoc flat">空</div>
          <div class="grow"><div class="t1 muted">还没有备份</div><div class="t2">点击右上角「生成备份」创建第一份</div></div></div>`}
      </div>
      <div class="footbox">恢复流程：选择备份 → 校验密码与版本 → 预览（笔数 / 时间范围）→ 确认。恢复前自动生成一份「恢复前备份」。</div>`;
  }
  function makeBackup() {
    backups.unshift({ time: '2026-09-29 15:08', count: tx.length, ver: 'v1.0.0' });
    renderBackup(); toast(`备份已生成（${tx.length} 笔账单）`);
  }
  function previewBk(i) {
    const b = backups[i];
    openModal(`<h3>恢复备份</h3>
      <div class="mins">备份时间：${b.time}<br>账单数量：${b.count} 笔<br>数据范围：2026-09-01 ~ 2026-09-29<br>备份版本：${b.ver}　当前版本：v1.0.0 ✓ 兼容</div>
      <p>确认后将用备份数据<b>覆盖当前数据</b>。系统会先自动生成一份「恢复前备份」，操作可反悔。</p>
      <div class="btns"><button class="btn" onclick="closeModal()">取消</button><button class="btn pri" onclick="closeModal();toast('已恢复，恢复前备份已自动生成')">确认恢复</button></div>`);
  }

  /* ========== SP-1-04 转账 / 借出 / 借入 ========== */
  let apMode = 'transfer';
  const AP_MODES = {
    transfer: ['转账', '转出账户 → 转入账户，不计入收支'],
    lend: ['借出', '我先垫付，未来收回。计入「应收」，不计入收支'],
    borrow: ['借入', '我先拿到钱，未来归还。计入「应付」，计入收入口径可切换'],
    repay: ['还款', '归还信用卡 / 贷款，只转移负债，不计入收支'],
    invest: ['投资买入', '从储蓄账户转入投资账户，仍是你的钱，不计入收支']
  };
  function openAddPlus(mode) {
    apMode = mode || 'transfer';
    const ttl = AP_MODES[apMode][0];
    $('ap-title').textContent = ttl;
    const amt = evalExpr() > 0 ? evalExpr() : 0;
    $('addPlusBody').innerHTML = `
      <div class="card hint">
        <div class="body"><b>${ttl}</b> · ${AP_MODES[apMode][1]}<br>
          这类记账涉及两个账户，<b>不走「点分类即保存」</b>，需要显式确认（G-6）。</div>
      </div>
      <div class="card" style="text-align:center;padding:18px">
        <div class="muted" style="font-size:11px">金额</div>
        <div style="font-size:32px;font-weight:500;margin-top:2px">¥${fmt(amt)}</div>
      </div>
      <div class="mcard">
        <div class="mrow" style="cursor:default"><div class="icoc">出</div><div class="grow"><div class="t1">转出 / 来源账户</div></div>
          <select><option>现金</option><option selected>招行储蓄</option></select></div>
        <div class="mrow" style="cursor:default"><div class="icoc">入</div><div class="grow"><div class="t1">转入 / 目标</div></div>
          <select><option>现金</option><option>招行信用卡</option><option selected>某基金</option></select></div>
        <div class="mrow" style="cursor:default"><div class="icoc">日</div><div class="grow"><div class="t1">日期</div></div><span class="rt">今天</span></div>
        <div class="mrow" style="cursor:default"><div class="icoc">注</div><div class="grow"><div class="t1">备注</div></div><span class="rt">选填</span></div>
      </div>
      <div class="card note">
        <div class="body"><b>副作用预览（保存前可见）：</b><br>
          · 转出账户 −¥${fmt(amt)}　· 转入账户 +¥${fmt(amt)}<br>
          · 净资产不变（钱只是换了地方）<br>
          · <b>不计入收支统计与预算</b>（G-2）</div>
      </div>`;
    go('s-addplus');
  }
  function saveAddPlus() { toast(`已记录「${AP_MODES[apMode][0]}」（不计入收支）`); go('s-home'); }

  /* ========== SP-1-05 分割交易 ========== */
  let splitParts = [
    { cat: '餐饮', sub: '午餐', amt: 68, note: '工作餐' },
    { cat: '人情', sub: '请客', amt: 100, note: '招待同事' }
  ];
  const splitTotal = 168;
  function renderSplit() {
    const sum = splitParts.reduce((s, p) => s + p.amt, 0);
    const diff = Math.round((splitTotal - sum) * 100) / 100;
    const ok = Math.abs(diff) < 0.005;
    $('splitBody').innerHTML = `
      <div class="card">
        <div class="cmp-row"><span>账单原始金额</span><b>¥${fmt(splitTotal)}</b></div>
        <div class="cmp-row"><span>已分配</span><b style="color:${ok ? 'var(--sem-pos)' : 'var(--sem-neg)'}">¥${fmt(sum)}</b></div>
        <div class="pbar ${ok ? '' : 'over'}"><i style="width:${Math.min(sum / splitTotal * 100, 100)}%"></i></div>
        <div style="font-size:12px;color:${ok ? 'var(--sem-pos)' : 'var(--sem-neg)'};margin-top:4px">
          ${ok ? '✓ 已对平，可以保存' : `还差 ¥${fmt(Math.abs(diff))}，未对平不允许保存`}
        </div>
      </div>
      <div class="mcard">
        ${splitParts.map(p => `<div class="split-row">
          <div class="icoc" style="color:${CATCOL[p.cat]};background:color-mix(in srgb, ${CATCOL[p.cat]} 13%, transparent)">${p.cat[0]}</div>
          <div class="grow"><div class="t1" style="font-size:13px">${p.cat} · ${p.sub}</div><div class="t2" style="font-size:11px">${p.note}</div></div>
          <b style="font-size:14px">¥${fmt(p.amt)}</b>
          <span class="rt pk" onclick="toast('编辑子项（原型演示）')">改</span>
        </div>`).join('')}
        <div class="split-row" style="cursor:pointer" onclick="addSplitPart()">
          <div class="icoc flat">＋</div>
          <div class="grow"><div class="t1 pk" style="font-size:13px">再分一项</div></div>
        </div>
      </div>
      <div class="footbox">
        父子结构：父单不被删除，子项独立统计。父单金额恒等于 Σ 子项金额。<br>
        报表中：各子项按自己的分类计数，父单<b>分类置空</b>、不参与分类统计（避免双算）；父单只计入账户余额一次。
      </div>`;
  }
  function addSplitPart() { splitParts.push({ cat: '其他', sub: '', amt: 0, note: '' }); renderSplit(); }
  function saveSplit() {
    const sum = splitParts.reduce((s, p) => s + p.amt, 0);
    if (Math.abs(splitTotal - sum) >= 0.005) { toast('金额未对平，无法保存'); return; }
    toast(`已分割为 ${splitParts.length} 项`); go('s-home');
  }

  /* ========== SP-1-06 报销中心 ========== */
  const claims = [
    { id: 1, amt: 328, cat: '交通', note: '客户拜访打车', date: '2026-09-26', state: '待报销' },
    { id: 2, amt: 1200, cat: '餐饮', note: '团队聚餐垫付', date: '2026-09-22', state: '已提交' },
    { id: 3, amt: 560, cat: '住宿', note: '出差酒店', date: '2026-09-15', state: '已到账' }
  ];
  function renderClaim() {
    const g = k => claims.filter(c => c.state === k);
    const box = (title, list, color) => `
      <div class="card">
        <div class="sec" style="color:${color}">${title} · ${list.length} 笔</div>
        ${list.length ? list.map(c => `<div class="kv"><span class="k">${c.date.slice(5)} ${c.cat}${c.note ? ' · ' + c.note : ''}</span><span class="v">¥${fmt(c.amt)}</span></div>`).join('') : '<div class="muted" style="font-size:12px">暂无</div>'}
      </div>`;
    $('claimBody').innerHTML = `
      <div class="hero brand">
        <div class="hl">待收回金额</div>
        <div class="hv">¥${fmt(g('待报销').concat(g('已提交')).reduce((s, c) => s + c.amt, 0))}</div>
        <div class="hs"><div><span>待报销</span><b>${g('待报销').length} 笔</b></div><div><span>已提交</span><b>${g('已提交').length} 笔</b></div></div>
      </div>
      ${box('待报销', g('待报销'), 'var(--sem-warn-ink)')}
      ${box('已提交', g('已提交'), 'var(--info-ink)')}
      ${box('已到账', g('已到账'), 'var(--sem-pos)')}
      <div class="card note">
        <div class="body">报销到账时，系统自动生成一笔等额收入并<b>冲销原支出</b>——净效果为 0，不会把你的报销算成额外收入。<br>
          报销前后：支出统计中该笔始终保留（体现真实消费），到账收入标记为「报销回款」不计入收入。</div>
      </div>`;
  }

  /* ========== SP-2-02 信用卡账单 ========== */
  function renderCardBill() {
    const c = accounts.find(a => a.cls === 'debt');
    const owe = Math.abs(c.bal);
    const avail = c.limit - owe;
    const used = owe / c.limit * 100;
    const billTx = tx.filter(t => t.acc === c.n);
    const billSum = billTx.reduce((s, t) => s + t.amt, 0);
    $('cardBillBody').innerHTML = `
      <div class="hero dark">
        <div class="hl">本期应还（还款日 10 月 8 日）</div>
        <div class="hv">¥${fmt(owe)}</div>
        <div class="hs">
          <div><span>最低还款</span><b>¥${fmt(owe * 0.1)}</b></div>
          <div><span>可用额度</span><b>¥${fmt(avail)}</b></div>
          <div><span>已用</span><b>${used.toFixed(1)}%</b></div>
        </div>
      </div>
      <div class="card">
        <div class="cmp-row"><span>账单日</span><b>每月 25 日</b></div>
        <div class="cmp-row"><span>还款日</span><b>次月 8 日</b></div>
        <div class="cmp-row"><span>总额度</span><b>¥${fmt(c.limit)}</b></div>
        <div class="cmp-row"><span>循环利息</span><b>无（全额还款）</b></div>
        <div class="pbar warn" style="margin-top:8px"><i style="width:${used}%"></i></div>
        <div class="foot">已用 ${used.toFixed(1)}%，额度使用健康</div>
      </div>
      <div class="card">
        <div style="display:flex;justify-content:space-between;font-size:13px;font-weight:500;margin-bottom:6px">
          <span>本期未出账消费</span><span>¥${fmt(billSum)}</span>
        </div>
        <div class="foot" style="margin-bottom:6px">账单周期 9/26–10/25 · 计息日 10/8</div>
        ${billTx.length ? billTx.map(t => `<div class="kv"><span class="k">${t.date.slice(5)} ${t.cat}${t.sub ? ' · ' + t.sub : ''}${t.note ? ' · ' + t.note : ''}</span><span class="v" style="color:var(--sem-neg)">-${fmt(t.amt)}</span></div>`).join('') : '<div class="muted" style="font-size:12px">本期暂无消费</div>'}
      </div>
      <div class="card note">
        <div class="body"><b>双数模型：</b>「欠款余额」是可写的唯一权威量；「可用额度」由总额度派生，<b>只读</b>。<br>
          信用卡消费计入支出统计（钱确实花了），还信用卡则不计入收支（只减少欠款）。<br>
          本期应还 ¥${fmt(owe)} 与未出账 ¥${fmt(billSum)} 是两个口径：前者是上一个账单周期的结算结果，后者是本期新增。</div>
      </div>`;
  }

  /* ========== SP-5-04 提醒中心 ========== */
  const reminders = [
    { k: '预算', t: '本月餐饮预算已用 87%', d: '剩余 ¥130，按当前速度将在 5 天后超支', lv: '响铃', c: 'var(--sem-warn)' },
    { k: '预算', t: '本月总支出已达 90%', d: '较上月同期多花 12%', lv: '静默', c: 'var(--sem-warn)' },
    { k: '账单', t: '招行信用卡 10 月 8 日还款', d: '本期应还 ¥3,280.00，还有 9 天', lv: '响铃', c: 'var(--sem-neg)' },
    { k: '周期', t: '房租 ¥4,500 待确认', d: '今天是每月 1 日，检测到周期记账规则命中', lv: '响铃', c: 'var(--primary)' },
    { k: '账单', t: '某基金定投将于 10 月 15 日扣款', d: '¥1,000.00，从招行储蓄扣除', lv: '静默', c: 'var(--info-ink)' }
  ];
  let remindFilter = '全部';
  function renderRemind() {
    const list = remindFilter === '全部' ? reminders : reminders.filter(r => r.k === remindFilter);
    $('remindBody').innerHTML = list.length ? list.map(r => `
      <div class="card" style="padding:12px 14px">
        <div style="display:flex;align-items:center;gap:8px">
          <span style="width:8px;height:8px;border-radius:50%;background:${r.c};flex-shrink:0"></span>
          <div class="grow"><div style="font-size:13.5px;font-weight:500">${r.t}</div>
          <div style="font-size:11.5px;color:var(--muted);margin-top:3px;line-height:1.6">${r.d}</div></div>
          <span class="tag ${r.lv === '响铃' ? 'paid' : 'free'}">${r.lv}</span>
        </div>
        <div style="display:flex;gap:8px;margin-top:10px">
          <button class="btn" style="height:32px;font-size:12.5px" onclick="toast('稍后提醒（原型演示）')">稍后</button>
          <button class="btn pri" style="height:32px;font-size:12.5px" onclick="toast('已处理（原型演示）')">知道了</button>
        </div>
      </div>`).join('') : '<div class="empty">这类提醒暂时没有</div>';
  }
  function segRemind(el, k) {
    remindFilter = k;
    el.parentNode.querySelectorAll('div').forEach(d => d.classList.remove('on'));
    el.classList.add('on'); renderRemind();
  }

  /* ========== SP-5-05 自动规则 ========== */
  const rules = [
    { n: '星巴克自动归类', on: true, if: '商户 包含 <code>星巴克</code>', then: '分类 → 餐饮 · 饮料，账户 → 招行信用卡', hit: 12 },
    { n: '地铁通勤归类', on: true, if: '商户 包含 <code>地铁</code> 且 金额 <code>&lt;= 20</code>', then: '分类 → 交通 · 公交地铁', hit: 34 },
    { n: '大额支出标记', on: true, if: '金额 <code>&gt;= 500</code>', then: '打标签 <code>#大额</code>，备注追加提醒', hit: 6 },
    { n: '晚间消费提醒', on: false, if: '时间 在 <code>23:00–05:00</code>', then: '打标签 <code>#深夜</code>（仅标记不通知）', hit: 3 },
    { n: '工资自动入账', on: true, if: '金额 <code>= 15000</code> 且 类型 收入', then: '分类 → 其他 · 工资，账户 → 招行储蓄', hit: 1 }
  ];
  function renderRule() {
    $('ruleBody').innerHTML = `
      <div class="card soft"><div class="body">规则 = <b>条件（IF）</b> + <b>动作（THEN）</b>。一条账单可在保存时命中多条规则，按优先级顺序执行，后者可覆盖前者。<br>每次命中都会记入「规则执行日志」，可查看、可撤销。</div></div>
      <div class="mcard">
        ${rules.map((r, i) => `<div class="rl-row">
          <div class="icoc ${r.on ? '' : 'o'}" style="${r.on ? 'background:var(--primary-soft);color:var(--primary-ink)' : 'background:var(--surface-2);color:var(--muted)'}">${i + 1}</div>
          <div class="grow">
            <div class="t1" style="font-size:13px">${r.n}</div>
            <div class="rl-if">IF ${r.if}</div>
            <div class="rl-if">THEN ${r.then}</div>
            <div class="faint" style="font-size:10.5px;margin-top:3px">已命中 ${r.hit} 次</div>
          </div>
          <div class="sw ${r.on ? 'on' : ''}" onclick="toggleRule(this,${i})"></div>
        </div>`).join('')}
      </div>
      <div class="footbox">执行阶段：保存前（可改写分类 / 账户） / 保存后（只做标记与通知）。改动仅作用于规则生效之后的新账单，不回改历史。</div>`;
  }
  function toggleRule(el, i) {
    rules[i].on = !rules[i].on; el.classList.toggle('on');
    toast(`规则「${rules[i].n}」已${rules[i].on ? '启用' : '停用'}`);
  }

  /* ========== SP-5-06 储蓄目标与基金 ========== */
  const funds = [
    { n: '年度旅行', target: 12000, saved: 7400, monthly: 1000, icon: '✈' },
    { n: '换手机', target: 6000, saved: 1800, monthly: 500, icon: '📱' },
    { n: '保险费（年金）', target: 4800, saved: 3600, monthly: 400, icon: '🛡' },
    { n: '应急储备', target: 30000, saved: 12500, monthly: 2500, icon: '🚑' }
  ];
  function renderGoal() {
    const totalSaved = funds.reduce((s, f) => s + f.saved, 0);
    const totalTarget = funds.reduce((s, f) => s + f.target, 0);
    $('goalBody').innerHTML = `
      <div class="hero brand">
        <div class="hl">目标已存 / 目标总额</div>
        <div class="hv">¥${fmt(totalSaved)} <span style="font-size:15px;opacity:.75">/ ¥${fmt(totalTarget)}</span></div>
        <div class="pbar" style="background:rgba(255,255,255,.25)"><i style="width:${totalSaved / totalTarget * 100}%;background:#fff"></i></div>
        <div class="hs" style="margin-top:10px"><div><span>总进度</span><b>${(totalSaved / totalTarget * 100).toFixed(1)}%</b></div><div><span>月需存入</span><b>¥4,400</b></div></div>
      </div>
      ${funds.map(f => {
      const p = f.saved / f.target * 100;
      return `
        <div class="card">
          <div style="display:flex;align-items:center;gap:10px">
            <div class="icoc" style="font-size:17px">${f.icon}</div>
            <div class="grow">
              <div style="display:flex;justify-content:space-between;font-size:13.5px;font-weight:500">
                <span>${f.n}</span><span>¥${fmt(f.saved)} <span class="muted" style="font-size:11px;font-weight:400">/ ¥${fmt(f.target)}</span></span>
              </div>
              <div class="pbar ${p >= 90 ? 'over' : (p < 40 ? '' : 'warn')}" style="margin-top:7px"><i style="width:${Math.min(p, 100)}%"></i></div>
              <div style="display:flex;justify-content:space-between;font-size:11px;color:var(--muted);margin-top:4px">
                <span>${p.toFixed(0)}% · 还差 ¥${fmt(f.target - f.saved)}</span><span>月存 ¥${fmt(f.monthly)}</span>
              </div>
            </div>
          </div>
        </div>`;
    }).join('')}
      <div class="card note">
        <div class="body"><b>沉淀基金</b>把「一年一次的大额支出」拆成月存（如保险费、旅行、年检），避免某个月突然被击穿。<br>
          目标里的钱<b>从「安全可花」基数中扣除</b>——否则你会以为自己很有钱。</div>
      </div>`;
  }

  /* ========== SP-5-07 首页卡片自定义 ========== */
  const homeCards = [
    { n: '记账月结余', d: '收入 / 支出 / 结余三数值', on: true },
    { n: '预算进度', d: '本月预算总进度条', on: true },
    { n: '安全可花', d: '扣除预留后的日均可支配', on: true },
    { n: '目标进度', d: '最近一个储蓄目标的进度', on: false },
    { n: '净值', d: '净资产与较上月变化', on: false },
    { n: '近 7 天热力图', d: '按日消费强度色块', on: false }
  ];
  function renderCardCfg() {
    $('cardCfgBody').innerHTML = `
      <div class="card soft"><div class="body">勾选要常驻首页的卡片。<b>至少保留 1 张、最多 4 张</b>，长按可拖动排序。</div></div>
      <div class="mcard">
        ${homeCards.map((c, i) => `<div class="mrow" style="cursor:default">
          <div class="icoc flat">${i + 1}</div>
          <div class="grow"><div class="t1">${c.n}</div><div class="t2">${c.d}</div></div>
          <div class="sw ${c.on ? 'on' : ''}" onclick="toggleCard(this,${i})"></div>
        </div>`).join('')}
      </div>
      <div class="footbox">首页卡片顺序与开关属本机偏好，多端同步时不覆盖其他设备。</div>`;
  }
  function toggleCard(el, i) {
    const on = homeCards.filter(c => c.on).length;
    if (homeCards[i].on && on <= 1) { toast('至少保留 1 张卡片'); return; }
    if (!homeCards[i].on && on >= 4) { toast('最多 4 张卡片'); return; }
    homeCards[i].on = !homeCards[i].on; el.classList.toggle('on');
  }

  /* ========== SP-2-04 投资持仓 ========== */
  const holdings = [
    { n: '沪深300指数基金', code: '110020', shares: 5680.2, cost: 15000, price: 3.274, mkt: 18600 },
    { n: '纳指ETF', code: '513100', shares: 1200, cost: 9600, price: 8.95, mkt: 10740 },
    { n: '货币基金', code: '000198', shares: 5000, cost: 5000, price: 1.0, mkt: 5012 }
  ];
  function renderInvest() {
    const mkt = holdings.reduce((s, h) => s + h.mkt, 0);
    const cost = holdings.reduce((s, h) => s + h.cost, 0);
    const pnl = mkt - cost;
    $('investBody').innerHTML = `
      <div class="hero brand">
        <div class="hl">持仓总市值</div>
        <div class="hv">¥${fmt(mkt)}</div>
        <div class="hs">
          <div><span>总成本</span><b>¥${fmt(cost)}</b></div>
          <div><span>浮动盈亏</span><b>${pnl >= 0 ? '+' : ''}¥${fmt(pnl)}</b></div>
          <div><span>收益率</span><b>${pnl >= 0 ? '+' : ''}${(pnl / cost * 100).toFixed(2)}%</b></div>
        </div>
      </div>
      ${holdings.map(h => {
      const g = h.mkt - h.cost; const r = g / h.cost * 100;
      return `
        <div class="card">
          <div style="display:flex;justify-content:space-between;align-items:baseline">
            <div><div style="font-size:13.5px;font-weight:500">${h.n}</div>
            <div class="muted" style="font-size:11px;margin-top:2px">${h.code} · 持有 ${h.shares.toLocaleString()} 份 · 净值 ${h.price}</div></div>
            <div style="text-align:right"><div style="font-size:15px;font-weight:500">¥${fmt(h.mkt)}</div>
            <div style="font-size:11.5px;color:${g >= 0 ? 'var(--sem-inc)' : 'var(--sem-pos)'}">${g >= 0 ? '+' : ''}${fmt(g)} (${r >= 0 ? '+' : ''}${r.toFixed(2)}%)</div></div>
          </div>
          <div class="pbar" style="margin-top:9px"><i style="width:${Math.min(h.mkt / h.cost * 50, 100)}%"></i></div>
        </div>`;
    }).join('')}
      <div class="card note">
        <div class="body">持仓成本为手工录入或买入时自动记账；<b>市值需要行情源</b>——数据源选型是 V3.0 前的开放问题（免费源 / 用户手填 / 手动刷新三选一或多轨）。<br>
          在你选定之前，市值可按「最近一次手动估值」冻结显示。</div>
      </div>`;
  }

  /* ========== SP-2-05 贷款摊销 ========== */
  function renderLoan() {
    const P = 1000000, yRate = 0.039, months = 360, mRate = yRate / 12;
    const mp = P * mRate * Math.pow(1 + mRate, months) / (Math.pow(1 + mRate, months) - 1);
    const paidM = 48;
    const remain = P * (Math.pow(1 + mRate, months) - Math.pow(1 + mRate, paidM)) / (Math.pow(1 + mRate, months) - 1);
    const totalInt = mp * months - P;
    const rows = [];
    let bal = P;
    for (let i = 1; i <= 6; i++) {
      const int = bal * mRate, pri = mp - int; bal -= pri;
      rows.push({ i, int, pri, bal });
    }
    $('loanBody').innerHTML = `
      <div class="hero dark">
        <div class="hl">剩余本金</div>
        <div class="hv">¥${fmt(remain)}</div>
        <div class="hs"><div><span>月供</span><b>¥${fmt(mp)}</b></div><div><span>已还</span><b>${paidM}/${months} 期</b></div><div><span>利率</span><b>${(yRate * 100).toFixed(2)}%</b></div></div>
      </div>
      <div class="card">
        <div class="cmp-row"><span>还款方式</span><b>等额本息</b></div>
        <div class="cmp-row"><span>贷款总额</span><b>¥${fmt(P)}</b></div>
        <div class="cmp-row"><span>利息总额</span><b>¥${fmt(totalInt)}</b></div>
        <div class="cmp-row"><span>已还利息</span><b>¥${fmt(mp * paidM - (P - remain))}</b></div>
        <div class="pbar" style="margin-top:8px"><i style="width:${paidM / months * 100}%"></i></div>
        <div class="foot">还款进度 ${(paidM / months * 100).toFixed(1)}%（按本息合计口径约 ${((P - remain + (mp * paidM - (P - remain))) / (P + totalInt) * 100).toFixed(1)}%）</div>
      </div>
      <div class="card">
        <div class="sec">未来 6 期还款计划</div>
        <div class="dtbl">
          <span class="h">期次</span><span class="h r">本金</span><span class="h r">利息</span><span class="h r">余额</span>
          ${rows.map(r => `<span class="c nm">第 ${r.i} 期</span><span class="c r">${Math.round(r.pri)}</span><span class="c r" style="color:var(--muted)">${Math.round(r.int)}</span><span class="c r">${Math.round(r.bal).toLocaleString()}</span>`).join('')}
        </div>
      </div>
      <div class="footbox">
        每期还款自动生成一条「还款」账单：利息计入支出，本金只减少负债、<b>不计入支出</b>（G-2）。<br>
        这样你看到的是「这个月真的花了多少利息」，而不是「我把本金挪了个地方也算花掉」。
      </div>`;
  }

  /* ========== SP-2-06 净值追踪 ========== */
  const nwHistory = [
    { m: '4月', a: 42000, d: 21000 }, { m: '5月', a: 44500, d: 20600 }, { m: '6月', a: 47800, d: 20200 },
    { m: '7月', a: 50200, d: 19800 }, { m: '8月', a: 53400, d: 3600 }, { m: '9月', a: 51627, d: 3280 }
  ];
  function renderNetWorth() {
    const c = nwHistory[nwHistory.length - 1], p = nwHistory[nwHistory.length - 2];
    const net = c.a - c.d, prevNet = p.a - p.d;
    const chg = net - prevNet;
    const mx = Math.max(...nwHistory.map(h => h.a - h.d));
    $('netWorthBody').innerHTML = `
      <div class="hero dark">
        <div class="hl">当前净值（资产 − 负债）</div>
        <div class="hv">¥${fmt(net)}</div>
        <div class="hs"><div><span>较上月</span><b>${chg >= 0 ? '+' : ''}¥${fmt(chg)}</b></div><div><span>环比</span><b>${chg >= 0 ? '+' : ''}${(chg / prevNet * 100).toFixed(1)}%</b></div></div>
      </div>
      <div class="card">
        <div class="sec" style="margin-bottom:2px">净值走势（近 6 个月）</div>
        <div class="mini-bars" style="height:96px">
          ${nwHistory.map((h, i) => { const n = h.a - h.d; const on = i === nwHistory.length - 1; return `<i style="height:${n / mx * 100}%;background:${on ? 'var(--primary)' : 'var(--chart-bar)'}" title="${h.m} ¥${fmt(n)}"></i>`; }).join('')}
        </div>
        <div style="display:flex;gap:4px;margin-top:5px">
          ${nwHistory.map(h => `<div style="flex:1;text-align:center;font-size:10px;color:var(--muted)">${h.m}</div>`).join('')}
        </div>
      </div>
      <div class="card">
        <div class="sec">构成变化（近 3 个月）</div>
        <div class="stack">
          <i style="width:52%;background:var(--cat-food)" title="现金储蓄"></i>
          <i style="width:34%;background:var(--cat-grocery)" title="投资"></i>
          <i style="width:14%;background:var(--cat-other)" title="其他资产"></i>
        </div>
        <div class="cmp-row"><span><span class="lg-dot" style="display:inline-block;background:var(--cat-food)"></span> 现金与储蓄</span><b>¥${fmt(33027)} · 63.9%</b></div>
        <div class="cmp-row"><span><span class="lg-dot" style="display:inline-block;background:var(--cat-grocery)"></span> 投资市值</span><b>¥${fmt(34352)} · 22.2%</b></div>
        <div class="cmp-row"><span><span class="lg-dot" style="display:inline-block;background:var(--sem-neg)"></span> 负债</span><b style="color:var(--sem-neg)">-¥${fmt(c.d)}</b></div>
      </div>
      <div class="card note">
        <div class="body">净值 = Σ资产 − Σ负债。<b>记账只能算出现金类账户的净值</b>；房 / 车等非现金资产靠手动估值与折旧录入（每 3 / 6 / 12 个月提醒你更新一次）。<br>
          净值曲线仅在资产估值口径一致时可比——换了估值口径，图上会留一个标注点。</div>
      </div>`;
  }

  /* ========== SP-3-03 Sankey ========== */
  function renderSankey() {
    const inc = 15000;
    const flows = [
      { n: '居住', v: 4500, c: 'var(--cat-housing)' }, { n: '餐饮', v: 1210, c: 'var(--cat-food)' },
      { n: '食材', v: 356, c: 'var(--cat-grocery)' }, { n: '购物', v: 399, c: 'var(--cat-shopping)' },
      { n: '其他', v: 1054, c: 'var(--cat-other)' }
    ];
    const spend = flows.reduce((s, f) => s + f.v, 0);
    const left = inc - spend;
    const H = 200, TOP = 16, INX = 16, INW = 16, OUTX = 176, OUTW = 16;
    let y = TOP, bands = '', labels = '';
    flows.forEach((f, i) => {
      const h = f.v / inc * H, y0 = y, y1 = y + h; y = y1;
      const my = (y0 + y1) / 2;
      const ly = TOP + 18 + i * ((H - 24) / (flows.length - 1 || 1));
      bands += `<path d="M${INX + INW} ${y0 + 1.5} C 96 ${y0 + 1.5}, 120 ${my}, ${OUTX} ${my - 3} L ${OUTX} ${my + 3} C 120 ${my + 3}, 96 ${y1 - 1.5}, ${INX + INW} ${y1 - 1.5} Z" fill="${f.c}" opacity=".34"/>`
        + `<rect x="${OUTX}" y="${my - 3}" width="${OUTW}" height="6" rx="2.5" fill="${f.c}"/>`
        + `<path d="M${OUTX + OUTW} ${my} L ${OUTX + OUTW + 9} ${ly}" stroke="${f.c}" stroke-width="1" fill="none" opacity=".55"/>`;
      labels += `<text x="${OUTX + OUTW + 13}" y="${ly + 3.5}" font-size="10.5" fill="var(--ink)">${f.n} ¥${f.v.toLocaleString()}</text>`;
    });
    const yl = TOP + H, lyb = TOP + H + 4;
    const leftBand = left > 0 ? `<rect x="${OUTX}" y="${yl - 3}" width="${OUTW}" height="6" rx="2.5" fill="var(--cat-grocery)"/>` : '';
    $('sankeyBody').innerHTML = `
      <div class="card">
        <div class="sec" style="margin-bottom:2px">收入 → 支出 → 结余</div>
        <div class="foot" style="margin-bottom:10px">2026年9月 · 记账月 9/1–9/30</div>
        <svg viewBox="0 0 340 ${H + TOP + 34}" style="width:100%;height:auto">
          <rect x="${INX}" y="${TOP}" width="${INW}" height="${H}" rx="4" fill="var(--cat-grocery)"/>
          <text x="${INX}" y="${TOP - 4}" font-size="10" fill="var(--ink-2)">收入</text>
          <text x="${INX}" y="${TOP + H + 15}" font-size="12" font-weight="500" fill="var(--ink)">¥15,000</text>
          ${bands}${labels}${leftBand}
          <text x="${OUTX + OUTW + 13}" y="${lyb + 3.5}" font-size="10.5" font-weight="500" fill="var(--cat-grocery)">结余 ¥${left.toLocaleString()}</text>
        </svg>
      </div>
      <div class="card">
        <div class="cmp-row"><span>总收入</span><b>¥${fmt(inc)}</b></div>
        <div class="cmp-row"><span>总支出</span><b>¥${fmt(spend)}</b></div>
        <div class="cmp-row"><span>净结余</span><b style="color:${left >= 0 ? 'var(--sem-pos)' : 'var(--sem-neg)'}">¥${fmt(left)}</b></div>
        <div class="cmp-row"><span>储蓄率</span><b>${(left / inc * 100).toFixed(1)}%</b></div>
      </div>
      <div class="card note"><div class="body">桑基图回答的是「钱从哪来、流到哪去、最后剩多少」——比环形图更适合看结构，环形图更适合看占比。<br>点击任一色带可下钻至该分类的二级明细。</div></div>`;
  }

  /* ========== SP-3-04 交叉分析 ========== */
  function renderCross() {
    const catSet = ['餐饮', '食材', '交通', '购物', '居住'];
    const accSet = ['现金', '招行储蓄', '招行信用卡'];
    const M = [[210, 180, 820], [0, 356, 0], [0, 120, 110], [0, 0, 399], [0, 4500, 0]];
    const mx = Math.max(...M.flat(), 1);
    const cellCol = '46,110,142';
    const cell = (v) => v === 0 ? 'var(--surface-2)' : `rgba(${cellCol},${(v / mx * 0.85 + 0.08).toFixed(2)})`;
    $('crossBody').innerHTML = `
      <div class="card">
        <div class="sec">分类 × 账户（9 月支出）</div>
        <table class="heat-tbl">
          <tr><td></td>${accSet.map(a => `<td class="hc">${a.replace('招行', '')}</td>`).join('')}</tr>
          ${catSet.map((c, i) => `<tr><td class="hr">${c}</td>
            ${M[i].map(v => `<td class="hv2" style="color:${v > mx * 0.5 ? '#fff' : 'var(--ink-2)'};background:${cell(v)}">${v ? v.toLocaleString() : '·'}</td>`).join('')}</tr>`).join('')}
        </table>
        <div class="foot">颜色越深金额越大。空格 = 该分类在该账户上无消费。</div>
      </div>
      <div class="card">
        <div class="sec">读出来的结论</div>
        <div class="cmp-row"><span>居住几乎全部走储蓄卡</span><b>¥4,500</b></div>
        <div class="cmp-row"><span>餐饮一半以上刷信用卡</span><b>¥820</b></div>
        <div class="cmp-row"><span>现金主要用于小额餐饮与食材</span><b>¥566</b></div>
      </div>
      <div class="card note"><div class="body">交叉分析的价值在于「发现异常组合」——比如某个账户的某类支出突然变成主力，往往意味着你的支付习惯在悄悄改变。</div></div>`;
  }

  /* ========== SP-3-05 资金年龄 ========== */
  function renderAge() {
    const hist = [{ m: '4月', v: 18 }, { m: '5月', v: 21 }, { m: '6月', v: 24 }, { m: '7月', v: 27 }, { m: '8月', v: 31 }, { m: '9月', v: 34 }];
    const c = hist[hist.length - 1].v, p = hist[hist.length - 2].v;
    const mx = Math.max(...hist.map(h => h.v));
    $('ageBody').innerHTML = `
      <div class="hero brand">
        <div class="hl">资金年龄（花掉的一块钱平均停留天数）</div>
        <div class="hv">${c} <span style="font-size:15px;opacity:.75">天</span></div>
        <div class="hs"><div><span>较上月</span><b>+${c - p} 天</b></div><div><span>近 6 月趋势</span><b>持续上升</b></div></div>
      </div>
      <div class="card">
        <div class="sec" style="margin-bottom:2px">近 6 个月</div>
        <div class="mini-bars">
          ${hist.map((h, i) => `<i style="height:${h.v / mx * 100}%;background:${i === hist.length - 1 ? 'var(--primary)' : 'var(--chart-bar)'}" title="${h.m} ${h.v} 天"></i>`).join('')}
        </div>
        <div style="display:flex;gap:4px;margin-top:5px">${hist.map(h => `<div style="flex:1;text-align:center;font-size:10px;color:var(--muted)">${h.m}</div>`).join('')}</div>
      </div>
      <div class="card">
        <div class="sec">这个数字在说什么</div>
        <div class="body">
          · <b>≥ 30 天</b>：你有缓冲，花的是「一个月前赚的钱」，抗风险能力强<br>
          · <b>15–30 天</b>：正常水平，收支基本同月<br>
          · <b>&lt; 15 天</b>：月光警报，花的还是这个月刚进来的钱
        </div>
        <div class="cmp-row" style="margin-top:8px;border-top:1px solid var(--line-soft);padding-top:9px"><span>当前判定</span><b style="color:var(--sem-pos)">健康 · 有缓冲</b></div>
      </div>
      <div class="card note"><div class="body">计算口径：FIFO（先进先出）。每笔支出都从最早的收入里扣，扣到哪一天的余额就记多少天，最后取加权平均。<br>这是一种「体检指标」，不参与任何记账流程，只读不写。</div></div>`;
  }

  /* ========== SP-5-09 预算 ========== */
  const budgets = [
    { n: '餐饮', limit: 3000, used: 2780, c: 'var(--cat-food)' },
    { n: '交通', limit: 600, used: 206, c: 'var(--cat-transport)' },
    { n: '购物', limit: 1000, used: 958, c: 'var(--cat-shopping)' },
    { n: '娱乐', limit: 800, used: 120, c: 'var(--cat-entertainment)' },
    { n: '居住', limit: 4600, used: 4500, c: 'var(--cat-housing)' }
  ];
  function renderBudget() {
    const totalL = budgets.reduce((s, b) => s + b.limit, 0);
    const totalU = budgets.reduce((s, b) => s + b.used, 0);
    const p = totalU / totalL * 100;
    $('budgetBody').innerHTML = `
      <div class="card">
        <div class="seg" style="margin-bottom:10px">
          <div class="on" onclick="segBudget(this)">分类限额</div>
          <div onclick="segBudget(this)">信封预算</div>
          <div onclick="segBudget(this)">零基预算</div>
          <div onclick="segBudget(this)">50-30-20</div>
        </div>
        <div class="body">当前使用 <b>分类限额</b>：为每个分类设上限，各自独立。切换方法会重新映射已有预算，需要你确认。</div>
      </div>
      <div class="hero ${p >= 100 ? 'dark' : (p >= 90 ? 'dark' : 'brand')}" style="${p >= 100 ? 'background:var(--sem-neg)' : (p >= 90 ? 'background:var(--sem-warn)' : '')}">
        <div class="hl">本月预算已用</div>
        <div class="hv">${p.toFixed(1)}%</div>
        <div class="pbar" style="background:rgba(255,255,255,.25)"><i style="width:${Math.min(p, 100)}%;background:#fff"></i></div>
        <div class="hs" style="margin-top:9px"><div><span>已花</span><b>¥${fmt(totalU)}</b></div><div><span>预算</span><b>¥${fmt(totalL)}</b></div><div><span>剩余</span><b>¥${fmt(Math.max(totalL - totalU, 0))}</b></div></div>
      </div>
      ${budgets.map(b => {
      const r = b.used / b.limit * 100;
      const cls2 = r >= 100 ? 'over' : (r >= 90 ? 'warn' : '');
      return `
        <div class="card">
          <div style="display:flex;justify-content:space-between;font-size:13px">
            <span><span class="lg-dot" style="display:inline-block;background:${b.c}"></span> ${b.n}</span>
            <b style="color:${r >= 100 ? 'var(--sem-neg)' : 'var(--ink)'}">¥${fmt(b.used)} / ¥${fmt(b.limit)}</b>
          </div>
          <div class="pbar ${cls2}" style="margin-top:7px"><i style="width:${Math.min(r, 100)}%"></i></div>
          <div style="font-size:11px;color:${r >= 100 ? 'var(--sem-neg)' : (r >= 90 ? 'var(--sem-warn-ink)' : 'var(--muted)')};margin-top:4px">
            ${r >= 100 ? `已超支 ¥${fmt(b.used - b.limit)}` : (r >= 90 ? `仅剩 ¥${fmt(b.limit - b.used)}，注意节奏` : `剩余 ¥${fmt(b.limit - b.used)}（${(100 - r).toFixed(0)}%）`)}
          </div>
        </div>`;
    }).join('')}
      <div class="card note">
        <div class="body"><b>四套方法论：</b>信封（每类一个信封，花完即止） / 零基（收入全部预先分配，余额为 0） / 50-30-20（必要 50 · 想要 30 · 储蓄 20） / 分类限额（最轻量）。<br>
          进度条三级着色与「是否响铃通知」绑定（G-3）：<b>90% 静默提醒、100% 响铃通知</b>，但两者都不阻挡你继续记账。</div>
      </div>`;
  }
  function segBudget(el) {
    el.parentNode.querySelectorAll('div').forEach(d => d.classList.remove('on'));
    el.classList.add('on'); toast('已切换预算方法（原型演示）');
  }

  /* ========== SP-5-10 家庭与成员 ========== */
  const members = [
    { n: '我（李振宇）', role: '所有者', color: 'var(--primary)', emoji: '我', share: '—' },
    { n: '配偶', role: '成员', color: 'var(--cat-social)', emoji: '配', share: '¥4,282' },
    { n: '孩子', role: '只读', color: 'var(--sem-warn)', emoji: '孩', share: '—' }
  ];
  function renderFamily() {
    $('familyBody').innerHTML = `
      <div class="card soft"><div class="body">共享账本：多人共同记同一本账，数据实时互见。<b>与「记账伙伴」不同</b>——伙伴只是别人帮你记，不共享你的账本（G-5，两套边界不共用）。</div></div>
      <div class="mcard">
        <div class="mrow" style="cursor:default">
          <div class="grow"><div class="t1">家庭共享账本</div><div class="t2">3 名成员 · 本月共同记账 47 笔</div></div>
          <div class="sw on" onclick="this.classList.toggle('on')"></div>
        </div>
        <div class="mrow" style="cursor:default">
          <div class="grow"><div class="t1">成员消费可见性</div><div class="t2">所有成员可见全部账单</div></div>
          <span class="rt pk">设置 ›</span>
        </div>
      </div>
      <div class="card sec">成员与权限</div>
      ${members.map(m => `<div class="aim-row">
        <div class="icoc" style="background:${m.color};color:#fff">${m.emoji}</div>
        <div class="grow"><div class="t1" style="font-size:13.5px">${m.n}</div>
        <div class="t2" style="font-size:11px;margin-top:2px">${m.role}${m.share !== '—' ? ' · 本月支出 ' + m.share : ''}</div></div>
        <span class="rt pk" onclick="toast('成员权限设置（原型演示）')">管理</span>
      </div>`).join('')}
      <div class="card note">
        <div class="body">三种角色：<b>所有者</b>（可增删成员、改权限、删除账本） / <b>成员</b>（可记账、可改自己的账） / <b>只读</b>（只能看）。<br>
          成员看到的分类与主题仍是<b>各自本机偏好</b>，不会被账本同步覆盖。</div>
      </div>`;
  }

  /* ========== SP-5-11 开放接口 ========== */
  function renderApi() {
    $('apiBody').innerHTML = `
      <div class="card hint"><div class="body"><b>默认关闭。</b>开放接口会让外部程序读写你的账本，请只在明确需要时开启，并逐项限定权限范围。</div></div>
      <div class="mcard">
        <div class="mrow" style="cursor:default"><div class="icoc">API</div><div class="grow"><div class="t1">本地 REST API</div><div class="t2">仅监听 127.0.0.1，不暴露到局域网</div></div><div class="sw" onclick="this.classList.toggle('on')"></div></div>
        <div class="mrow" style="cursor:default"><div class="icoc">MCP</div><div class="grow"><div class="t1">MCP 服务（给 LLM 用）</div><div class="t2">供 Claude / Cursor 等客户端读取账本</div></div><div class="sw" onclick="this.classList.toggle('on')"></div></div>
        <div class="mrow" style="cursor:default"><div class="icoc">键</div><div class="grow"><div class="t1">访问令牌</div><div class="t2">一次生成、可随时吊销</div></div><span class="rt pk" onclick="toast('令牌已复制（原型演示）')">复制</span></div>
      </div>
      <div class="card sec">权限范围（最小必要）</div>
      <div class="mcard">
        <div class="mrow" style="cursor:default"><div class="grow"><div class="t1" style="font-size:13px">读取账单与分类</div></div><div class="sw on" onclick="this.classList.toggle('on')"></div></div>
        <div class="mrow" style="cursor:default"><div class="grow"><div class="t1" style="font-size:13px">读取预算与目标</div></div><div class="sw on" onclick="this.classList.toggle('on')"></div></div>
        <div class="mrow" style="cursor:default"><div class="grow"><div class="t1" style="font-size:13px">写入账单</div><div class="t2">建议保持关闭，写入走导入更安全</div></div><div class="sw" onclick="this.classList.toggle('on')"></div></div>
        <div class="mrow" style="cursor:default"><div class="grow"><div class="t1" style="font-size:13px">删除数据</div><div class="t2">默认永不可授予</div></div><div class="sw" style="opacity:.4"></div></div>
      </div>
      <div class="card note">
        <div class="body">接口只在本机回环地址监听，不经过任何服务器——你的账本不会因为「开放」而离开这台设备。<br>
          MCP 侧默认<b>只读</b>，写入需要单独勾选并二次确认。</div>
      </div>`;
  }

  /* ========== SP-6-01 桌面端与多端 ========== */
  const endp = [
    { n: '手机（iOS / Android）', s: '已支持', d: '3 秒记账 · 点分类即保存', ok: true },
    { n: '平板（iPad / Android Pad）', s: '已支持', d: '双栏布局 · 侧栏常驻 · 手写备注', ok: true },
    { n: '桌面（Windows / macOS）', s: 'V3.0', d: '全键盘操作 · 批量录入 · 报表打印', ok: false },
    { n: 'Web（浏览器）', s: 'V3.0', d: '免安装查看与导出 · 只读为主', ok: false }
  ];
  function renderDesk() {
    $('deskBody').innerHTML = `
      <div class="card soft"><div class="body">Flutter 工程结构<b>已含 macos / web / windows 目录</b>——四端不是「将来重做」，而是「逐步点亮」。这决定了桌面端的边际成本远低于重写。</div></div>
      ${endp.map(e => `<div class="card" style="display:flex;align-items:center;gap:12px">
        <div class="icoc ${e.ok ? '' : 'o'}">${e.ok ? '✓' : '…'}</div>
        <div class="grow"><div class="t1" style="font-size:13.5px">${e.n}</div>
        <div class="t2" style="font-size:11.5px;margin-top:2px">${e.d}</div></div>
        <span class="tag ${e.ok ? 'free' : 'v3'}">${e.s}</span>
      </div>`).join('')}
      <div class="card">
        <div class="sec">桌面端差异化能力（V3.0）</div>
        <div class="cmp-row"><span>全键盘录账（Tab 跳转 / Enter 保存）</span></div>
        <div class="cmp-row"><span>CSV / Excel 批量导入与去重</span></div>
        <div class="cmp-row"><span>报表导出 PDF 并打印</span></div>
        <div class="cmp-row"><span>多账本同开（侧栏切换）</span></div>
      </div>
      <div class="card note">
        <div class="body">桌面端与 Web 端的<b>先后顺序是开放问题</b>：Web 先行可以覆盖「临时在别人电脑上查账」，macOS 先行则贴近重度用户。建议在 V2.0 云同步落地后按真实用量决定。</div>
      </div>`;
  }

  /* ========== SP-5-02 主题 ========== */
  function applyTheme() {
    const t = THEMES.find(x => x[0] === curTheme) || THEMES[0];
    const dark = isDark();
    const p = dark ? mix(t[3], '#FFFFFF', .30) : t[3];
    const a = dark ? mix(t[4], '#FFFFFF', .22) : t[4];
    const S = document.documentElement.style;
    S.setProperty('--primary', p);
    S.setProperty('--primary-ink', dark ? mix(t[3], '#FFFFFF', .46) : mix(t[3], '#000000', .16));
    S.setProperty('--primary-soft', `rgba(${hex(p).join(',')},${dark ? .20 : .12})`);
    S.setProperty('--accent', a);
    S.setProperty('--accent-soft', `rgba(${hex(a).join(',')},${dark ? .20 : .12})`);
    document.documentElement.setAttribute('data-bright', dark ? 'dark' : 'light');
    $('phone').classList.toggle('night', dark);
    syncThemeLabels();
  }
  function syncThemeLabels() {
    const t = THEMES.find(x => x[0] === curTheme) || THEMES[0];
    const lbl = $('me-theme'); if (lbl) lbl.textContent = t[1] + ' ›';
    const sel = $('themeMode'); if (sel) sel.value = curMode;
  }
  function setTheme(id) {
    curTheme = id; applyTheme(); renderTheme();
    toast('已切换主题：' + (THEMES.find(x => x[0] === id) || [])[1]);
  }
  function setThemeMode(m) { curMode = m; applyTheme(); renderTheme(); }
  function renderTheme() {
    const modes = [['system', '跟随系统'], ['light', '浅色'], ['dark', '深色']];
    $('themeBody').innerHTML = `
      <div class="card" style="display:flex;gap:6px;padding:8px">
        ${modes.map(([v, n]) => `<button class="btn${curMode === v ? ' pri' : ''}" style="height:34px" onclick="setThemeMode('${v}')">${n}</button>`).join('')}
      </div>
      <div class="mcard">${THEMES.map(t => `
        <div class="th-row${curTheme === t[0] ? ' on' : ''}" onclick="setTheme('${t[0]}')">
          <div class="th-sw"><i style="background:${t[3]}"></i><i style="background:${t[4]}"></i></div>
          <div class="grow"><div class="t1">${t[1]}</div><div class="th-t2">${t[2]}</div></div>
          <span class="th-tick">${curTheme === t[0] ? '✓' : ''}</span>
        </div>`).join('')}</div>
      <div class="footbox">
        10 套主题全部免费，每套含浅色 / 深色两态，切换即时生效、无需重启。<br>
        主题只改外观：分类色板与收入 / 支出语义色跨主题固定；主题属本机偏好，多端同步时不覆盖其他设备。
      </div>`;
  }
  function setScale(v) { $('phone').style.zoom = v; }
  function toggleKeep(el) {
    keepOnAdd = !keepOnAdd; el.classList.toggle('on', keepOnAdd);
    toast(keepOnAdd ? '保存后留在记账页' : '保存后返回流水');
  }
  function obNext(n) {
    document.querySelectorAll('.ob-step').forEach((s, i) => s.classList.toggle('on', i === n));
    document.querySelectorAll('.ob-dots i').forEach((d, i) => d.classList.toggle('on', i === n));
  }
  function obDone() { $('s-onboard0').style.display = 'none'; go('s-home'); }

  /* ========== chips 分组 ========== */
  const CHIP_GROUPS = [
    { label: 'V1.0 基线（11 屏）', ids: ['s-onboard0', 's-home', 's-add', 's-detail', 's-cat', 's-asset', 's-report', 's-backup', 's-find', 's-me', 's-theme'] },
    { label: 'V2.0 交易精度与主动管家（8 屏）', ids: ['s-addplus', 's-split', 's-claim', 's-cardbill', 's-remind', 's-rule', 's-goal', 's-card'] },
    { label: 'V3.0 资产与方法论（10 屏）', ids: ['s-invest', 's-loan', 's-networth', 's-sankey', 's-cross', 's-age', 's-budget', 's-family', 's-api', 's-desk'] }
  ];

  /* ========== 初始化 ========== */
  function init() {
    mountPages();
    const ms = $('monthStart');
    if (ms) for (let i = 1; i <= 28; i++) {
      const o = document.createElement('option'); o.value = i; o.textContent = i + ' 号';
      if (i === 1) o.selected = true; ms.appendChild(o);
    }
    const side = document.getElementById('chipGroups');
    CHIP_GROUPS.forEach(g => {
      const gl = document.createElement('div'); gl.className = 'grp';
      const h = document.createElement('h3'); h.textContent = g.label; gl.appendChild(h);
      const row = document.createElement('div'); row.className = 'chips';
      g.ids.forEach(id => {
        const meta = SCREENS.find(x => x[0] === id); if (!meta) return;
        const c = document.createElement('span');
        c.className = 'chip'; c.dataset.s = id;
        c.textContent = meta[1] + ' ' + meta[2];
        c.onclick = () => { if (id === 's-onboard0') $('s-onboard0').style.display = ''; go(id); };
        row.appendChild(c);
      });
      gl.appendChild(row); side.appendChild(gl);
    });
    applyTheme();
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
      if (curMode === 'system') { applyTheme(); if (cur === 's-theme') renderTheme(); }
    });
    renderGrid();
    /* 支持 #s-xxx 深链：便于单屏截图 / 分享定位 */
    const h = (location.hash || '').replace('#', '');
    if (h && SCREENS.some(x => x[0] === h)) { $('s-onboard0').style.display = 'none'; go(h); }
    else go('s-onboard0');
    window.addEventListener('hashchange', () => {
      const t = (location.hash || '').replace('#', '');
      if (t && SCREENS.some(x => x[0] === t)) { $('s-onboard0').style.display = 'none'; go(t); }
    });
  }

  /* ========== 暴露到全局（onclick 需要） ========== */
  Object.assign(window, {
    go, toast, closeModal,
    kb, pickCat, toggleType, cancelAdd, startEdit, commitEdit, openDetail, askDel, doDel,
    toggleHideBal, reconcile, doReconcile,
    editCat, doEditCat, hideCat, mergeCat, addCat, doAddCat,
    makeBackup, previewBk, openAddPlus, saveAddPlus, addSplitPart, saveSplit,
    segRemind, toggleRule, toggleCard, segBudget,
    setTheme, setThemeMode, setScale, toggleKeep, obNext, obDone
  });

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
