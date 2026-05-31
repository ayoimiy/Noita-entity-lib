# Capability 分类与声明式设计

## 现状

所有 Capability 用统一的 `{getter={}, setter={}}` 结构，每个字段手写闭包。实际可归为 4 类，其中 3 类的闭包是高度重复的机械模板。

---

## 四类 Capability 及处理方式

### 第一类：单组件透传 → `component_facade()` 工厂

**特征**: 整个 Capability 只访问一种 Noita 组件，>80% 字段是 `comp.field` 透传。

| Capability | 数据来源 | 透传字段 | 自定义字段 |
|------------|---------|---------|-----------|
| `damage_model` | DamageModelComponent | `hp`, `max_hp` | `damage_muls` (经 get_object) |
| `herd_id` | GenomeDataComponent | `herd_id` | — |
| `sprite` | SpriteComponent | `alpha` | — |
| `velocity` | VelocityComponent | — | `velocity` (经 get_value2 + Vector2D) |

**处理**: 一个工厂函数，输入组件获取方法和字段规格，输出标准 `{getter, setter}`。

```lua
local function component_facade(get_comp, fields, err_name)
    local getter, setter = {}, {}
    for name, spec in pairs(fields) do
        if type(spec) == "table" and (spec.get or spec.set) then
            if spec.get then getter[name] = spec.get end
            if spec.set then setter[name] = spec.set end
        else
            local target = (type(spec) == "string") and spec or name
            getter[name] = function(self)
                local c = get_comp(self)
                return c and c[target]
            end
            setter[name] = function(self, v)
                local c = get_comp(self)
                if c then c[target] = v
                elseif err_name then _M.logger:error(err_name) end
            end
        end
    end
    return { getter = getter, setter = setter }
end
```

**使用示例**:

```lua
Capability.damage_model = component_facade(
    function(self) return self:damagemodel_comp(true) end,
    {
        hp      = true,         -- 透传
        max_hp  = true,         -- 透传
        damage_muls = {         -- 自定义
            get = function(self) ... end,
            set = function(self, v) ... end,
        },
    }
)

Capability.herd_id = component_facade(
    function(self) return self:genome_data_comp(true) end,
    { herd_id = true },
    "查找herd_id时无法查找到组件"
)
```

---

### 第二类：多组件门面 → 手写 + `cap_fields()` 辅助

**特征**: 一个 Capability 聚合 2~3 种不同组件，每种组件负责一组字段。内部有多个 accessor。

| Capability | 数据来源 |
|------------|---------|
| `wand_ability` | AbilityComponent 直接字段 + `.gun_config` 对象 + `.gunaction_config` 对象 |
| `wand_sprite` | AbilityComponent + SpriteComponent + HotspotComponent |
| `item` | ItemComponent + AbilityComponent |

**处理**: 每个 accessor 用 `cap_fields()` 生成该组的 getter/setter，再用 `merge_caps()` 拼合。有 Vector2D 转换、多字段扇出等复杂逻辑的字段仍然手写。

```lua
local function cap_fields(accessor, fields, err_name)
    -- 实现同 component_facade
end

local function merge_caps(...)
    local merged = { getter = {}, setter = {} }
    for _, cap in ipairs({...}) do
        for k, v in pairs(cap.getter or {}) do merged.getter[k] = v end
        for k, v in pairs(cap.setter or {}) do merged.setter[k] = v end
    end
    return merged
end
```

**使用示例**:

```lua
Capability.wand_ability = merge_caps(
    cap_fields(function(self) return self:ability_comp(true) end, {
        mana_max          = true,
        mana_charge_speed = true,
        click_to_use      = true,
    }, "wand_ability: 无法获取 ability_component"),

    cap_fields(_gun_config, {
        deck_capacity          = true,
        actions_per_round      = true,
        reload_time            = true,
        shuffle_deck_when_empty = true,
    }, "wand_ability: 无法获取 gun_config 对象"),

    cap_fields(_gunaction_config, {
        fire_rate_wait  = true,
        spread_degrees  = true,
        speed_mul       = "speed_multiplier",   -- 字段名映射
    }, "wand_ability: 无法获取 gunaction_config 对象")
)

Capability.wand_sprite = merge_caps(
    cap_fields(function(self) return self:ability_comp(true) end, {
        sprite_file = true,
    }),
    cap_fields(function(self) return self:sprite_comp(true) end, {
        image_file = true,
    }),
    -- 自定义：Vector2D 多字段扇出
    {
        getter = { sprite_offset = function(self) ... end },
        setter = { sprite_offset = function(self, v) ... end },
    },
    -- 自定义：get_value2 访问
    {
        getter = { hotspot_offset = function(self) ... end },
        setter = { hotspot_offset = function(self, v) ... end },
    }
)
```

---

### 第三类：缓存数据读取 → `cache_data_facade()` 工厂

**特征**: 字段值来自静态数据缓存表（`_actions_cache` / `_perks_cache`），全是只读，模板完全相同。

| Capability | 缓存表 | 影响字段数 |
|------------|--------|-----------|
| `action` (缓存部分) | `_actions_cache[self.action_id]` | ~11 个 |
| `perk` (缓存部分) | `_perks_cache[self.perk_id]` | ~18 个 |

**处理**: 专用工厂只生成 getter，setter 为空。

```lua
local function cache_data_facade(cache, key_accessor, fields)
    local getter = {}
    for name, spec in pairs(fields) do
        if type(spec) == "table" and spec.get then
            getter[name] = spec.get
        else
            local key = (type(spec) == "string") and spec or name
            getter[name] = function(self)
                local data = cache[key_accessor(self)]
                return data and data[key]
            end
        end
    end
    return { getter = getter, setter = {} }
end
```

**使用示例**:

```lua
Capability.perk = merge_caps(
    cache_data_facade(_perks_cache, function(self) return self.perk_id end, {
        ui_name            = true,
        ui_description     = true,
        ui_icon            = true,
        game_effect        = true,
        stackable          = true,
        -- ... 其余 ~14 个字段
    }),
    -- perk_id 和 count 是第四类，手写
    {
        getter = {
            perk_id = function(self) ... end,
            count   = function(self) ... end,
        },
        setter = {
            perk_id = function(self, v) ... end,
            count   = function(self, v) ... end,
        },
    }
)
```

---

### 第四类：特殊 API 调用 → 保持手写闭包

**特征**: 每个字段有独特的 API 调用或转换逻辑，声明式没有收益。

| Capability/字段 | 特殊之处 |
|----------------|---------|
| `position.pos` | EntityGetTransform / EntitySetTransform + Vector2D 转换 |
| `Entity.name` | EntityGetName → GameTextGetTranslatedOrNot 翻译 |
| `Entity.tags` | EntityGetTags → 逗号分割字符串 → table |
| `Entity.file_name` | EntityGetFilename |
| `perk.perk_id` | 遍历 variable_comps 按 name 匹配 |
| `perk.count` | GlobalsGetValue / GlobalsSetValue 全局标志 |

直接写 `{getter={...}, setter={...}}`，通过 `merge_caps` 与其他部分拼合。

---

## 字段规格语法总结

同一个字段名在 `fields` 表中的值决定了生成行为：

| spec 值 | 生成效果 | 适用场景 |
|---------|---------|---------|
| `true` | `obj[name]` ↔ `obj[name]` | API 字段名与对外名相同 |
| `"other_name"` | `obj["other_name"]` ↔ `obj["other_name"]` | API 字段名与对外名不同，值直接透传 |
| `{get=fn}` | 只读，调用 fn | 缓存只读数据、计算属性 |
| `{set=fn}` | 只写，调用 fn | 仅写入场景 |
| `{get=fn, set=fn}` | 完全自定义 | 类型转换、多字段扇出、经 get_value2 读写 |

四种语法可在同一个 Capability 中混用。

---

## 架构约束

- 三个工厂产出的全部是标准 `{getter={}, setter={}}` 结构
- `add_capability()` 和 `class()` **不需要任何修改**
- 迁移可以按 Capability 逐个进行，不需要一次全部切换
- `merge_caps` 按参数顺序合并，后出现的覆盖先出现的（与当前行为一致）
