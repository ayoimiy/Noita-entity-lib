
---@class yoiEntity
---@field Vector2D Vector2D|fun(x:number,y:number):Vector2D 二维向量
---@field Entity yoiEntity.Entity|fun(entity:number|string,pos?:Vector2D):yoiEntity.Entity
---@field Item yoiEntity.Item|fun(entity:number|string,pos?:Vector2D):yoiEntity.Item 物品类
---@field Animals yoiEntity.Animals|fun(entity:number|string,pos?:Vector2D):yoiEntity.Animals   动物类
---@field Player yoiEntity.Player|fun(entity:number|string,pos?:Vector2D):yoiEntity.Player 玩家类
---@field Perk yoiEntity.Perk|fun(str:number|string,pos?:Vector2D):yoiEntity.Perk 天赋类
---@field Wand yoiEntity.Wand|fun(entity:number|string,pos?:Vector2D)):yoiEntity.Wand
---@field Action_Card yoiEntity.Action_Card|fun(str:number|string,pos?:Vector2D):yoiEntity.Action_Card 法术类
---@method set_logger(newlogger:table) 设置新的logger
local M = {} 

local _M = {}
-------------------------------------------------------------------------------------------
--[[
    日志部分
]]
local logger = {}
function logger:error(msg)
    error(msg)
end
function logger:warn(msg)
    GamePrint(msg)
end
_M.logger = logger

-------------------------------------------------------------------------------------------
--[[
    通用函数部分
]]

local function add_capability(self,...)
    for _,cap in ipairs({...}) do 
        --设置属性获取器
        for name,fn in pairs(cap.getter) do 
            self.__getter[name] = fn
        end
        --设置属性设置器
        for name,fn in pairs(cap.setter) do 
            self.__setter[name] = fn
        end
    end
end
---@param entity yoiEntity.Entity
local function get_id(entity)
    if type(entity) == 'number' then
        return entity
    elseif type(entity) == 'table' then
        return entity.id
    end
end
---@param _class_name string  类名
---@param base? table
local function class(_class_name,base,...)
    --类的元表方法
    local _class = setmetatable({},{
        __index = base or nil ,   --父类方法和属性只读
        --实现构造函数，创建实例直接用call即可，并且子类只需要写字段的初始化，而无需new 
        __call = function (c,...)
            local obj = setmetatable({},c)
            if obj.init then 
                local r =obj:init(...) 
                if r == false then
                    return nil
                end
            end
            return obj
        end
    })    
    --类属性
    _class.__getter = {}
    _class.__setter  = {}
    --类方法，用以控制实例对象
    _class.__index = function (self,key)
        --先查找类自己的字段(self是实例)
        local field = _class[key]
        if field ~=nil  then
            return field
        end
        --查找类的getter访问属性
        local getter = _class.__getter[key]
        if getter~=nil  then
           return getter(self)
        end
        --没有返回nil
        return nil 
    end
    _class.__newindex = function (self,key,value)
        --只查找类的setter访问器
        local setter = _class.__setter[key]
        if setter then
            setter(self,value)
            return 
        end
        _M.logger:error(_class_name ..  "no such field:"..tostring(key) .. "")
    end
    _class._class_name = _class_name

    --继承父类的属性
    if base then
        for name,fn in pairs(base.__getter) do
            _class.__getter[name] = fn 
        end
        for name,fn in pairs(base.__setter) do 
            _class.__setter[name] = fn 
        end 
    end
    
    --自己的属性
    add_capability(_class,...)
    return _class
end
---二维向量
---@class Vector2D
---@field x number 默认为0
---@field y number 默认为0
---@method unpack()
local Vector2D =class("Vector2D")
Vector2D.__add = function (a,b)
    return Vector2D(a.x+b.x,a.y+b.y)
end
function Vector2D:init(x,y)
    rawset(self,"x",x or 0)
    rawset(self,"y",y or 0)
end
function Vector2D:unpack()
    return self.x,self.y
end
---伤害类型
---@class DamageType
---@field melee number|nil 
---@field projectile number|nil
---@field explosion number|nil
---@field electricity number|nil
---@field fire number|nil
---@field drill number|nil
---@field slice number|nil
---@field ice number|nil
---@field healing number|nil
---@field physics_hit number|nil
---@field radioactive number|nil
---@field poison number|nil
---@field overeating number|nil
---@field curse number|nil
---@field holy number|nil
local DamageType = setmetatable({},{
    __call = function(self,...)
        local t = {}
        setmetatable(t,self)
        return t
    end
})
DamageType.__index = function (self,key)
    return nil
end



-------------------------------------------------------------------------------------------
--[[
    数据缓存表
]]
--法术数据缓存
local _actions_cache = {}
setmetatable(_actions_cache,{
    __index = function(self,key)
        if not next(self) then
            dofile_once("data/scripts/gun/gun_enums.lua")
            dofile_once("data/scripts/gun/gun_actions.lua")
            for i,v in ipairs(actions or {}) do 
                self[v.id] = v 
            end
        end
        return rawget(self,key)
    end
})
--天赋数据缓存
local _perks_cache = {}
setmetatable(_perks_cache,{
    __index = function(self,key) 
        if not next(self) then
            dofile_once( "data/scripts/perks/perk_list.lua" )
            for i,v in ipairs(perk_list or {}) do 
                self[v.id] = v 
            end
        end
        return rawget(self,key)
    end
})

-------------------------------------------------------------------------------------------

---函数
---@param get_comp fun(self) 组件
---@param fields table 字段名
---@param error_msg? string 错误信息
---@return table{getter:table,setter:table}
local function cap_fields(get_comp,fields,error_msg)
    local getter,setter = {},{}
    for name,cap in pairs(fields) do 
        if type(cap) == "table" and (cap.get or cap.set) then
            --自定义处理
            if cap.get then
                getter[name] = function (self)
                    local c = get_comp(self)
                    return c and cap.get(self,c)
                end
            end
            if cap.set then 
                setter[name] = function (self,v)
                    local c = get_comp(self)
                    if c then 
                        cap.set(self,c,v)
                    elseif error_msg then 
                        _M.logger:error(error_msg)
                    else
                        _M.logger:error("no such component:"..tostring(name))
                    end
                end
            end 
        else
            --为字段
            local target = type(cap) == "string" and cap or name
            getter[name] = function (self)
                local c = get_comp(self)
                return c and c[target]
            end
            setter[name] = function (self,v)
                local c = get_comp(self)
                if c then 
                    c[target] = v
                elseif error_msg then 
                    _M.logger:error(error_msg)
                else
                    _M.logger:error("no such component:"..tostring(cap))
                end
            end
        end
    end
    return {
        getter = getter,
        setter = setter
    }
end
---@return table{getter:table,setter:table}
local function merge_cap(...)
    local setter,getter = {},{}
    for _,cap in ({...})  do
        for name,fn in pairs(cap.getter or {}) do
            getter[name] = fn
        end
        for name,fn in pairs(cap.setter or {}) do
            setter[name] = fn
        end
    end
    return {
        getter = getter,
        setter = setter
    }
end
---@param cache table 缓存表
---@param get_key function 获取缓存key
---@param fields table 字段
---@return table {getter:table,setter:table}
local function _cache_data_cap(cache,get_key,fields)
    local getter = {}
    for name,cap in pairs(fields) do
        if type(cap) == "table" and (cap.get) then
            getter[name] = function (self)
                return cap.get(self,cache,get_key(self))
            end
        else
            local key = type(cap) == "string" and cap or name
            getter[name] = function (self)
                local data = cache[get_key(self)]
                return data and data[key]
            end
        end
    end


    return {
        getter = getter
    }
end


--能力
local Capability = {
}
---@class Capability.position 
---@field pos Vector2D 坐标
Capability.position = {
    getter = { 
        pos = function (self)
            local x,y = EntityGetTransform(self.id)
            return Vector2D(x,y)            
        end
    },
    setter = {
        pos = function (self,pos)
            EntitySetTransform(self.id,pos:unpack())
        end
    }
}
---@class Capability.Entity
---@field name string|nil 实体名称
---@field file_name string|nil 实体文件名
---@field id number|nil 实体ID
---@field tags string[]|nil 实体标签
Capability.Entity = {
    getter = {
        name = function (self)
            local name = EntityGetName(self.id)
            if name == "" then
                return nil
            end
            return GameTextGetTranslatedOrNot(name)
        end,
        file_name = function (self)
            return EntityGetFilename(self.id)
        end,
        id = function (self)
            return self.id 
        end,
        tags = function (self)
            local tags = {}
            local s_tags =EntityGetTags(self.id)
            if not s_tags then return nil end
            for  tag in string.gmatch(s_tags,"([^,]+)") do
                table.insert(tags,tag)
            end
            return tags
        end
    },
    setter = {
    }
}

local function _damage_multipliers(self)
    local comp = self:damagemodel_comp(true)
    return comp and comp:get_object("damage_multipliers")
end

---@class Capability.damage_model
---@field hp number|nil
---@field max_hp number|nil
---@field damage_muls table|nil
Capability.damage_model = merge_cap(
    cap_fields(function(self)  return self:damagemodel_comp(true) end ,{
            hp = true,
            max_hp = true,
        },
        "无法获取对应damage_model组件"
    ),
    cap_fields(_damage_multipliers,{
        damage_muls = {
            get = function (self,comp)
                local damage_muls = ComponentObjectGetMembers(comp.id,"damage_multipliers") or {}
                local damage = DamageType()
                for k,v in pairs(damage_muls) do
                    damage[k] = v and tonumber(v)
                end
                return damage
            end,
            set  = function (self,comp,damage_muls)
                for k,v in pairs(damage_muls) do
                    comp[k] = v 
                end
            end
            }
        },
        "无法获取对应的damage_multipliers对象"
    )   
)
---@class Capability.herd_id
---@field herd_id number|nil
Capability.herd_id = cap_fields(
    function(self) return self:genome_data_comp(true) end,
    {herd_id = true},
    "无法获取GenomeDataComponent组件"
)

---@class Capability.wand_ability
---@field deck_capacity number|nil  法杖容量
---@field actions_per_round number|nil 施法数
---@field fire_rate_wait number|nil 延迟(按帧)
---@field reload_time number|nil 充能时间(按帧)
---@field spread_degrees number|nil 散射角度
---@field speed_mul number|nil 速度倍率
---@field shuffle_deck_when_empty boolean|nil 是否乱序
---@field mana_max number|nil 最大法力
---@field mana_charge_speed number|nil 回蓝速度
---@field click_to_use boolean|nil 是否能够点击使用

local function _gun_config(self)
    local comp = self:ability_comp(true)
    return comp and  comp:get_object("gun_config")
end

local function _gunaction_config(self)
    local comp = self:ability_comp(true)
    return comp and  comp:get_object("gunaction_config")
end

Capability.wand_ability = merge_cap(
    cap_fields(function(self) return self:ability_comp(true) end,{
            mana_max = true,
            mana_charge_speed = true,
            click_to_use = true
        },
        "无法获取AbilityComponent组件"
    ),
    cap_fields(_gun_config,{
            deck_capacity = true,
            actions_per_round = true,
            reload_time = true,
            shuffle_deck_when_empty = true,
        },
        "无法获取AbilityComponent组件或其gun_config对象"
    ),
    cap_fields(_gunaction_config,{
            fire_rate_wait = true,
            spread_degrees = true,
            speed_mul = "speed_multiplier",       
        },
        "无法获取AbilityComponent组件或其gunaction_config对象"
    )
)

---@class Capability.wand_sprite
---@field sprite_file string|nil 法杖在背包显示的图像路径
---@field image_file string|nil 法杖在手上显示的图像路径
---@field sprite_offset Vector2D|nil 法杖在手上显示的图像偏移
---@field hotspot_offset Vector2D|nil  法杖在手上显示的图像热点偏移(即发射法术的地方)
Capability.wand_sprite = merge_cap(
    cap_fields(function(self) return self:ability_comp(true) end,{
            sprite_file = true,
        },
        "无法获取AbilityComponent组件"
    ),
    cap_fields(function(self) return self:sprite_comp(true) end,{
            image_file = true,
            sprite_offset = {
                get = function (self,comp)
                    return Vector2D(comp.offset_x,comp.offset_y)
                end,
                set = function (self,comp,offset)
                    comp.offset_x = offset.x or comp.offset_x
                    comp.offset_y = offset.y or comp.offset_y
                end,
            }
        },
        "无法获取SpriteComponent组件"
    ),
    cap_fields(function(self) return self:hotspot_comp(true,"shoot_pos") end,{
            hotspot_offset = {
                get = function (self,comp)
                    return Vector2D(comp:get_value2("offset"))
                end,
                set =  function (self,comp,offset)
                    comp:set_value2("offset",offset:unpack())
                end
            }
        },
        "无法获取HotspotComponent组件"
    )
)



---@class Capability.sprite
---@field alpha number|nil 透明度
Capability.sprite = cap_fields(
    function(self) return self:sprite_comp(true) end,
    {
        alpha = true
    },
    "无法获取SpriteComponent组件"
)

---@class Capability.item
---@field item_name string|nil 
---@field always_use_item_name_in_ui boolean|nil 
---@field inventory_slot Vector2D|nil 布局坐标
---@field ui_name string|nil
---@field ui_description string|nil
---@field ui_sprite string|nil

Capability.item = merge_cap(
    cap_fields(function(self) return self:item_comp(true) end,{
            item_name = true,
            always_use_item_name_in_ui = true,
            inventory_slot = {
                get = function (self,comp)
                    local x,y = comp:get_value2("inventory_slot")
                    return Vector2D(x,y)
                end,
                set = function (self,comp,pos)
                    comp:set_value2("inventory_slot",pos:unpack())
                end,
            },
            ui_description = true,
            ui_sprite = true,
        },
        "无法获取ItemComponent组件"
    ),
    cap_fields(function(self) return self:ability_comp(true) end,{
            ui_name = true,
        },
        "无法获取AbilityComponent组件"
    )
)
---@class Capability.action
---@field action_id string|nil  修改其会改变除了在世界显示的图像以外的法术属性
---@field name string|nil 只读
---@field description string|nil 只读
---@field sprite string|nil  在世界的图像路径(法术标识)
---@field sprite_unidentified string|nil 只读，不知道什么用_
---@field type number|nil @readonly常量,只读
---@field spawn_level string|nil 只读
---@field spawn_probability number|nil 只读
---@field price number|nil 只读
---@field related_projectiles string[]|nil 只读
---@field action function|nil 执行的函数 只读
---@field max_uses number|nil 最大可用次数,只读
---@field uses_remaining number|nil 当前可用次数,默认为-1
---@field custom_xml_file string|nil 只读，法术在法杖内，法杖产生的例子效果等(如黑洞的紫色光粒)
---@field permanently_attached boolean|nil 是否为永久法术
Capability.action = merge_cap(
    _cache_data_cap(
        _actions_cache,
        function(self) return self.action_id end,
        {
            name = true,
            description = true,
            type = true,
            spawn_level = true,
            spawn_probability =true,
            price = true,
            related_projectiles = true,
            action = true,
            max_uses = true,
            sprite_unidentified  = true,
            custom_xml_file = true,
        }
    ),
    cap_fields(function(self) return self:item_action_comp(true) end,{
            action_id = true,
        },
        "无法获取ItemActionComponent组件"
    ),
    cap_fields(function(self) return self:sprite_comp(true, "item_identified") end,{
            sprite = "image_file",
        },
        "无法获取SpriteComponent组件"
    ),
    cap_fields(function(self) return self:item_comp(true) end,{
            uses_remaining = true,
            permanently_attached = true,
        },
        "无法获取ItemComponent组件"
    )
)
--[[
    待办：
    天赋类 name = "perk_id",
]]
---@class Capability.perk
---@field perk_id string  天赋ID
---@field count number 已捡起的天赋数量
---@field ui_name string 天赋在界面上显示的名字（可读）
---@field ui_description string 天赋在界面上的描述（可读）
---@field ui_icon string 屏幕右上角的天赋图标路径（可读）
---@field perk_icon string 地图上的天赋图标路径（可读）
---@field remove_other_perks string[] 获取后从天赋池中移除的其他天赋ID列表（可读）
---@field one_off_effect string 一次性效果（可读）
---@field game_effect string 游戏效果，如爆炸免疫（可读）
---@field game_effect2 string 第二个游戏效果（可读）
---@field particle_effect string 粒子效果（可读）
---@field stackable boolean 天赋是否可堆叠（可读）
---@field stackable_how_often_reappears number 天赋序列中至少间隔几个才会再次出现，stackable为false时启用（可读）
---@field stackable_is_rare boolean 是否标记为稀有天赋，稀有天赋在序列中只出现一次，stackable为false时启用（可读）
---@field stackable_maximum number 最大可堆叠数量，stackable为false时启用（可读）
---@field max_in_perk_pool number 天赋池中的最大数量（可读）
---@field usable_by_enemies boolean 是否可以被敌人使用（可读）
---@field func function 拾取天赋时调用的函数，参数(entity_perk_item, entity_who_picked, item_name)（可读）
---@field func_remove function 天赋被移除时调用的函数，参数同上（可读）
---@field func_enemy function 天赋在敌人身上的特殊效果函数，参数同上（可读）
---@field not_in_default_perk_pool boolean 是否不在默认天赋池中生成，默认false（可读）
---@field do_not_remove boolean 是否不会被天赋祭坛移除（可读）
Capability.perk = merge_cap(
    _cache_data_cap(
        _perks_cache,
        function(self) return self.perk_id end,
        {
            ui_name = true,
            ui_description = true,
            ui_icon = true,
            perk_icon = true,
            remove_other_perks = true,
            one_off_effect = true,
            game_effect = true,
            game_effect2 = true,
            particle_effect = true,
            stackable = true,
            stackable_how_often_reappears = true,
            stackable_is_rare = true,
            stackable_maximum = true,
            max_in_perk_pool = true,
            usable_by_enemies = true,
            func = true,
            func_remove = true,
            func_enemy = true,
            not_in_default_perk_pool = true,
            do_not_remove = true,
        }
    ),{
        getter = {
            perk_id = function(self)
                local comps = self:variable_comps(true)
                for i,comp in ipairs(comps or {}) do
                    if comp.name == 'perk_id' then
                        return comp.value_string
                    end
                end
                _M.logger:warn('获取perk_id失败')
                return nil
            end,
            count = function(self)
                local perk_id = self.perk_id
                local flag = string.format('PERK_PICKED_%s_PICKUP_COUNT',perk_id)
                return tonumber(GlobalsGetValue(flag,'0'))
            end,
        },
        setter = {
            perk_id = function (self,perk_id)
                local comps = self:variable_comps(true)
                for i,comp in ipairs(comps or {}) do
                    if comp.name == 'perk_id' then
                        comp.value_string = perk_id
                        return
                    end
                end
                _M.logger:error("无法找到对应的perk_id")
            end,
            count = function (self,count)
                local perk_id = self.perk_id
                local flag = string.format('PERK_PICKED_%s_PICKUP_COUNT',perk_id)
                GlobalsSetValue(flag,tostring(count))
            end
        }
    }
)
local function _damage_critical(self)
    local comp = self:get_comp("ProjectileComponent",true)
    return comp and comp:get_object("damage_critical")
end

---@class Capability.projectile
---@field lifetime number 当前生命时长
---@field max_lifetime number 最大生命周期
---@field on_collision_die boolean 碰撞后死亡
---@field friendly_fire boolean 友伤
---@field damage DamageType 伤害
---@field type string 投射物类型
---@field critical_chance number 暴击概率
---@field critical_mul number 暴击倍率
---@field who_shot   number 射出者
Capability.projectile = merge_cap(
    cap_fields(
        function (self) return self:get_comp("ProjectileComponent",true) end,
        {
            lifetime = true,  
            friendly_fire = true,
            on_collision_die = true,
            damage = {
                get = function (self,comp)
                    local damage_by_type = ComponentObjectGetMembers(comp.id,"damage_by_type")
                    local damages = DamageType()
                    for type_name,v in pairs(damage_by_type or {}) do
                        damages[type_name] = tonumber(v)
                    end
                    damages.projectile = comp.damage                    
                    return damages
                end,
                set = function (self,comp,damages)
                    local damage_by_type = comp:get_object("damage_by_type")
                    for type_name,v in pairs(damages or {}) do
                        if type_name == "projectile" then
                            comp.damage = v
                        else
                            damage_by_type[type_name] = v
                        end                       
                    end                    
                end
            },
            who_shot = "mWhoShot" ,
        }
    ),
    cap_fields(
        function (self) return self:get_comp("LifetimeComponent",true) end,
        {
            max_lifetime = "lifetime",            
        }
    ),
    cap_fields(
        _damage_critical,
        {
            critical_chance = "chance",
            critical_mul = "damage_muliplier"
        }
    )
)
---@class Capability.velocity
---@field velocity Vector2D 
Capability.velocity = cap_fields(
    function(self) return self:get_comp("VelocityComponent",true) end ,
    {
        velocity = {
            get = function (self,comp)
                return Vector2D(comp:get_value2("mVelocity"))
            end,
            set =  function (self,comp,velocity)
                comp:set_value2("mVelocity",velocity:unpack())
            end
        }
    }
)

---@class Capability.Component 组件类
---@field id number 组件ID
---@field entity_id number 实体ID
Capability.Component = {
    getter = {
        id = function (self)
            return self.id
        end,
        entity_id = function (self)
            return self.entity_id
        end
    },
    setter = {
    }
}

-------------------------------------------------------------------------------------------
--[[
    内部私有类，不暴露构造函数
]]

---@class Component:Capability.Component 组件代表表类
---@field entity_id number 组件所在实体的ID
---@field id  number 组件ID
---@method remove() void 移除组件
---@method get_value(key_name:string) string  获取组件值
---@method get_value2(variable_name:string) any 获取组件值，但是更快(7.5x
---@method set_value(variable_name:string,value:string) void 设置组件值
---@method set_value2(variable_name:string,value:any) void 设置组件值
---@method get_object(object_name:string) Component 获取组件对象
---@method get_object_value(object_name:string,variable_name:string) string 获取结构体字段值
---@method get_object_value2(object_name:string,variable_name:string) ...  获取结构体字段值
---@method set_comp_enable(enabled)  设置组件启用
---@method add_tag(tag:string) 增加flag
local Component = class("Component",nil,Capability.Component)

---@class ComponentFactory
---@method new(entity_id:number,comp_id:number) Component
local ComponentFactory = {
}

-- 组件工厂
--[[

]]
--- 操作普通属性
---@param entity_id number 
---@param comp_id number 
---@return any 代理表proxy
function ComponentFactory:new(entity_id,comp_id)
    local comp = Component(entity_id,comp_id)
    local proxy = {}
    setmetatable(proxy,{
        __index = function (_,variable_name)
            if comp[variable_name] ~= nil  then
               return comp[variable_name] 
            else
                return comp:get_value2(variable_name)
            end           
        end,
        __newindex = function (_,variable_name,value)
            comp:set_value2(variable_name,value)
        end
    })
    return proxy
end

--- 代理object对象类型
---@param object_name string
---@return table 代理表proxy
function Component:get_object(object_name)
    local proxy = {}
    proxy.id = self.id
    proxy.__index = function (_,variable_name)
        return self:get_object_value2(object_name,variable_name)
    end
    proxy.__newindex = function (_,variable_name,...)
        return self:set_object_value2(object_name,variable_name,...)
    end
    return setmetatable(proxy,proxy)
end
---@param enabled boolean
function Component:set_comp_enable(enabled)
    EntitySetComponentIsEnabled(self.entity_id,self.id,enabled)
end

function Component:init(entity_id,comp_id)
    rawset(self,"entity_id",entity_id)
    rawset(self,"id",comp_id)
end

---移除组件，不处理组件不存在的问题
function Component:remove()
    EntityRemoveComponent(self.entity_id,self.id)
end
---@param variable_name string 
---@return string|nil 
function Component:get_value(variable_name)
    return ComponentGetValue(self.id,variable_name)
end
--- 更快(7.5x)
---@param variable_name string
---@return ...  一个或多个值 
function Component:get_value2(variable_name)
    return ComponentGetValue2(self.id,variable_name)
end
---@param variable_name string 
---@param value string  全部都是string 
function Component:set_value(variable_name,value)
    ComponentSetValue(self.id,variable_name,value)
end
--- 更快(20x)
---@param variable_name string 
---@param ... any  需要具体字段的类型具体分析
function Component:set_value2(variable_name,...)
    ComponentSetValue2(self.id,variable_name,...)
end
---@param object_name string 结构体字段名
---@param variable_name string 
---@return string|nil 
function Component:get_object_value(object_name,variable_name)
    return ComponentObjectGetValue(self.id,object_name,variable_name)
end
---@param object_name string 结构体字段名
---@param variable_name string 
---@return ...  一个或多个值 
function Component:get_object_value2(object_name,variable_name)
    return ComponentObjectGetValue2(self.id,object_name,variable_name)
end
---@param object_name string 结构体字段名
---@param variable_name string 
---@param value string
function Component:set_object_value(object_name,variable_name,value)
    ComponentObjectSetValue(self.id,object_name,variable_name,value)
end
---@param object_name string 结构体字段名
---@param variable_name string 
---@param ... any 
function Component:set_object_value2(object_name,variable_name,...)
    ComponentObjectSetValue2(self.id,object_name,variable_name,...)
end
---@param tag string 组件标签
function Component:add_tag(tag)
    ComponentAddTag(self.id,tag)
end


---------------------------------------------------------------------------------------------
--[[
    公开类，对外暴露
]]

-- 实体类
---@class yoiEntity.Entity : Capability.Entity
---@field id number|nil 实体ID，只读属性
---@field _class_name string 实体类名，只读属性
---@method kill() void 杀死实体
---@method is_living() boolean 实体是否存活
---@method has_tag(tag:string) boolean 实体是否有标签
---@method add_tag(tag:string) void 添加实体标签
---@method remove_tag(tag:string) void 移除实体标签
---@method add_child(child:yoiEntity.Entity|number) void 添加子实体
---@method remove_child(child:yoiEntity.Entity|number) void 移除子实体
---@method set_comp_enable(comp:Component,enabled:boolean) 设置组件启用？
---@method set_comps_enable(tag:string,enabled:boolean) 设置一类组件启用
---@method add_comp(type_name:string,table_of_comp_values:table,tags?:string,enabled?:boolean) number 添加组件
---@method add_variable_comp(table_of_comp_values:table,tags?:string,enabled?:boolean) number 添加变量存储组件
---@method add_lua_comp(table_of_comp_values:table,tags?:string,enabled?:boolean) number 添加Lua组件
---@method get_comp(type_name:string,including_disabled?:boolean,tag?:string) Component|nil 获取单个组件(返回组件代理表)
---@method get_comps(type_name:string,including_disabled?:boolean,tag?:string) Component[]|nil 获取所有组件(返回组件代理表数组)
---@method item_comp(including_disabled?:boolean,tag?:string) Component|nil 获取物品组件
---@method ability_comp(including_disabled?:boolean,tag?:string) Component|nil 获取能力组件
---@method item_action_comp(including_disabled?:boolean,tag?:string) Component|nil 获取物品动作组件
---@method damagemodel_comp(including_disabled?:boolean,tag?:string) Component|nil 获取伤害模型组件
---@method lifetime_comp(including_disabled?:boolean,tag?:string) Component|nil 获取生命周期组件
---@method controls_comp(including_disabled?:boolean,tag?:string) Component|nil 获取控制组件
---@method genome_data_comp(including_disabled?:boolean,tag?:string) Component|nil 获取基因组数据组件
---@method inventory2_comp(including_disabled?:boolean,tag?:string) Component|nil 获取背包组件
---@method sprite_comp(including_disabled?:boolean,tag?:string) Component|nil 获取精灵图组件
---@method hotspot_comp(including_disabled?:boolean,tag?:string) Component|nil 获取热点组件
---@method lua_comps(including_disabled?:boolean,tag?:string) Component[]|nil 获取所有Lua组件(返回组件代理表数组)
---@method variable_comps(including_disabled?:boolean,tag?:string) Component[]|nil 获取所有变量存储组件(返回组件代理表数组)
local Entity = class("Entity",nil,Capability.Entity)
---@param entity number|string 
---@param pos? Vector2D
function Entity:init(entity,pos)
    if entity == nil or entity == 0 then 
        _M.logger:error("Entity:init: eid is nil")
        return false
    end
    if type(entity) == "string" then
        pos = pos or Vector2D(0,0)
        local eid = EntityLoad(entity,pos:unpack())
        self:init(eid)
        return
    end
    rawset(self,"id",entity)
end

-- 动物类
---@class yoiEntity.Animals : yoiEntity.Entity, Capability.damage_model, Capability.herd_id,Capability.position
---@method is_living() boolean 重写：判断实体是否存活
---@method add_game_effect(effect_name:string,frames:number) Component|nil 添加游戏效果
---@method pick_up_perk(perk:yoiEntity.Perk|number,do_cosmetic_fx:boolean,kill_other_perks:boolean)
---@method ingest_material(material_name:string,frames:number) 吃材料
local Animals = class("Animals",Entity,
    Capability.damage_model,
    Capability.herd_id,
    Capability.position
)

-- 玩家类
---@class yoiEntity.Player:yoiEntity.Animals
---@method get_mouse_pos() number,number 获取鼠标世界坐标
---@method get_mouse_pos_in_screen(gui:userdata) number,number 获取鼠标屏幕坐标
---@method pick_up_item(item:yoiEntity.Entity|number) void 拾取物品
---@method get_wand_held() yoiEntity.Wand 获取手持法杖
---@method pick_up_perk(perk:yoiEntity.Perk|number,do_cosmetic_fx:boolean,kill_other_perks:boolean) 拾取天赋 
local Player = class("Player",Animals)

-- 物品类
---@class yoiEntity.Item:yoiEntity.Entity,Capability.item,Capability.position
---@method set_inventory_slot_x(x:number) void 设置物品X坐标
local Item = class("Item",Entity,
    Capability.item,
    Capability.position
)

-- 法术类
---@class yoiEntity.Action_Card:yoiEntity.Item,Capability.action
local Action_Card=class("Action_Card",Item,
    Capability.action
)
---@param str number|string 实体ID|法术ID|实体filename
---@param pos? Vector2D
function Action_Card:init(str,pos)
    if type(str) == "string" then
        if _actions_cache[str] ~= nil then
            --输入一个ID，则返回法术
            pos = pos or Vector2D(0,0)
            local eid = CreateItemActionEntity(str,pos:unpack())
            if eid == nil or eid == 0 then
                _M.logger:error("法术ID无效")
                return false
            end
            self:init(eid)
            return
        else
            _M.logger:error("无效的法术卡ID:" .. str)
            return false
        end
    elseif type(str) == "number" then
        Item.init(self,str,pos)
    else
        _M.logger:error("Action_Card:init: str is not string or number")
        return false
    end    
end

-- 法杖类
---@class yoiEntity.Wand : yoiEntity.Item, Capability.wand_ability,Capability.wand_sprite
---@method get_empty_slots() number[] 获取法杖空位置，升序排列
---@method add_action(action_id:string,dont_add_when_full:boolean) void 添加法术
---@method add_action_permanent(action_id:string) void 添加永久法术
---@method get_actions() yoiEntity.Action_Card[] 获取法术(按照位置排序好)
local Wand = class("Wand",Item,
    Capability.wand_ability,
    Capability.wand_sprite
)
--- 投射物类
--- @class yoiEntity.Projectile:yoiEntity.Entity,Capability.position,Capability.projectile,Capability.velocity
local Projectile = class("Projectile",Entity,
    Capability.position,
    Capability.projectile,
    Capability.velocity
)


--天赋类
---@class yoiEntity.Perk:yoiEntity.Entity,Capability.position,Capability.perk
local Perk = class("Perk",Entity,
    Capability.position,
    Capability.perk
)
---@param str string|number 天赋ID|实体ID
---@param pos? Vector2D
---@param dont_remove_other_perks? boolean
function Perk:init(str,pos,dont_remove_other_perks)
    if type(str) == "string" then
        if _perks_cache[str] ~= nil then
            --输入的是天赋ID
            pos = pos or Vector2D(0,0)
            local data = _perks_cache[str]
            local eid = EntityLoad( "data/entities/items/pickup/perk.xml", pos:unpack())
            if eid == nil then
                _M.logger:error("天赋ID无效")
                return false
            end
            self:init(eid)
            self:add_comp("SpriteComponent",{
                image_file = data.perk_icon or "data/items_gfx/perk.xml",  
                offset_x = 8, 
                offset_y = 8, 
                update_transform = true,
                update_transform_rotation = false,
            })
            self:add_comp("UIInfoComponent",{
                name = data.ui_name,
            })
            self:add_comp("ItemComponent",{
                item_name = data.ui_name,
                ui_description = data.ui_description,
                ui_display_description_on_pick_up_hint = true,
                play_spinning_animation = false,
                play_hover_animation = true,
                play_pick_sound = true,        
            })
            self:add_comp("SpriteOffsetAnimatorComponent",{
                sprite_id=-1 ,
                x_amount= 0 ,
                x_phase= 0 ,
                x_phase_offset=0 ,
                x_speed=0 ,
                y_amount=2 ,
                y_speed=3,    
            })
            self:add_comp("VariableStorageComponent",{
                name = "perk_id",
                value_string = data.id,
            })
            if dont_remove_other_perks then
                self:add_comp("VariableStorageComponent",{
                    name="perk_dont_remove_others",
                    value_bool=true,
                })
            end
            return 
        else
            _M.logger:error("无效的天赋ID:" .. str)
            return false
        end
    elseif type(str) == "number" then
        Entity.init(self,str,pos)
    else
        _M.logger:error("Perk:init: str is not string or number")
        return false
    end
end



function Entity:kill()
    if self:is_living() then
        EntityKill(self.id)
        rawset(self,"id",nil)
    end
end
-- 是否存活
function Entity:is_living()
    if self.id == nil then
        _M.logger:warn("实体不存在")
        return false
    end
    -- if EntityGetIsAlive(self.id) then
    --     return false
    -- end
    return true
end


function Entity:has_tag(tag)
    return EntityHasTag(self.id,tag)
end
function Entity:add_tag(tag)
    return EntityAddTag(self.id,tag)
end
function Entity:remove_tag(tag)
    return EntityRemoveTag(self.id,tag)
end

-- 子实体
function Entity:add_child(child)
    local child_id = get_id(child)    
    if child_id and child_id~=0 then
        EntityAddChild(self.id,child_id)
    end
end
function Entity:remove_child(child)
    local child_id = get_id(child)
    if child_id and child_id~=0 then
        EntityRemoveFromParent(child_id)
    end
end
---@param comp number|Component  组件ID
---@param enabled boolean
function Entity:set_comp_enable(comp,enabled)
    local comp_id 
    if type(comp) == "number" then
        comp_id = comp 
    elseif type(comp) == "table" then
        comp_id = comp.id
    end
    EntitySetComponentIsEnabled(self.id,comp_id,enabled)
end
---@param enabled boolean
---@param tag string
function Entity:set_comps_enable(tag,enabled)
    EntitySetComponentsWithTagEnabled(self.id,tag,enabled)
end


---给实体添加组件
---@param type_name string 组件类型名
---@param table_of_comp_values? table 组件的键值表
---@param tags? string  组件tags,以逗号分割
---@param enabled? boolean 是否启用
---@return number 组件ID
function Entity:add_comp(type_name,table_of_comp_values,tags,enabled)
    local t = {}
    for k,v in pairs(table_of_comp_values or {}) do
        t[k] = v
    end
    if tags ~= nil then t.tags = tags end
    if enabled ~= nil then t._enabled = enabled end
    return EntityAddComponent2(self.id,type_name,t)
end
---@param table_of_comp_values table 组件的键值表
---@param tags? string  组件tags,以逗号分割
---@param enabled? boolean 是否启用
---@return number 组件ID
function Entity:add_variable_comp(table_of_comp_values,tags,enabled)
    return self:add_comp("VariableStorageComponent",table_of_comp_values,tags,enabled)
end
---@param table_of_comp_values table 组件的键值表
---@param tags? string  组件tags,以逗号分割
---@param enabled? boolean 是否启用
---@return number 组件ID
function Entity:add_lua_comp(table_of_comp_values,tags,enabled)
    return self:add_comp("LuaComponent",table_of_comp_values,tags,enabled)
end


--- 获取组件
---@param type_name string
---@param including_disabled boolean|nil
---@param tag? string 组件tag
---@return any|nil   返回任何组件代理表或nil
function Entity:get_comp(type_name,including_disabled,tag)
    if not self:is_living() then return nil end
    local comp 
    if including_disabled == true then
        if tag then 
            comp = EntityGetFirstComponentIncludingDisabled(self.id,type_name,tag)
        else
            comp = EntityGetFirstComponentIncludingDisabled(self.id,type_name)
        end                
    else
        if tag then 
            comp = EntityGetFirstComponent(self.id,type_name,tag)
        else 
            comp = EntityGetFirstComponent(self.id,type_name)
        end
    end
    if not comp then 
        _M.logger:warn("未查找到组件" .. type_name)
        return nil
    end
    -- 提供一个可以读写的代理表
    return ComponentFactory:new(self.id,comp)
end


---@return  ItemComponent
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:item_comp(including_disabled,tag)
    return self:get_comp("ItemComponent",including_disabled,tag)
end
---@return AbilityComponent
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:ability_comp(including_disabled,tag)
    return self:get_comp("AbilityComponent",including_disabled,tag)
end
---@return ItemActionComponent
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:item_action_comp(including_disabled,tag)
    return self:get_comp("ItemActionComponent",including_disabled,tag)
end
---@return DamageModelComponent
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:damagemodel_comp(including_disabled,tag)
    return self:get_comp("DamageModelComponent",including_disabled,tag)
end
---@return LifetimeComponent
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:lifetime_comp(including_disabled,tag)
    return self:get_comp("LifetimeComponent",including_disabled,tag)
end
---@return ControlsComponent
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:controls_comp(including_disabled,tag)
    return self:get_comp("ControlsComponent",including_disabled,tag)
end
---@return GenomeDataComponent
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:genome_data_comp(including_disabled,tag)
    return self:get_comp("GenomeDataComponent",including_disabled,tag)
end
---@return Inventory2Component
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:inventory2_comp(including_disabled,tag)
    return self:get_comp("Inventory2Component",including_disabled,tag)
end
---@return SpriteComponent
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:sprite_comp(including_disabled,tag)
    return self:get_comp("SpriteComponent",including_disabled,tag)
end
---@return HotspotComponent
---@param including_disabled? boolean
---@param tag? string 组件tag
function Entity:hotspot_comp(including_disabled,tag)
    return self:get_comp("HotspotComponent",including_disabled,tag)
end


--- 获取组件s
---@param type_name string
---@param including_disabled boolean|nil
---@param tag? string 组件tag
---@return any|nil
function Entity:get_comps(type_name,including_disabled,tag)
    if not self:is_living() then return nil end
    local comps 
    if including_disabled == true then
        if tag then 
            comps = EntityGetComponentIncludingDisabled(self.id,type_name,tag)
        else
            comps = EntityGetComponentIncludingDisabled(self.id,type_name)
        end
    else   
        if tag then 
            comps = EntityGetComponent(self.id,type_name,tag)
        else 
            comps = EntityGetComponent(self.id,type_name)
        end
    end
    if not comps then 
        _M.logger:warn("未查找到组件" .. type_name)
        return nil 
    end
    local proxies = {}
    for _,comp_id in ipairs(comps) do 
        table.insert(proxies,ComponentFactory:new(self.id,comp_id))
    end
    return proxies
end
---@param including_disabled? boolean
---@param tag? string 组件tag
---@return LuaComponent[] with proxy
function Entity:lua_comps(including_disabled,tag)
    return self:get_comps("LuaComponent",including_disabled,tag)
end
---@param including_disabled? boolean
---@param tag? string 组件tag
---@return VariableStorageComponent[] with proxy
function Entity:variable_comps(including_disabled,tag)
    return self:get_comps("VariableStorageComponent",including_disabled,tag)
end



function Animals:is_living()
    if self.id == nil then
        _M.logger:warn("实体不存在")
        return false
    elseif not EntityGetIsAlive(self.id) then
        _M.logger:warn("实体未存活")
        return false
    end
    return true
end
--- 设置效果
---@param effect_name string 效果名
---@param frames? number 持续帧数
---@param always_load_new? boolean 默认为true
---@return GameEffectComponent,yoiEntity.Entity
function Animals:add_game_effect(effect_name,frames,always_load_new)
    local comp_id,eid = GetGameEffectLoadTo(self.id,effect_name,always_load_new or true)
    local comp = ComponentFactory:new(self.id,comp_id) 
    if comp ~= nil then
        comp.frames = frames or -1
    else
        _M.logger:warn("获取" .. effect_name .. "失败")
    end
    return comp,M.Entity(eid)
end
---@param perk yoiEntity.Perk|string
function Animals:pick_up_perk(perk)
    local pos = self.pos
    if type(perk) == "string" then
        perk = Perk(perk)
    end
    --赋予效果
    if perk.game_effect ~= nil then
        self:add_game_effect(perk.game_effect,-1)
    end

    --效果
    if perk.func_enemy ~= nil then
        perk.func_enemy(perk.id,self.id)
    elseif perk.func ~= nil then
        perk.func(perk.id,self.id)
    end

    --添加UI
    local entity = M.Entity( "data/entities/misc/perks/enemy_icon.xml",pos)
    local comp = entity:sprite_comp(true)
    comp.image_file = perk.ui_icon
    self:add_child(entity)
    
    perk:kill()
end

---@param material string|number 若为材料的name,则会自动通过CellFactory_GetType(name)转id
---@param count number 吃掉的单位数
function Animals:ingest_material(material,count)
    local mat_id 
    if type(material) == "string" then
        mat_id = CellFactory_GetType(material)
    else
        mat_id = material
    end
    EntityIngestMaterial(self.id,mat_id,count)
end



---获取鼠标位置
function Player:get_mouse_pos()
    return DEBUG_GetMouseWorld()
end
function Player:get_mouse_pos_in_screen(gui)
    local mx,my = self:get_mouse_pos()
    local _, _, cw, ch = GameGetCameraBounds()
    local cx, cy = GameGetCameraPos()
    cw = cw - 4
    local cx = cx-cw/2
    local cy = cy-ch/2
    local  gw, gh = GuiGetScreenDimensions(gui)
    return (mx-cx)*gw/cw+1.0, (my-cy)*gh/ch -3
end

function Player:pick_up_item(item)
    local item_id = get_id(item)
    if item_id then
        GamePickUpInventoryItem(self.id,item_id)
    end
end
---@return yoiEntity.Wand|nil 手持法杖对象
function Player:get_wand_held()
    local children = EntityGetAllChildren(self.id)
	if ( children == nil ) then return nil end
	-- Inventory2Component
	-- mActiveItem
	local inventory2_comp = self:inventory2_comp(true)
	if ( inventory2_comp ~= nil ) then
		local active_item =inventory2_comp.mActiveItem 
		if ( EntityHasTag( active_item, "wand" ) ) then
			return Wand(active_item)
		end
	end
	return nil
end
---@param perk yoiEntity.Perk|string
---@param do_cosmetic_fx? boolean
---@param kill_other_perks? boolean 是否清除范围其他天赋
function Player:pick_up_perk(perk,do_cosmetic_fx,kill_other_perks)
    local pos  = {}
    if type(perk) == "string" then
        perk = M.Perk(perk)
        pos = self.pos
    else
        pos = perk.pos
    end
    local data = _perks_cache[perk.perk_id]
    if data == nil then
        _M.logger:warn("无法获取对应data")
        return 
    end
    
    --全局数据
    perk.count = perk.count + 1 
    local add_progress_flags = not GameHasFlagRun( "no_progress_flags_perk" )
    local flag = string.format('PERK_PICKED_%s_PICKUP_COUNT',perk.perk_id)
    if add_progress_flags then
		local flag_name_persistent = string.lower( flag )
		if ( not HasFlagPersistent( flag_name_persistent ) ) then
			GameAddFlagRun( "new_" .. flag_name_persistent )
		end
		AddFlagPersistent( flag_name_persistent )
	end
	GameAddFlagRun( flag)

    --标记是否可移除
    local no_remove = perk.do_not_remove or false

    --执行天赋效果
    if perk.game_effect ~= nil then
        local comp,entity = self:add_game_effect(perk.game_effect,-1,true)
        if no_remove == false then
            comp:add_tag("perk_component")
            entity:add_tag("perk_entity")
        end
    end
    if perk.game_effect2 ~= nil then
        local comp,entity = self:add_game_effect(perk.game_effect2,-1,true)
        if no_remove == false then
            comp:add_tag("perk_component")
            entity:add_tag("perk_entity")
        end
    end

    --首次添加时的例子效果
    if perk.particle_effect ~= nil and  perk.count <=1 then
        local entity = M.Entity("data/entities/particles/perks/" .. perk.particle_effect .. ".xml")
        if no_remove == false then
            entity:add_tag("perk_entity")
        end
        self:add_child(entity)
    end
    --标记同类天赋
    for i,v in ipairs( perk.remove_other_perks or {} ) do
        local f =string.format('PERK_PICKED_%s_PICKUP_COUNT',v)
        GameAddFlagRun( f )
        -- NOTE( Petri ): 8.8.2023 - Thank you to Noita community for this fix. 
        -- this should remove the related perks from the perk pool. 4realz.
        local remove_perk_pickup_count = tonumber( GlobalsGetValue( f .. "_PICKUP_COUNT", "0" ) )
        remove_perk_pickup_count = remove_perk_pickup_count + 1
        GlobalsSetValue( f .. "_PICKUP_COUNT", tostring( remove_perk_pickup_count ) )
	end
    --func
    if perk.func ~=nil then
        perk.func(perk.id,self.id,perk.perk_id,perk.count)
    end
    ---UI图标
    local entity_ui = M:EntityCreateNew("")
    if entity_ui == nil then
        _M.logger:warn("无法生成entity_ui")
        return 
    end
    entity_ui:add_comp("UIIconComponent",{
        name = perk.name,
        description = perk.ui_description,
        icon_sprite_file = perk.ui_icon,
    })
 
    

    if no_remove == false then
        entity_ui:add_tag("perk_entity")
    end
    self:add_child(entity_ui)

    

    --杀戮和非杀戮？
    if do_cosmetic_fx then
		local enemies_killed = tonumber( StatsBiomeGetValue("enemies_killed") )
		
		if( enemies_killed ~= 0 ) then
			EntityLoad( "data/entities/particles/image_emitters/perk_effect.xml", pos.x, pos.y )
		else
			EntityLoad( "data/entities/particles/image_emitters/perk_effect_pacifist.xml", pos.x, pos.y )
		end
		
		GamePrintImportant( GameTextGet( "$log_pickedup_perk", GameTextGetTranslatedOrNot(perk.ui_name) ),perk.ui_description )
	end

    --获取roll机和其他天赋
    pos = self.pos
    local rerolls = EntityGetInRadiusWithTag( pos.x, pos.y, 200, "perk_reroll_machine" )--roll机
	local other_perks = EntityGetInRadiusWithTag( pos.x, pos.y, 200, "item_perk" )--天赋实体

    local disable_reroll = false

    if (#other_perks <= 1) then
        disable_reroll = true
    end

    if kill_other_perks then
		local perk_destroy_chance = tonumber( GlobalsGetValue( "TEMPLE_PERK_DESTROY_CHANCE", "100" ) )
		SetRandomSeed( pos.x, pos.y )

		if( Random( 1, 100 ) <= perk_destroy_chance ) then
			-- removes all the perks
			local all_perks = EntityGetWithTag( "perk" )
			disable_reroll = true
		
			if ( #all_perks > 0 ) then
				for i,entity_perk in ipairs(all_perks) do
					if entity_perk ~= perk.id then
						EntityKill( entity_perk )
					end
				end
			end
		end
	end

    --roll机
    if disable_reroll == true then
        for _,roll in ipairs(rerolls) do
            local eid = M.Entity(roll) 
            ---@type ItemCostComponent
            local comp = eid:get_comp("ItemCostComponent")
            if  comp then
                comp:set_comp_enable(false)
            end            
            local comps = eid:get_comp("SpriteComponent",false,"shop_cost")
            for _,comp2 in ipairs(comps or {}) do
                comp2:set_comp_enable(false)
            end
            eid:set_comps_enable( "perk_reroll_disable",false)
        end
    end
    perk:kill()
end
---@param x number
function Item:set_inventory_slot_x(x)
    local comp = self:item_comp(true)
    if not comp then
        _M.logger:warn("无法获取item_comp")
        return 
    end
    comp:set_value2("inventory_slot",x)
end

-- 获取法术id
---@return string|nil  法术id  
function Action_Card:get_action_id()
    local comp = self:item_action_comp(true)
    if comp then
        local action_id = comp.action_id
        return action_id
    end
    return nil 
end

---降序表，最小的格子在最后
---@return number[] 
function Wand:get_empty_slots()
    local empty_slots = {}
    local cards,cards_permanent = self:get_actions()
    local cards_slots = {}
    for _,card in ipairs(cards) do 
        cards_slots[card.inventory_slot.x] = true
    end 
    local count = 0 
    for i = (self.deck_capacity - #cards_permanent - 1),0,-1 do
        if cards_slots[i] ~= true then
            count = count +1 
            empty_slots[count] = i 
        end
    end
    return empty_slots
end
---@param action_id string 法术的大写ID
---@param dont_add_when_full? boolean 是否在满时不添加
---@param slot_x? number 法术的位置，默认添加于空位
---@return yoiEntity.Action_Card|nil
function Wand:add_action(action_id,dont_add_when_full,slot_x)
    if( action_id == "" ) then return nil end
    if (dont_add_when_full) then
        local n = #(EntityGetAllChildren(self.id,"card_action") or {})
        if n== self.deck_capacity then
            return nil
        end
    end
    local action_entity = M.Action_Card(action_id)
    if action_entity == nil then
        _M.logger:error("提供的actions存在错误")
        return nil 
    end
    local empty_slots = self:get_empty_slots()
    self:add_child(action_entity)
    if slot_x~=nil  then    
        action_entity:set_inventory_slot_x(slot_x)
    elseif #empty_slots > 0 then 
        action_entity:set_inventory_slot_x( empty_slots[#empty_slots])
    end

	if action_entity.id ~= 0 then
        action_entity:set_comps_enable("enabled_in_world",false)
	end
    return action_entity
end
---@param actions string[] 法术
---@param dont_add_when_full? boolean
function Wand:add_actions(actions,dont_add_when_full)
    local n = #(EntityGetAllChildren(self.id,"card_action") or {})
    local empty_slots = self:get_empty_slots()
    for i,action_id in ipairs(actions) do 
        if (dont_add_when_full) then        
            if n+i > self.deck_capacity then
                return  
            end
        end
        local action_entity =M.Action_Card(action_id)
        if action_entity == nil then
            _M.logger:error("提供的actions存在错误")
            break 
        end
        self:add_child(action_entity)
        local empty_slots_n = #empty_slots
        if empty_slots_n > 0 then
            action_entity:set_inventory_slot_x( empty_slots[empty_slots_n] )
            empty_slots[empty_slots_n] = nil 
        end
        if action_entity.id ~= 0 then
            action_entity:set_comps_enable("enabled_in_world",false)
	    end
    end
end
---@param action_id string
---@param slot_x? number 法杖位置
function Wand:add_action_permanent(action_id,slot_x)
    if( action_id == "" ) then return 0 end
	local action_entity = M.Action_Card(action_id)
    if action_entity == nil then
        _M.logger:error("无法获取" .. action_id .. " 法术")
        return 
    end
    self:add_child(action_entity)
    if self.deck_capacity then
        self.deck_capacity = self.deck_capacity +1
    end     
	local item_component = action_entity:item_comp(true) 
	if( item_component ~= nil ) then
        item_component.permanently_attached = true
	end
    if slot_x then
        action_entity:set_inventory_slot_x(slot_x)
    end
	if action_entity ~= nil then
        action_entity:set_comps_enable("enabled_in_world",false)
	end
end
---@return yoiEntity.Action_Card[] 普通法术,yoiEntity.Action_Card[] 永久法术
function Wand:get_actions()
    local actions = EntityGetAllChildren(self.id)
    local cards = {}
    local cards_permanent = {}
    for i,v in ipairs(actions or {}) do
        local card = M.Action_Card(v)
        if card.permanently_attached == true then
            table.insert(cards_permanent,card)
        else
            table.insert(cards,card)
        end
    end
    --将actions排序
    table.sort(cards,function(a,b)
        local a_x = a.inventory_slot and a.inventory_slot.x or -1
        local b_x = b.inventory_slot and b.inventory_slot.x or -1
        return a_x < b_x
    end)
    table.sort(cards_permanent,function(a,b)
        local a_x = a.inventory_slot and a.inventory_slot.x or -1
        local b_x = b.inventory_slot and b.inventory_slot.x or -1
        return a_x < b_x
    end)
    return cards,cards_permanent
end

-------------------------------------------------------------------------------------------

-- 暴露的函数
M.Vector2D = Vector2D
M.DamageType = DamageType
M.Entity = Entity 
M.Item = Item
M.Animals = Animals
M.Player = Player
M.Wand = Wand
M.Perk = Perk
M.Action_Card = Action_Card
---@param newlogger table
function M:set_logger(newlogger)
    _M.logger = newlogger
end
---@param name string ??
---@return yoiEntity.Entity|nil
function M:EntityCreateNew(name)
    local eid = EntityCreateNew(name)
    return M.Entity(eid)
end
return M

