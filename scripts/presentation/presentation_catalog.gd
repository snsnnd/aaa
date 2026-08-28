extends RefCounted

## 表现目录：所有纯表现数据（文案/颜色/图标/立绘/音频路径）。
## 铁律：BattleSimulation 不得引用本文件；本文件不含任何玩法数值。
## 换皮肤/换音效/换图标只改这里，战斗结果（content_hash）不受影响。

const CARD_PRESENTATION := {
	"attack": {"title": "斩纸", "color": Color("d3a44b"), "icon": "res://assets/game/cards/card_attack.png"},
	"shatter": {"title": "还刃", "color": Color("bd3d45"), "icon": "res://assets/game/cards/card_shatter.png"},
	"guard": {"title": "镇煞", "color": Color("43a9b2"), "icon": "res://assets/game/cards/card_guard.png"},
	"shift": {"title": "续灯", "color": Color("6d9663"), "icon": "res://assets/game/cards/card_shift.png"},
	"duannian": {"title": "断念", "color": Color("c98862"), "icon": "res://assets/game/cards/card_duannian.png"},
	"dengxin": {"title": "灯芯", "color": Color("8fae72"), "icon": "res://assets/game/cards/card_dengxin.png"},
	"zhuangzhong": {"title": "撞钟", "color": Color("b0925c"), "icon": "res://assets/game/cards/card_zhuangzhong.png"},
	"anhun": {"title": "安魂", "color": Color("9ab0a2"), "icon": "res://assets/game/cards/card_anhun.png"},
	"duanxiang": {"title": "断香", "color": Color("7fa89a"), "icon": "res://assets/game/cards/card_duanxiang.png"},
	"tinggeng": {"title": "听更", "color": Color("8fae9e"), "icon": "res://assets/game/cards/card_tinggeng.png"},
	"jieshi": {"title": "借势", "color": Color("c9b96a"), "icon": "res://assets/game/cards/card_jieshi.png"},
	"tongjing": {"title": "铜镜", "color": Color("a8c0c8"), "icon": "res://assets/game/cards/card_tongjing.png"},
	"podan": {"title": "破胆", "color": Color("9a7ab8"), "icon": "res://assets/game/cards/card_podan.png"},
	"jinshen": {"title": "金身", "color": Color("c8b88a"), "icon": "res://assets/game/cards/card_jinshen.png"},
	"zhuying": {"title": "逐影", "color": Color("e09c48"), "icon": "res://assets/game/cards/card_zhuying.png"},
	"liebo": {"title": "裂帛", "color": Color("d85c54"), "icon": "res://assets/game/cards/card_liebo.png"},
	"xuezhang": {"title": "血账", "color": Color("c83832"), "icon": "res://assets/game/cards/card_xuezhang.png"},
	"baiguyin": {"title": "白骨引", "color": Color("c0d5dc"), "icon": "res://assets/game/cards/card_baiguyin.png"},
	"shoulian": {"title": "收殓", "color": Color("bfae95"), "icon": "res://assets/game/cards/card_shoulian.png"},
	"shuangdeng": {"title": "双灯照", "color": Color("e6a850"), "icon": "res://assets/game/cards/card_shuangdeng.png"},
	"yuangui": {"title": "怨归", "color": Color("c43232"), "icon": "res://assets/game/cards/card_yuangui.png"},
	"tianping": {"title": "极·天平倒悬", "color": Color("e54238"), "icon": "res://assets/game/cards/card_tianping.png"},
	"difan": {"title": "低幡", "color": Color("5898aa"), "icon": "res://assets/game/cards/card_difan.png"},
	"fuhunsuo": {"title": "缚魂索", "color": Color("48a8b8"), "icon": "res://assets/game/cards/card_fuhunsuo.png"},
	"jiedao": {"title": "借刀", "color": Color("52b8be"), "icon": "res://assets/game/cards/card_jiedao.png"},
	"tianyou": {"title": "添油", "color": Color("e8a238"), "icon": "res://assets/game/cards/card_tianyou.png"},
	"wenlu": {"title": "问路", "color": Color("82b888"), "icon": "res://assets/game/cards/card_wenlu.png"},
	"zhima": {"title": "纸马", "color": Color("92b884"), "icon": "res://assets/game/cards/card_zhima.png"},
	"changming": {"title": "长明", "color": Color("e8b04a"), "icon": "res://assets/game/cards/card_changming.png"},
	"jieshou": {"title": "借寿", "color": Color("d85248"), "icon": "res://assets/game/cards/card_jieshou.png"},
}

const CARD_FRAMES := {
	"斩": "res://assets/game/ui/card_frame_zhan.png",
	"御": "res://assets/game/ui/card_frame_yu.png",
	"佑": "res://assets/game/ui/card_frame_you.png",
}

const PARALLAX_LAYERS := [
	{"texture": "res://assets/game/environments/old_street/bg_layer0_sky_moon.png", "z": -30, "drift": 0.3},
	{"texture": "res://assets/game/environments/old_street/bg_layer1_distant_eaves.png", "z": -25, "drift": 0.6},
	{"texture": "res://assets/game/environments/old_street/bg_layer2_mid_buildings.png", "z": -20, "drift": 1.0},
	{"texture": "res://assets/game/environments/old_street/bg_layer3_ground_puddles.png", "z": -15, "drift": 1.8},
	{"texture": "res://assets/game/environments/old_street/bg_layer4_foreground_fog.png", "z": -8, "drift": 2.6},
]

const CHARACTER_SLICES := {
	"keeper_body": "res://assets/game/characters_sliced/keeper_body_clean.png",
	"keeper_lantern": "res://assets/game/characters_sliced/keeper_lantern_prop.png",
}

const MOVE_PRESENTATION := {
	"red": {"color": Color("bd3d45")},
	"blue": {"color": Color("43a9b2")},
	"green": {"color": Color("6d9663")},
	"quick": {"color": Color("d0a45c")},
}

const ENEMY_PRESENTATION := {
	"watchman": {"texture": "res://assets/demo/enemy_watchman.png"},
	"lantern_imp": {"texture": "res://assets/game/enemies/lantern_imp.png"},
	"patrol_corpse": {"texture": "res://assets/game/enemies/patrol_corpse.png"},
	"barber_ghost": {"texture": "res://assets/game/enemies/barber_ghost.png"},
	"paper_apprentice": {"texture": "res://assets/game/enemies/paper_apprentice.png"},
	"well_sisters": {"texture": "res://assets/game/enemies/well_sisters.png"},
	"gambler_ghost": {"texture": "res://assets/game/enemies/gambler_ghost.png"},
	"mortuary_warden": {"texture": "res://assets/game/enemies/mortuary_warden.png"},
	"lantern_keeper": {"texture": "res://assets/game/enemies/lantern_keeper.png"},
}

const AUDIO := {
	"parry": "res://assets/demo/audio/parry.wav",
	"hurt": "res://assets/demo/audio/hurt.wav",
	"card": "res://assets/demo/audio/card.wav",
	"warning": "res://assets/demo/audio/warning.wav",
}
