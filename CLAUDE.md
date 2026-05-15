# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

为 Noita 游戏 Mod 开发的实体组件系统 Lua 封装库。提供面向对象的 API，通过 Proxy 元表实现组件字段的属性风格读写。

## Key Files

- `entity-lib.lua` — 库的主文件，包含所有类和逻辑
- `annotations/comp_text.lua` — 所有 Noita 原生组件类型的 LuaLS 类型注解（~65000 tokens）
- `examples/` — 示例目录（当前为空）

## Architecture

单文件库，无外部依赖。核心机制：

```
class() ── OOP 工具（__call 构造 + 单继承）
    │
Component ── 组件代理（__index/__newindex 元表 → ComponentGetValue2/ComponentSetValue2）
    │
Entity ── 基础实体
  ├── Animals ── 生物（HP、承伤倍率、效果、阵营）
  │   └── Player ── 玩家（鼠标、拾取、法杖）
  ├── Item ── 物品（UI 信息）
  │   ├── Action_Card ── 法术牌
  │   └── Wand ── 法杖（添加法术）
  └── Perk ── 天赋（stub）
```

`ComponentFactory:new` 通过 `__index`/`__newindex` 将组件字段读写映射到 `ComponentGetValue2`/`ComponentSetValue2`，支持嵌套 object 字段（通过 `get_object` 递归代理）。

## Type Annotations

整个库使用 LuaLS 注解格式。`annotations/comp_text.lua` 定义了所有 Noita 组件的完整类型（~400+ 个组件类），通过 `---@class AIAttackComponent : Component` 继承自库内的 Component 基类。Entity 类的 get_comp 等方法返回这些注解过的 Component 类型。

## Remaining Work

- `Wand:get_ation()` 和 `Wand:get_ations()` 未实现（stub）
- `Perk` 类未实现功能
- `examples/` 目录为空
- 没有测试和构建脚本

## Key Patterns

- **实体构造**: `Player(entity_id)` 或 `Player:new(entity_id)`
- **组件读写**: `local dmg = player:damagemodel_comp()` → `dmg.hp = 100`
- **object 字段**: `local gun_config = comp:get_object("gun_config")` → `gun_config.deck_capacity`
- **Logger**: 默认静默，可替换：`Lib.logger.setLogger(custom_logger)`
