/* Planning data for this document only. Never load as a MapDefinition or collision mask. */
window.WATERGEN_SCENE_PLAN = {
  "schema": "watergen-scene-layer-plan-v1",
  "status": "planning_only_not_runtime",
  "basis": "A 沟谷倒木 / 第三轮装饰生态 / 2838165",
  "world_size": [1280, 480],
  "image": "../fauna-round3/evidence/FAUNA-world.png",
  "annotation_geometry_is_authoritative": false,
  "current_new_scene_interactions": "none",
  "clear_zone": [320, 77, 679, 230],
  "groups": [
    {"id": "background", "name": "远景背景", "color": "#81c5ee"},
    {"id": "scenery", "name": "中景装饰", "color": "#a5dca6"},
    {"id": "binding", "name": "待绑定交互外观", "color": "#ffd17b"},
    {"id": "foreground", "name": "前景装饰", "color": "#d8b2ff"},
    {"id": "fauna", "name": "装饰动物", "color": "#ffaaa0"}
  ],
  "regions": [
    {
      "id": "B01", "name": "水色、光束与水面反光", "group": "background", "depth": "最远背景",
      "current": "静态底图的一部分；无交互。", "merge_mode": "decoration_only", "feature_id": null,
      "after_merge": "纯视觉。水面反光不决定真实 water 边界，光束不指示鱼钩或食物位置。",
      "placement": "在背景通道绘制；光束低对比，不在角色、鱼线和 HUD 上叠加亮膜。",
      "fallback": "沿用当前场景水色；不改 MapContext.water。",
      "asset": "bg_water_light", "pin": [640, 56],
      "areas": [[[460, 18], [727, 18], [815, 215], [403, 215]]]
    },
    {
      "id": "B02", "name": "远岸、远处倒木与植物剪影", "group": "background", "depth": "远景",
      "current": "静态底图的一部分；无交互。", "merge_mode": "decoration_only", "feature_id": null,
      "after_merge": "只建立纵深，鱼和鱼线可以从它们前方经过。远处木石不参与缠线、抄网阻挡。",
      "placement": "低饱和、低对比，可用轻视差；不能长得像紧贴玩家的可用缠线目标。",
      "fallback": "压低对比或缩回远景，不为剪影创建目标。",
      "asset": "bg_banks_silhouettes", "pin": [1011, 169],
      "areas": [[[12, 68], [188, 92], [306, 159], [374, 236], [268, 262], [166, 189], [18, 185]], [[941, 226], [1114, 108], [1181, 78], [1259, 126], [1220, 272], [1026, 312]]]
    },
    {
      "id": "B03", "name": "顶部浮叶与垂根", "group": "background", "depth": "顶部装饰背景",
      "current": "静态底图的一部分；无交互。", "merge_mode": "decoration_only", "feature_id": null,
      "after_merge": "不缠线、不挡网、不响应钩位。植物根须应与鱼线保持颜色、宽度及运动差异。",
      "placement": "留在顶部与两侧；过长垂根移出中央识别区。不要覆盖浮漂、鱼线或提示。",
      "fallback": "缩短、减少或省略垂根。",
      "asset": "bg_surface_roots", "pin": [1163, 43],
      "areas": [[[0, 0], [168, 0], [125, 93], [14, 94]], [[1027, 0], [1280, 0], [1280, 141], [1093, 77]]]
    },
    {
      "id": "D01", "name": "两侧坡地、沟底、沙泥与小碎石", "group": "scenery", "depth": "中景地势装饰",
      "current": "画出来的高低差；没有对应的真实高低地形。", "merge_mode": "decoration_only", "feature_id": null,
      "after_merge": "不抬高真实池底、不改变可游区。沙泥和小碎石不产生新碰撞、阻挡或缠线点。",
      "placement": "大坡面作为后方池岸，玩家鱼能从前面游过；近处收成低矮底边。与真实地面冲突时让美术退后，避免假墙。",
      "fallback": "按实际 floor_y、水域与巢穴范围重构外观；不能直接把整幅不透明坡面压入玩法层。",
      "asset": "mid_sediment_banks", "pin": [526, 433],
      "areas": [[[0, 256], [120, 301], [305, 354], [474, 390], [679, 431], [858, 449], [1053, 414], [1191, 362], [1280, 315], [1280, 480], [0, 480]]]
    },
    {
      "id": "D02", "name": "矮草、地毯藻、宽叶草与丝状藻", "group": "scenery", "depth": "中景植物装饰",
      "current": "静态植物群落；无交互。", "merge_mode": "decoration_only", "feature_id": null,
      "after_merge": "丰富生态，不新增减速区、草缠线目标或碰撞。长在坡脚和沟底不代表能够缠线。",
      "placement": "以低矮、横向成片的形态与交互高草区分；依附公开地形/表面挂点，不读取鱼钩。",
      "fallback": "没有合适挂点则稀疏或省略；不得推导新的 gameplay 区域。",
      "asset": "mid_plant_communities", "pin": [148, 278],
      "areas": [[[101, 246], [153, 235], [195, 282], [161, 309], [105, 303]], [[479, 395], [582, 406], [675, 421], [665, 448], [496, 428]], [[998, 348], [1035, 335], [1070, 386], [1038, 411], [996, 394]]]
    },
    {
      "id": "I01", "name": "近处倒木与左侧断桩", "group": "binding", "depth": "主活动层的交互外观候选",
      "current": "尚未绑定。图中的整根横跨倒木现在不能缠线或挡网。", "merge_mode": "existing_target_skin_only", "feature_id": null,
      "after_merge": "只有对上已有 wood target 的部分才承接原缠线、抄网阻挡、接触淡化等行为；不会变成阻挡玩家鱼的实心墙。",
      "placement": "跟随原木头 polygon、位置、target index 与 fade_group；附生植物/蜗牛随宿主同步淡化。",
      "fallback": "本图长倒木不能硬拉伸去连接分散目标。无匹配时改构图，或作为低对比远景；不新增目标或把目标间空隙连成障碍。",
      "asset": "bound_wood_skin", "pin": [656, 351],
      "areas": [[[180, 326], [199, 276], [208, 233], [224, 220], [242, 258], [293, 279], [482, 316], [690, 351], [722, 323], [738, 326], [711, 367], [984, 401], [1000, 417], [971, 425], [796, 400], [801, 437], [787, 426], [779, 398], [525, 365], [325, 322], [252, 299], [262, 356], [231, 347], [207, 338]]]
    },
    {
      "id": "I02", "name": "近处大石块", "group": "binding", "depth": "主活动层的交互外观候选",
      "current": "尚未绑定。不是每一块画出的石头都能交互。", "merge_mode": "existing_target_skin_only", "feature_id": null,
      "after_merge": "匹配已有 stone target 后继承该目标原有能力；小碎石仍归 D01，不扩大阻挡或缠线范围。",
      "placement": "纹理贴合已有 polygon；可识别轮廓与原接触边界一致，保留 target_opacity。",
      "fallback": "图中右侧大石不在现有目标位置时，重排/重绘石块；不能移动真实石块来迁就底图。",
      "asset": "bound_stone_skin", "pin": [1114, 343],
      "areas": [[[1010, 372], [1043, 333], [1081, 308], [1122, 295], [1168, 312], [1175, 364], [1135, 402], [1059, 413]], [[333, 374], [356, 347], [404, 334], [441, 355], [456, 393], [382, 397]]]
    },
    {
      "id": "I03", "name": "少量可辨识的交互高草", "group": "binding", "depth": "主活动层的交互外观候选",
      "current": "两侧高草只标作形态参考，尚未认领任何真实 grass target。", "merge_mode": "existing_target_skin_only", "feature_id": null,
      "after_merge": "只有绑定到已有 grass target 的草丛才沿用缠线、束草与接触淡化；减速仍只由既有 vegetation_drag_zones 决定。",
      "placement": "保持实际根点、bounds、back 标志与原变形带。交互草用清楚、成束的轮廓，不能把所有群落都标成交互。",
      "fallback": "没有 grass target 的高草改成低对比远景或减少；不因草长得高而新增减速区。",
      "asset": "bound_grass_skin", "pin": [91, 206],
      "areas": [[[53, 147], [92, 130], [149, 170], [160, 240], [130, 289], [69, 275]], [[1195, 220], [1243, 158], [1275, 178], [1280, 318], [1223, 342], [1199, 288]]]
    },
    {
      "id": "D03", "name": "木石上的苔藻与附生植物", "group": "scenery", "depth": "宿主表面的附着装饰",
      "current": "已画进底图；不是独立可交互对象。", "merge_mode": "host_decoration_only", "feature_id": null,
      "after_merge": "植物自身不能缠线或挡网；宿主存在交互时，仍由原木石负责。",
      "placement": "跟随宿主变换、裁剪与同一淡化值；不让木头淡化后留下悬浮绿壳。",
      "fallback": "未匹配公开宿主则不放置附着物；不要从隐藏状态寻找宿主。",
      "asset": "attached_moss_epiphytes", "pin": [387, 300],
      "areas": [[[286, 271], [353, 279], [397, 292], [427, 306], [416, 316], [338, 300], [286, 286]], [[1070, 303], [1125, 282], [1161, 289], [1169, 304], [1110, 310], [1061, 331]]]
    },
    {
      "id": "F01", "name": "画面底沿与两角的深色近景", "group": "foreground", "depth": "近景框景",
      "current": "底图中的深色土沿/草叶；没有交互。", "merge_mode": "decoration_only", "feature_id": null,
      "after_merge": "前景仅表示离镜头近。不能碰撞、缠线、减速或挡网，也不能遮住巢穴和食物。",
      "placement": "低矮、限制在边缘；合并时仍早于玩家与前方鱼线绘制。若遮到 NPC/缠线后方通道则缩小或裁除。",
      "fallback": "受巢穴、出生点、饵位、镜头及 HUD 安全区约束；不能只靠 A 图中央留白矩形。",
      "asset": "fg_bank_frame", "pin": [98, 439],
      "areas": [[[0, 368], [88, 389], [208, 437], [411, 469], [450, 480], [0, 480]], [[962, 480], [1078, 443], [1160, 400], [1280, 360], [1280, 480]]]
    },
    {
      "id": "E01", "name": "沿底部活动的 3 只小虾", "group": "fauna", "depth": "中景装饰动物",
      "current": "独立像素精灵；本地视觉时间驱动，无交互。", "merge_mode": "decoration_only", "feature_id": null,
      "after_merge": "不可吃、不可钓、不挡网、不参与 NPC AI 或网络快照。",
      "placement": "在真实可公开的表面挂点附近限幅活动；保持小体型、低对比，位于 gameplay 识别通道之前。",
      "fallback": "目前 A 图挂点需要重新适配；不把 (170,339) 等美术坐标当作地图真值。",
      "asset": "decor_fauna_atlas_shrimp", "pin": [469, 398],
      "areas": [[[151, 328], [188, 328], [188, 354], [151, 354]], [[445, 403], [486, 403], [486, 431], [445, 431]], [[938, 420], [977, 420], [977, 444], [938, 444]]]
    },
    {
      "id": "E02", "name": "木石表面的 2 只蜗牛", "group": "fauna", "depth": "附着装饰动物",
      "current": "独立像素精灵；触角变化，无交互。", "merge_mode": "host_decoration_only", "feature_id": null,
      "after_merge": "不可吃、不可钓，没有自己的 target；原木石的交互能力不传给蜗牛。",
      "placement": "挂点绑定公开宿主；宿主淡化时同步淡化，避免看起来浮在消失的石头上。",
      "fallback": "没有合适宿主或清晰表面则省略该只蜗牛。",
      "asset": "decor_fauna_atlas_snail", "pin": [1131, 266],
      "areas": [[[423, 304], [451, 304], [451, 325], [423, 325]], [[1107, 285], [1135, 285], [1135, 306]]]
    },
    {
      "id": "E03", "name": "两组远景小鱼群", "group": "fauna", "depth": "远景装饰动物",
      "current": "2 组各 5 条；独立视觉时间，无交互。", "merge_mode": "decoration_only", "feature_id": null,
      "after_merge": "与现有 gameplay NPC 是两套对象。它们不抢食、不被钓起、不触发声光反馈，不根据暗钩/目标鱼改变行为。",
      "placement": "低对比、小尺寸、在背景通道；保持中央活动区清楚。",
      "fallback": "与实际食物或识别区域冲突时限制装饰范围或省略；不查询隐藏钩位。",
      "asset": "decor_fauna_atlas_school", "pin": [249, 145],
      "areas": [[[198, 126], [297, 126], [297, 176], [198, 176]], [[1019, 204], [1122, 204], [1122, 253], [1019, 253]]]
    }
  ]
};
