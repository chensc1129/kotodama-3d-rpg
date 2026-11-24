# 言霊剣士・あの一撃 3D（Godot 4.3+ 跨平台版）

> 🎮 **立即線上遊玩（GitHub Pages）**：https://chensc1129.github.io/kotodama-3d-rpg/

由原版網頁 Three.js 作品完整移植至 **Godot 4.3+（GDScript / GL Compatibility 渲染器）** 的全 3D 日文動作 RPG，支援桌面（Windows / macOS / Linux）、Web（HTML5）與行動裝置匯出。

## 專案架構

```text
kotodama_3d_rpg/
├── project.godot              # Godot 4.3+ 專案設定（GL Compatibility、Autoload、輸入映射、TTS）
├── icon.svg                   # 鳥居「あ」遊戲圖示
├── resources/
│   └── ui_theme.tres          # 繁體中文／日文系統字型主題
├── scenes/
│   └── main.tscn              # 主場景（3D 世界、攝影機、戰鬥管理、HUD 與各彈窗）
└── scripts/
    ├── autoload/
    │   ├── game_data.gd       # 角色、關卡、裝備、式神、怪物、Boss、日文詞庫、祝福資料
    │   ├── game_state.gd      # 玩家存檔（user://kotodama_3d_rpg_v2_save.json）與戰鬥狀態
    │   └── audio_manager.gd   # 程式化複音合成音效（AudioStreamGenerator）＋日文 TTS
    ├── world/
    │   ├── arena_3d.gd        # 4 張 3D 場地建構（圓形道場、鳥居、石燈籠、落花／火星粒子）
    │   ├── camera_rig.gd      # 第三人稱軌道鏡頭（滑鼠／觸控拖曳旋轉、滾輪縮放）
    │   └── ring_vfx_3d.gd     # 3D 擴散衝擊波光環特效
    ├── entities/
    │   ├── player_3d.gd       # 5 位角色 3D 模型、裝備外觀同步、3D 頭頂銘牌與動作
    │   ├── shikigami_3d.gd    # 式神夥伴模型與跟隨動畫
    │   ├── enemy_3d.gd        # 6 種妖怪與 3 種 Boss 模型與控場狀態視覺
    │   └── enemy_projectile_3d.gd
    ├── combat/
    │   └── battle_manager.gd  # 核心戰鬥、波次生成、AI、三段斬、瞬步與言霊詠唱技能
    └── ui/
        ├── ui_style.gd        # 玻璃擬態風格工具
        ├── virtual_joystick.gd# 360° 虛擬類比輪盤（支援多點觸控與滑鼠）
        ├── floating_popup_layer.gd # 3D 轉 2D 浮動傷害數字
        ├── hud_ui.gd          # 頂部狀態列、Boss 血條、底部操作與日文感應輸入框
        ├── chant_overlay.gd   # 子彈時間日文詠唱視窗（手打 1.5 倍暴擊／四選一）
        ├── lobby_modal.gd     # 大廳（自訂名稱、5 角色、4 場景、4 模式）
        ├── upgrade_modal.gd   # 技能升級／裝備鍛造／式神契約
        └── blessing_modal.gd  # 幕間 3 選 1 Roguelite 祝福
```

## 相較原版 HTML 已修復的問題

1. **修正鍵位衝突**：`W/A/S/D` 與方向鍵專用於移動，普攻改綁 `J`／日文 `あ` 鍵，專屬技能改綁 `1`／`K`，奧義為 `2`／`Q`，瞬步為 `Space`，不再因移動誤觸攻擊或詠唱。
2. **修正繁／日漢字詞庫配對**：每位角色改用明確的 `chant_word_id`（例如腳鬥士→`脚・足`、雪女→`氷結`），確保專屬技能每次都正確配對專屬日文單字。
3. **修正重開局祝福殘留**：從大廳重新開始戰鬥時完整呼叫 `GameState.reset_battle_state()`，清空上一局的幕間祝福與連擊狀態。
4. **補完雪女寒霜持續傷害**：凍結狀態下會依角色說明定期觸發寒霜傷害。

## 開啟與執行方式

1. 下載並開啟 **Godot 4.3 或更新版本**（標準版即可，不需 .NET）。
2. 在專案管理員點擊「匯入（Import）」，選擇本資料夾內的 `project.godot`。
3. 按下 `F5` 直接遊玩！

## HTML5 網頁版匯出（已內建單執行緒設定與中／日／Emoji 字型）

- 已內建 `export_presets.cfg`（`variant/thread_support=false`，無須設定 COOP/COEP 標頭即可部署於 GitHub Pages、Netlify、Cloudflare Pages 或任何靜態網站主機）。
- 已打包精簡版 **Noto Sans CJK TC Bold**（約 499 KB）與 **Noto Color Emoji**（約 132 KB），確保網頁版繁體中文、日文假名與表情符號不會缺字。
- 匯出成品位於 `build/web/index.html`（含 `.js`、`.wasm`、`.pck`），於本機測試時請在 `build/web/` 目錄啟動簡易 HTTP 伺服器（例如 `python3 -m http.server 8080`）後以瀏覽器開啟，不可直接 `file://` 雙擊開啟（瀏覽器 CORS 會阻擋載入 `.wasm` 與 `.pck`）。
