# 游戏特效资产库规范 (VFX Assets Library) v1.0

> 本目录为独立特效资产包，**不修改任何项目原有源码与逻辑**。可直接在 Godot 编辑器中预览、独立实例化或未来在表现层（`battle_vfx.gd`）中平滑替换。

---

## 一、目录结构

```text
assets/game/vfx/
├── scenes/               # 10 个独立预制体特效场景 (.tscn)
│   ├── vfx_perfect_parry.tscn       # 完美弹反破煞大爆发（8层满规格反馈）
│   ├── vfx_guard_arc.tscn           # 防范金光护盾弧光
│   ├── vfx_paper_burst.tscn         # 斩纸/断念：水墨刀弧与符纸碎屑
│   ├── vfx_counter_slash.tscn       # 还刃/乘势：十字重斩与炽热余烬
│   ├── vfx_seal_ring.tscn           # 镇煞/缚魂：冷青八卦收束阵
│   ├── vfx_bell_wave.tscn           # 撞钟/听更：铜铃音波共振环
│   ├── vfx_soul_embers.tscn         # 续灯/灯芯：命火光晕与升腾余烬
│   ├── vfx_ghost_flame_burst.tscn   # 幽冥鬼火：三色敌招起手预兆
│   ├── vfx_hit_sparks.tscn          # 通用受击/格挡火星
│   └── vfx_death_dissolve.tscn      # 超度解脱/消散魂光与纸灰
├── textures/             # 11 张高精度程序化水墨/怪谈风格材质贴图 (.png)
│   ├── tex_spark_sharp.png          # 白金十字星芒/针状闪光 (512x512)
│   ├── tex_slash_arc.png            # 水墨刀光月牙月弧 (512x512)
│   ├── tex_talisman_shard.png       # 朱砂黄纸符片/破损符箓 (512x512)
│   ├── tex_ink_splatter.png         # 国风水墨飞溅与离散墨滴 (512x512)
│   ├── tex_shockwave_ring.png       # 高频能量冲击波环 (512x512)
│   ├── tex_seal_bagua.png           # 道教八卦镇煞法阵 (512x512)
│   ├── tex_bell_ripple.png          # 铜钟声波同心涟漪 (512x512)
│   ├── tex_ghost_flame.png          # 幽冥磷火/鬼气火焰 (512x512)
│   ├── tex_ember_particle.png       # 命火菱形余烬微粒 (256x256)
│   ├── tex_slash_cross.png          # 十字重斩光刃 (512x512)
│   └── tex_noise_dissolve.png       # 符纸燃烧/消散无缝噪波 (512x512)
├── shaders/              # 4 套 CanvasItem 专用着色器 (.gdshader)
│   ├── vfx_shockwave_distort.gdshader # 屏幕空间径向折射与色差冲击波
│   ├── vfx_talisman_burn.gdshader     # 符纸燃烧消散（金红边缘烧焦）
│   ├── vfx_ghost_aura.gdshader        # 动态幽冥鬼雾/磷光流动
│   └── vfx_additive_glow.gdshader     # HDR 叠加辉光与呼吸脉冲
├── scripts/
│   └── vfx_standalone_emitter.gd      # 独立特效控制器（支持编辑器预览与自释放）
└── vfx_manifest.json     # 特效资产清单
```

---

## 二、特效资产规范与设计对应表

| 场景资产 | 触发事件 / 对应卡牌 | 视觉层次与构成 | 持续时间 |
|---|---|---|---|
| `vfx_perfect_parry.tscn` | 完美防范（★ 最高爽点） | 白金十字闪光 + 水墨裂痕 + 冲击波扩散环 + 反向飞溅符纸 + 高速火花 | 0.85s |
| `vfx_guard_arc.tscn` | 玩家按下防范（Space） | 暖金半月形护盾弧光展开 + 边缘细微火星 | 0.45s |
| `vfx_paper_burst.tscn` | 斩纸 / 断念 | 水墨斩切轨迹 + 飞散黄纸符片 + 墨水烟雾 | 0.55s |
| `vfx_counter_slash.tscn` | 还刃（僵直乘势） | 金红双重十字重斩 + 核心白光 + 烈焰余烬 | 0.60s |
| `vfx_seal_ring.tscn` | 镇煞 / 缚魂 | 八卦阵盘旋转收敛 + 向心聚拢幽蓝符咒粒子 + 定身染色 | 0.80s |
| `vfx_bell_wave.tscn` | 撞钟 / 更夫铜锣 | 双重声波金色涟漪扩震 + 声学共振微粒 | 0.65s |
| `vfx_soul_embers.tscn` | 续灯 / 灯芯 / 添油 | 命火暖橙色光晕脉冲 + 向上升腾的温暖灯火余烬 | 0.90s |
| `vfx_ghost_flame_burst.tscn` | 敌招意图（赤/碧/青） | 幽冥鬼火升腾爆发（支持通过 modulate 切换赤嗔/碧痴/青疑三色） | 0.75s |
| `vfx_hit_sparks.tscn` | 攻击命中 / 受击 | 方向性白金色受击火星飞溅 + 命中接触闪点 | 0.35s |
| `vfx_death_dissolve.tscn` | 厉鬼超度消散 / 玩家倒下 | 升华蓝色/青白灵魂微光 + 飘逸纸灰与神圣光晕 | 1.30s |

---

## 三、独立资产特性说明

1. **零源码耦合**：所有资源打包为自包含的 `PackedScene`，在 `VFXStandaloneEmitter` 驱动下可独立运行或挂载。
2. **编辑器实时预览**：在 Godot 编辑器内打开任意 `.tscn`，勾选属性面板上的 `Preview Trigger` 即可随时循环播放看效果。
3. **性能友好**：粒子均使用参数化 `CPUParticles2D` 驱动，兼容所有渲染后端（Compatibility、Mobile、Forward+），避免特定平台 shader 崩溃。
4. **接入方法（未来接入时）**：
   ```gdscript
   var vfx_scene: PackedScene = preload("res://assets/game/vfx/scenes/vfx_perfect_parry.tscn")
   var vfx_node = vfx_scene.instantiate()
   vfx_node.position = hit_position
   add_child(vfx_node)
   ```
