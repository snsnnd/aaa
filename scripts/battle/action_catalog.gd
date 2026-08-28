class_name ActionCatalog
extends RefCounted

## 动作目录：每张卡的动作属性（Entry Pose / Exit Pose / Movement / Impact / Tags）。
## 卡牌定义"做什么"（CardSystem effects），动作定义"怎么动"（本文件），
## 表现层定义"怎么看起来"——三者解耦，调卡牌数值不需要碰动画。
##
## 姿态词汇表（pose）：neutral / high / low / left / right / thrust / spell / guard / parry_exit
## 位移词汇表（movement）：none / step / lunge / dash / retreat / leap
## 冲击等级（impact）：LIGHT / MEDIUM / HEAVY / STAGGER / BREAK / INTERRUPT / FINISHER

const LEVELS := ["LIGHT", "MEDIUM", "HEAVY", "BREAK", "FINISHER"]  # 伤害类升级阶梯
const COMBO_WINDOW := 2.6          # 连招窗口（秒）：窗口内出牌视为衔接
const FINISHER_COMBO := 3          # 终结动作开放的连招等级

## 每张卡的动作 id；未列出者按类别取默认动作。
const CARD_ACTIONS := {
	# 斩（红）：我怎么打
	"attack": "act_zhijian",         # 斩纸：低位起手，右位收，垫步
	"zhuying": "act_zhuying",        # 逐影：右→左，突进，追击
	"liebo": "act_liebo",            # 裂帛：左→右，横斩
	"duannian": "act_duannian",      # 断念：高→低，下劈
	"xuezhang": "act_xuezhang",      # 血账：低→高，挑斩
	"shatter": "act_shatter",        # 还刃：高位重斩，突进
	"shoulian": "act_shoulian",      # 收殓：终结向突进
	"yuangui": "act_yuangui",        # 怨归：低位刺击
	"tianping": "act_tianping",      # 极·天平倒悬：跳跃终结
	"baiguyin": "act_baiguyin",      # 白骨引：符术起手
	"shuangdeng": "act_shuangdeng",  # 双灯照：左→右双段
	"zhuangzhong": "act_zhuangzhong",# 撞钟：高位连段凝滞
	# 御（蓝）：敌人怎么打
	"guard": "act_guard",            # 镇煞：从戒备打出
	"difan": "act_difan",            # 低幡：低位扫幡
	"fuhunsuo": "act_fuhunsuo",      # 缚魂索：符术锁敌
	"jiedao": "act_jiedao",          # 借刀：戒备中截招
	"tongjing": "act_tongjing",      # 铜镜：布符
	"jinshen": "act_jinshen",        # 金身：护身桩
	"podan": "act_podan",            # 破胆：退步喝符
	"duanxiang": "act_duanxiang",    # 断香：焚香
	"yandeng": "act_yandeng",        # 延灯：拖住灯焰
	"jiezou": "act_jiezou",          # 劫奏：刺入其节奏
	"huangdeng": "act_huangdeng",    # 晃灯：布符
	"jieshi": "act_jieshi",          # 借势：戒备中蓄势
	# 佑（黄）：这段战斗按什么规则打
	"shift": "act_shift",            # 续灯
	"dengxin": "act_dengxin",        # 灯芯
	"tianyou": "act_tianyou",        # 添油
	"jieshou": "act_jieshou",        # 借寿：符术
	"wenlu": "act_wenlu",            # 问路：布符
	"zhima": "act_zhima",            # 纸马：召符
	"changming": "act_changming",    # 长明：桩功
	"anhun": "act_anhun",            # 安魂：符转戒备
	"tinggeng": "act_tinggeng",      # 听更
	"chageng": "act_chageng",        # 查更：布符
}

const DEFAULT_BY_CLASS := {
	"斩": "act_zhijian",
	"御": "act_guard",
	"佑": "act_shift",
}

## 动作定义库。字段：type(PLAYER/ENEMY_TIMELINE/RULE) entry_pose exit_pose movement
## startup impact_time recovery cancel_window impact_level combo_tags
const ACTIONS := {
	# —— 斩：玩家攻击动作 ——
	"act_zhijian": {"title": "斩纸·直斩", "type": "PLAYER", "entry_pose": "low", "exit_pose": "right", "movement": "step", "startup": 0.10, "impact_time": 0.22, "recovery": 0.28, "cancel_window": 0.16, "impact_level": "LIGHT", "combo_tags": ["chain"]},
	"act_zhuying": {"title": "逐影·突进", "type": "PLAYER", "entry_pose": "right", "exit_pose": "left", "movement": "dash", "startup": 0.08, "impact_time": 0.20, "recovery": 0.24, "cancel_window": 0.18, "impact_level": "LIGHT", "combo_tags": ["chase", "chain", "opener"]},
	"act_liebo": {"title": "裂帛·横斩", "type": "PLAYER", "entry_pose": "left", "exit_pose": "right", "movement": "none", "startup": 0.12, "impact_time": 0.24, "recovery": 0.30, "cancel_window": 0.16, "impact_level": "MEDIUM", "combo_tags": ["chain"]},
	"act_duannian": {"title": "断念·下劈", "type": "PLAYER", "entry_pose": "high", "exit_pose": "low", "movement": "none", "startup": 0.16, "impact_time": 0.30, "recovery": 0.34, "cancel_window": 0.18, "impact_level": "MEDIUM", "combo_tags": ["chain"]},
	"act_xuezhang": {"title": "血账·挑斩", "type": "PLAYER", "entry_pose": "low", "exit_pose": "high", "movement": "step", "startup": 0.14, "impact_time": 0.26, "recovery": 0.32, "cancel_window": 0.18, "impact_level": "MEDIUM", "combo_tags": ["chain"]},
	"act_shatter": {"title": "还刃·重斩", "type": "PLAYER", "entry_pose": "high", "exit_pose": "low", "movement": "lunge", "startup": 0.22, "impact_time": 0.36, "recovery": 0.46, "cancel_window": 0.12, "impact_level": "HEAVY", "combo_tags": ["heavy"]},
	"act_shoulian": {"title": "收殓·合葬", "type": "PLAYER", "entry_pose": "right", "exit_pose": "left", "movement": "lunge", "startup": 0.20, "impact_time": 0.34, "recovery": 0.44, "cancel_window": 0.12, "impact_level": "HEAVY", "combo_tags": ["finisher"]},
	"act_yuangui": {"title": "怨归·刺击", "type": "PLAYER", "entry_pose": "low", "exit_pose": "thrust", "movement": "lunge", "startup": 0.18, "impact_time": 0.30, "recovery": 0.40, "cancel_window": 0.14, "impact_level": "HEAVY", "combo_tags": ["finisher"]},
	"act_tianping": {"title": "天平·倒悬", "type": "PLAYER", "entry_pose": "high", "exit_pose": "thrust", "movement": "leap", "startup": 0.30, "impact_time": 0.48, "recovery": 0.60, "cancel_window": 0.0, "impact_level": "HEAVY", "combo_tags": ["finisher"]},
	"act_baiguyin": {"title": "白骨·引魂", "type": "PLAYER", "entry_pose": "spell", "exit_pose": "spell", "movement": "none", "startup": 0.12, "impact_time": 0.20, "recovery": 0.26, "cancel_window": 0.20, "impact_level": "LIGHT", "combo_tags": ["setup"]},
	"act_shuangdeng": {"title": "双灯·照影", "type": "PLAYER", "entry_pose": "left", "exit_pose": "right", "movement": "step", "startup": 0.16, "impact_time": 0.30, "recovery": 0.36, "cancel_window": 0.16, "impact_level": "MEDIUM", "combo_tags": ["chain"]},
	"act_zhuangzhong": {"title": "撞钟·震魂", "type": "PLAYER", "entry_pose": "high", "exit_pose": "high", "movement": "none", "startup": 0.14, "impact_time": 0.26, "recovery": 0.30, "cancel_window": 0.18, "impact_level": "STAGGER", "combo_tags": ["stagger"]},
	# —— 御：敌招时间轴动作 ——
	"act_guard": {"title": "镇煞·封步", "type": "ENEMY_TIMELINE", "entry_pose": "guard", "exit_pose": "neutral", "movement": "none", "startup": 0.08, "impact_time": 0.18, "recovery": 0.30, "cancel_window": 0.20, "impact_level": "STAGGER", "combo_tags": ["counter"]},
	"act_difan": {"title": "低幡·扫地", "type": "ENEMY_TIMELINE", "entry_pose": "low", "exit_pose": "low", "movement": "none", "startup": 0.10, "impact_time": 0.20, "recovery": 0.26, "cancel_window": 0.20, "impact_level": "STAGGER", "combo_tags": ["stagger"]},
	"act_fuhunsuo": {"title": "缚魂·锁拍", "type": "ENEMY_TIMELINE", "entry_pose": "spell", "exit_pose": "spell", "movement": "none", "startup": 0.14, "impact_time": 0.24, "recovery": 0.30, "cancel_window": 0.18, "impact_level": "STAGGER", "combo_tags": ["timeline"]},
	"act_jiedao": {"title": "借刀·截招", "type": "ENEMY_TIMELINE", "entry_pose": "guard", "exit_pose": "neutral", "movement": "step", "startup": 0.06, "impact_time": 0.16, "recovery": 0.28, "cancel_window": 0.22, "impact_level": "INTERRUPT", "combo_tags": ["timeline", "counter", "opener"]},
	"act_tongjing": {"title": "铜镜·布面", "type": "ENEMY_TIMELINE", "entry_pose": "spell", "exit_pose": "spell", "movement": "none", "startup": 0.10, "impact_time": 0.18, "recovery": 0.24, "cancel_window": 0.22, "impact_level": "LIGHT", "combo_tags": ["setup"]},
	"act_jinshen": {"title": "金身·护桩", "type": "RULE", "entry_pose": "guard", "exit_pose": "guard", "movement": "none", "startup": 0.10, "impact_time": 0.16, "recovery": 0.24, "cancel_window": 0.22, "impact_level": "LIGHT", "combo_tags": ["setup"]},
	"act_podan": {"title": "破胆·退喝", "type": "ENEMY_TIMELINE", "entry_pose": "spell", "exit_pose": "spell", "movement": "retreat", "startup": 0.12, "impact_time": 0.20, "recovery": 0.28, "cancel_window": 0.18, "impact_level": "LIGHT", "combo_tags": ["timeline"]},
	"act_duanxiang": {"title": "断香·焚引", "type": "ENEMY_TIMELINE", "entry_pose": "spell", "exit_pose": "spell", "movement": "none", "startup": 0.10, "impact_time": 0.18, "recovery": 0.24, "cancel_window": 0.22, "impact_level": "LIGHT", "combo_tags": ["timeline"]},
	"act_yandeng": {"title": "延灯·拖拍", "type": "ENEMY_TIMELINE", "entry_pose": "spell", "exit_pose": "spell", "movement": "retreat", "startup": 0.12, "impact_time": 0.20, "recovery": 0.26, "cancel_window": 0.20, "impact_level": "LIGHT", "combo_tags": ["timeline", "opener"]},
	"act_jiezou": {"title": "劫奏·断拍", "type": "ENEMY_TIMELINE", "entry_pose": "thrust", "exit_pose": "left", "movement": "step", "startup": 0.10, "impact_time": 0.20, "recovery": 0.28, "cancel_window": 0.20, "impact_level": "LIGHT", "combo_tags": ["timeline", "opener"]},
	"act_huangdeng": {"title": "晃灯·摇影", "type": "RULE", "entry_pose": "spell", "exit_pose": "spell", "movement": "none", "startup": 0.10, "impact_time": 0.16, "recovery": 0.22, "cancel_window": 0.22, "impact_level": "LIGHT", "combo_tags": ["setup"]},
	"act_jieshi": {"title": "借势·蓄劲", "type": "RULE", "entry_pose": "guard", "exit_pose": "parry_exit", "movement": "none", "startup": 0.10, "impact_time": 0.16, "recovery": 0.24, "cancel_window": 0.24, "impact_level": "LIGHT", "combo_tags": ["setup", "counter"]},
	# —— 佑：规则/条件动作 ——
	"act_shift": {"title": "续灯·调息", "type": "RULE", "entry_pose": "neutral", "exit_pose": "neutral", "movement": "none", "startup": 0.08, "impact_time": 0.12, "recovery": 0.20, "cancel_window": 0.26, "impact_level": "LIGHT", "combo_tags": ["rule"]},
	"act_dengxin": {"title": "灯芯·挑火", "type": "RULE", "entry_pose": "neutral", "exit_pose": "neutral", "movement": "none", "startup": 0.08, "impact_time": 0.12, "recovery": 0.20, "cancel_window": 0.26, "impact_level": "LIGHT", "combo_tags": ["rule"]},
	"act_tianyou": {"title": "添油·润芯", "type": "RULE", "entry_pose": "neutral", "exit_pose": "neutral", "movement": "none", "startup": 0.08, "impact_time": 0.12, "recovery": 0.20, "cancel_window": 0.26, "impact_level": "LIGHT", "combo_tags": ["rule"]},
	"act_jieshou": {"title": "借寿·引火", "type": "RULE", "entry_pose": "spell", "exit_pose": "spell", "movement": "none", "startup": 0.12, "impact_time": 0.18, "recovery": 0.26, "cancel_window": 0.22, "impact_level": "LIGHT", "combo_tags": ["rule"]},
	"act_wenlu": {"title": "问路·布符", "type": "RULE", "entry_pose": "spell", "exit_pose": "spell", "movement": "none", "startup": 0.10, "impact_time": 0.14, "recovery": 0.22, "cancel_window": 0.26, "impact_level": "LIGHT", "combo_tags": ["setup"]},
	"act_zhima": {"title": "纸马·召符", "type": "RULE", "entry_pose": "spell", "exit_pose": "spell", "movement": "none", "startup": 0.14, "impact_time": 0.20, "recovery": 0.28, "cancel_window": 0.22, "impact_level": "LIGHT", "combo_tags": ["rule"]},
	"act_changming": {"title": "长明·桩功", "type": "RULE", "entry_pose": "guard", "exit_pose": "neutral", "movement": "none", "startup": 0.10, "impact_time": 0.16, "recovery": 0.22, "cancel_window": 0.24, "impact_level": "LIGHT", "combo_tags": ["rule"]},
	"act_anhun": {"title": "安魂·净化", "type": "ENEMY_TIMELINE", "entry_pose": "spell", "exit_pose": "guard", "movement": "none", "startup": 0.12, "impact_time": 0.20, "recovery": 0.26, "cancel_window": 0.22, "impact_level": "MEDIUM", "combo_tags": ["counter", "rule"]},
	"act_tinggeng": {"title": "听更·辨拍", "type": "RULE", "entry_pose": "neutral", "exit_pose": "neutral", "movement": "none", "startup": 0.08, "impact_time": 0.12, "recovery": 0.20, "cancel_window": 0.26, "impact_level": "LIGHT", "combo_tags": ["setup"]},
	"act_chageng": {"title": "查更·探路", "type": "RULE", "entry_pose": "spell", "exit_pose": "spell", "movement": "none", "startup": 0.10, "impact_time": 0.14, "recovery": 0.22, "cancel_window": 0.26, "impact_level": "LIGHT", "combo_tags": ["setup"]},
}


static func action_for(card_id: String, card_class: String) -> Dictionary:
	var aid := String(CARD_ACTIONS.get(card_id, DEFAULT_BY_CLASS.get(card_class, "act_zhijian")))
	var def: Dictionary = ACTIONS.get(aid, ACTIONS["act_zhijian"])
	var out := def.duplicate(true)
	out["id"] = aid
	return out
