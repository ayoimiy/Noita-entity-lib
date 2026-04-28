
local Logger = {
}
function Logger:write(msg)
    -- GamePrint(msg)
end
function Logger:error(msg)
    self:write("[Error]" .. msg)
end
function Logger:info(msg)
    self:write("[Info]" .. msg)
end
function Logger:debug(msg)
    self:write("[Debug]" .. msg)
end
function Logger:warn(msg)
    self:write("[Warn]" .. msg)
end

local logger = {}
function logger.setLogger(_Logger)
    setmetatable(logger,{
        __index = _Logger
    })
end
logger.setLogger(Logger)

---@class Component
---@method remove() void 移除组件
---@method get_id() number 获取组件ID
---@method get_value(key_name:string) any 获取组件值
---@method get_object(object_name:string) Component 获取组件对象
local Component = {
}

local function get_id(entity)
    if type(entity) == 'number' then
        return entity
    elseif type(entity) == 'table' then
        return entity:get_id()
    end
end



-- 实体类
---@class Entity
---@field id number|nil 实体ID
---@method get_id() number 获取实体ID
---@method get_name() string 获取实体名称
---@method get_file_name() string 获取实体文件名称
---@method kill() void 杀死实体
---@method is_living() boolean 实体是否存活
---@method get_pos() number,number 获取实体坐标
---@method set_pos(x:number,y:number) void 设置实体坐标
---@method has_tag(tag:string) boolean 实体是否有标签
---@method add_tag(tag:string) void 添加实体标签
---@method remove_tag(tag:string) void 移除实体标签
---@method add_child(child:Entity|number) void 添加子实体
---@method remove_child(child:Entity|number) void 移除子实体
---@method add_comp(type_name:string,table_of_comp_values:table,tags:string,enabled:boolean) number 添加组件
---@method add_variable_comp(table_of_comp_values:table,tags:string,enabled:boolean) number 添加变量存储组件
---@method add_lua_comp(table_of_comp_values:table,tags:string,enabled:boolean) number 添加Lua组件
---@method get_comp(type_name:string,including_disabled:boolean) Component|nil 获取单个组件
---@method get_comps(type_name:string,including_disabled:boolean) Component[]|nil 获取所有组件
---@method get_comp_object(type_name:string,object_name:string) Component|nil 获取组件对象
---@method item_comp(including_disabled:boolean) Component|nil 获取物品组件
---@method ability_comp(including_disabled:boolean) Component|nil 获取能力组件
---@method item_ation_comp(including_disabled:boolean) Component|nil 获取物品动作组件
---@method damagemodel_comp(including_disabled:boolean) Component|nil 获取伤害模型组件
---@method lifetime_comp(including_disabled:boolean) Component|nil 获取生命周期组件
---@method controls_comp(including_disabled:boolean) Component|nil 获取控制组件
---@method genome_data_comp(including_disabled:boolean) Component|nil 获取基因组数据组件
---@method inventory2_comp(including_disabled:boolean) Component|nil 获取背包组件
local Entity = {
    id = nil 
}

-- 动物类
---@class Animals:Entity
---@method is_living() boolean 重写：判断实体是否存活
---@method get_hp() number|nil 获取当前生命值
---@method set_hp(hp:number) void 设置当前生命值
---@method get_max_hp() number|nil 获取最大生命值
---@method set_max_hp(max_hp:number) void 设置最大生命值
---@method get_damage_muls() table|nil 获取承伤倍率表
---@method set_damage_muls(damage_muls:table) void 设置承伤倍率
---@method get_herd_id() number|nil 获取阵营ID
---@method set_herd_id(herd_id:number) void 设置阵营ID
---@method add_game_effect(effect_name:string,frames:number) Component|nil 添加游戏效果
local Animals = {}



-- 玩家类
---@class Player:Animals
---@method get_mouse_pos() number,number 获取鼠标世界坐标
---@method get_mouse_pos_in_screen(gui:userdata) number,number 获取鼠标屏幕坐标
---@method pick_up_item(item:Entity|number) void 拾取物品
---@method get_wand_held() Wand 获取手持法杖
local Player = {}

-- 物品类
---@class Item:Entity
---@method get_ui_info() table 获取物品UI信息
---@method set_ui_info(info:table) void 设置物品UI信息
local Item = {}

-- 法术类
---@class Action_Card:Item
---@method get_action_id() number|nil 获取法术ID
local Action_Card={}

-- 法杖类
---@class Wand:Item
---@method add_action(action_id:string,dont_add_when_full:boolean) void 添加法术
---@method add_action_permanent(action_id:string) void 添加永久法术
local Wand = {}
--天赋类
---@class Perk:Entity
local Perk = {}




-- 打包
local M = {
    Entity = Entity,
    Item = Item,
    Animals = Animals,
    Player = Player,
    Wand = Wand,
    Perk = Perk,
    Action_Card = Action_Card,
    Logger = Logger,
}

--- 操作普通属性
---@param entity_id number 
---@param comp_id number 组件ID
---@return table 代理表proxy
function Component:new(entity_id,comp_id)
    local obj = {
    }
    setmetatable(obj,{
          __index = function (_,key)
            if key == "remove" then
                return function ()
                    EntityRemoveComponent(entity_id,comp_id)
                end
            elseif key == "get_id" then
                return function ()
                    return comp_id
                end
            elseif key == "get_value" then
                return function (key_name)
                    return ComponentGetValue2(comp_id,key_name)
                end
            elseif key == "get_object" then
                return function (object_name)
                    local M = {}
                    setmetatable(M,{
                        __index =function(_,key_name)
                            ComponentObjectGetValue2(comp_id,object_name,key_name)
                        end,
                        __newindex = function (_,key_name,value)
                            ComponentObjectSetValue2(comp_id,object_name,key_name,value)
                        end
                    })
                    return M
                end
            else
                local value = ComponentGetValue2(comp_id,key)
                -- GamePrint("第一次获取" .. value)
                -- if not value then
                --     value = ComponentGetValue(comp_id,key)
                --     -- GamePrint("第二次获取" .. value)
                -- end
                return value
            end            
        end,
        __newindex = function(_,key,value)
            return ComponentSetValue2(comp_id,key,value)
        end   
    })
    return obj
end
--- 操作object对象
---@param entity_id number
---@param comp_id number
---@param object_name string
function Component:new_object(entity_id,comp_id,object_name)
    local comp  = Component:new(entity_id,comp_id)
    if not comp then return nil end 
    return comp.get_object(object_name)
end

Entity.__index = Entity
---@param eid number
function Entity:new(eid)
    local obj = {}
    obj.id = eid 
    setmetatable(obj,Entity)
    return obj
end
-- 获取id 
--- @return number 
function Entity:get_id()
    return self.id
end
-- 获取名字
function Entity:get_name()
    local name = EntityGetName(self.id)
    if name == nil then
        logger:warn(tostring(self.id) .. "不存在名字")
        name = ""
    end
    return GameTextGetTranslatedOrNot(name )
end
function Entity:get_file_name()
    return EntityGetFilename(self.id)
end

function Entity:kill()
    if self:is_living() then
        EntityKill(self.id)
        self.id = nil 
    end
end

-- 是否存活
function Entity:is_living()
    if self.id == nil then
        logger:warn("实体不存在")
        return false
    end
    -- if EntityGetIsAlive(self.id) then
    --     return false
    -- end
    return true
end
-- 坐标
function Entity:get_pos()
    local x,y = EntityGetTransform(self.id)
    return x,y
end
function Entity:set_pos(x,y)
    EntitySetTransform(self.id,x,y)
end

function Entity:has_tag(tag)
    return EntityHasTag(self.id,tag)
end
function Entity:add_tag(tag)
    return EntityAddTag(self.id,tag)
end
function  Entity:remove_tag(tag)
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

---给实体添加组件
---@param type_name string 组件类型名
---@param table_of_comp_values table 组件的键值表
---@param tags string  组件tags,以逗号分割
---@param enabled boolean 是否启用
---@return number 组件ID
function Entity:add_comp(type_name,table_of_comp_values,tags,enabled)
    local t = table_of_comp_values
    if tags ~= nil then t.tags = tags end
    if enabled ~= nil then t._enabled = enabled end
    return EntityAddComponent2(self.id,type_name,t)
end
function Entity:add_variable_comp(table_of_comp_values,tags,enabled)
    return self:add_comp("VariableStorageComponent",table_of_comp_values,tags,enabled)
end
function Entity:add_lua_comp(table_of_comp_values,tags,enabled)
    return self:add_comp("LuaComponent",table_of_comp_values,tags,enabled)
end


--- 获取组件
---@param type_name string
---@param including_disabled boolean
---@return table|nil
function Entity:get_comp(type_name,including_disabled)
    if not self:is_living() then return nil end
    local comp 
    if including_disabled == true then
        comp = EntityGetFirstComponentIncludingDisabled(self.id,type_name)
    else
        comp = EntityGetFirstComponent(self.id,type_name)
    end
    if not comp then 
        logger:warn("未查找到组件" .. type_name)
        return nil
    end
    -- 提供一个可以读写的代理表
    return Component:new(self.id,comp)
end

--- 获取组件s
---@param type_name string
---@param including_disabled boolean
---@return table|nil
function Entity:get_comps(type_name,including_disabled)
    if not self:is_living() then return nil end
    local comps 
    if including_disabled == true then
        comps = EntityGetComponentIncludingDisabled(self.id,type_name)
    else    
        comps = EntityGetComponent(self.id,type_name)
    end
    if not comps then 
        logger:warn("未查找到组件" .. type_name)
        return nil 
    end
    local proxies = {}
    for _,comp_id in ipairs(comps) do 
        table.insert(proxies,Component:new(self.id,comp_id))
    end
    return proxies
end

-- 获取object
--- func desc
---@param type_name string
---@param object_name string
---@return table|nil
function Entity:get_comp_object(type_name,object_name)
    if not EntityGetIsAlive(self.id) then return nil end
    local comp = EntityGetFirstComponentIncludingDisabled(self.id,type_name)
    if not comp then return nil end
    return Component:new_object(self.id,comp,object_name)
end
function Entity:item_comp(including_disabled)
    return self:get_comp("ItemComponent",including_disabled)
end
function Entity:ability_comp(including_disabled)
    return self:get_comp("AbilityComponent",including_disabled)
end
function Entity:item_ation_comp(including_disabled)
    return self:get_comp("ItemActionComponent",including_disabled)
end
function Entity:damagemodel_comp(including_disabled)
    return self:get_comp("DamageModelComponent",including_disabled)
end
function Entity:lifetime_comp(including_disabled)
    return self:get_comp("LifetimeComponent",including_disabled)
end
function Entity:controls_comp(including_disabled)
    return self:get_comp("ControlsComponent",including_disabled)
end
function Entity:genome_data_comp(including_disabled)
    return self:get_comp("GenomeDataComponent",including_disabled)
end
function Entity:inventory2_comp(including_disabled)
    return self:get_comp("Inventory2Component",including_disabled)
end


Animals.__index = Animals
setmetatable(Animals,Entity)
---@param eid number 生物名字
---@return table 
function Animals:new(eid)
    local obj = Entity:new(eid)
    setmetatable(obj,self)
    return obj
end
function Animals:is_living()
    if self.id == nil then
        logger:warn("实体不存在")
        return false
    elseif not EntityGetIsAlive(self.id) then
        logger:warn("实体未存活")
        return false
    end
    return true
end
--获取血量
function Animals:get_hp()
    local damagemodel = self:damagemodel_comp()
    if not damagemodel then return nil end
    return damagemodel.hp
end
---@param hp number 
function Animals:set_hp(hp)
    local damagemodel = self:damagemodel_comp()
    if not damagemodel then return nil end
    damagemodel.hp = hp 
end
function Animals:get_max_hp()
    local damagemodel = self:damagemodel_comp()
    if not damagemodel then return nil end
    return damagemodel.max_hp
end
function Animals:set_max_hp(max_hp)
    local damagemodel = self:damagemodel_comp()
    if not damagemodel then return nil end
    damagemodel.max_hp = max_hp
end

-- 承伤倍率
function Animals:get_damage_muls()
    local comp = EntityGetFirstComponentIncludingDisabled(self.id,"DamageModelComponent")
    if not comp then return nil end 
    return ComponentObjectGetMembers(comp,"damage_multipliers")
end
function Animals:set_damage_muls(damage_muls)
    local damage_multipliers = self:get_comp_object("DamageModelComponent","damage_multipliers")
    if not damage_multipliers  then return nil end 
    for type,mul in pairs(damage_muls) do
        damage_multipliers[type] =mul
    end
end
-- 获取敌人阵营
function Animals:get_herd_id()
    local comp = self:genome_data_comp(true)
    if not comp then return nil end
    return comp.herd_id
end
function Animals:set_herd_id(herd_id)
    local comp = self:genome_data_comp(true)
    if not comp then return nil end
    comp.herd_id = herd_id
end
--- 设置效果
---@param effect_name string
function Animals:add_game_effect(effect_name,frames)
    local comp_id = GetGameEffectLoadTo(self.id,effect_name,true)
    local comp = Component:new(self.id,comp_id) 
    if comp ~= nil then
        comp.frames = frames or -1
    else
        logger:warn("获取" .. effect_name .. "失败")
    end
    return comp
end


Player.__index = Player
setmetatable(Player,Animals)
function Player:new(eid)
    local obj = Animals:new(eid)
    setmetatable(obj,self)
    return obj
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

function Player:get_wand_held()
    local children = EntityGetAllChildren(self.id)
	if ( children == nil ) then return 0 end

	local backup_result = 0

	-- Inventory2Component
	-- mActiveItem
	local inventory2_comp = self:inventory2_comp(true)
	if ( inventory2_comp ~= nil ) then
		local active_item =inventory2_comp.mActiveItem 
		if ( EntityHasTag( active_item, "wand" ) ) then
			return Wand:new(active_item)
		end
	end

	-- -- if that doesn't work (e.g. player is holding something else than a wand)
	-- -- 如果上面的方法不工作（例如玩家正拿着法杖以外的物品）
	-- for _,child in ipairs( children ) do
	-- 	if( EntityHasTag( child, "wand" ) ) then
	-- 		if ( EntityGetFirstComponent( child, "ItemComponent") ~= nil ) then
	-- 			return child
	-- 		end
	-- 		if ( ComponentGetIsEnabled( EntityGetFirstComponentIncludingDisabled( child, "ItemComponent") ) ) then
	-- 			backup_result = child
	-- 		end
	-- 	else
	-- 		local temp_result = find_the_wand_held( child )
	-- 		if ( temp_result ~= 0 ) then
	-- 			if ( EntityGetFirstComponent( temp_result, "ItemComponent") ~= nil ) then
	-- 				return temp_result
	-- 			else
	-- 				backup_result = temp_result
	-- 			end
	-- 		end
	-- 	end
	-- end

	return backup_result
end

Item.__index = Item
setmetatable(Item,Entity)
function Item:new(eid)
    local obj = Entity:new(eid)
    setmetatable(obj,self)
    return obj
end
-- 获取ui
function Item:get_ui_info()
    local info = {}
    local ItemComp = self:item_comp(true)
    if ItemComp then
        -- 在物品栏的ui
        info.ui_description = ItemComp.ui_description
        -- 在物品栏的ui
        info.ui_sprite  = ItemComp.ui_sprite
    end
    local Ability_comp = self:ability_comp(true)
    if Ability_comp then
        info.ui_name =Ability_comp.ui_name
    end
    return info
end
-- 修改ui 
function Item:set_ui_info(info)
    -- GamePrint(tostring(self.id))
    if info.ui_description or info.ui_sprite then
        local ItemComp = self:item_comp(true)
        if ItemComp then
            if info.ui_description then
                ItemComp.ui_description = info.ui_description
            end
            if info.ui_sprite then
                ItemComp.ui_sprite = info.ui_sprite
            end
        end
    --  GamePrint("ItemComp:"..ItemComp)
    end
    if info.ui_name then
        local Ability_comp = self:ability_comp(true)
        if Ability_comp then
            Ability_comp.ui_name = info.ui_name
        end
    end
end

Action_Card.__index = Action_Card
setmetatable(Action_Card,Item)
function Action_Card:new(eid)
    local obj = Item:new(eid)
    setmetatable(obj,self)
    return obj
end
-- 获取法术id
function Action_Card:get_action_id()
    local comp = self:item_ation_comp()
    if comp then
        local action_id = comp.action_id
        return action_id
    end
    return nil 
end

Wand.__index = Wand
setmetatable(Wand,Item)
function Wand:new(eid)
    local obj = Item:new(eid)
    setmetatable(obj,self)
    return obj
end

function Wand:add_action(action_id,dont_add_when_full)
    if( action_id == "" ) then return 0 end
    if (dont_add_when_full) then
        local ability_comp = self:ability_comp(true) 
        if( ability_comp ~= nil ) then
            local deck_capacity = Component:new_object(self.id,ability_comp:get_id(),"gun_config")
            local n = #(EntityGetAllChildren(self.id,"card_action") or {})
            if n+1> deck_capacity.deck_capacity then
                return 
            end
        end
    end
	local action_entity = Action_Card:new(CreateItemActionEntity( action_id ))
    self:add_child(action_entity)
	if action_entity ~= 0 then
		EntitySetComponentsWithTagEnabled( action_entity:get_id(), "enabled_in_world", false )
	end
end
function Wand:add_action_permanent(action_id)
    if( action_id == "" ) then return 0 end
	local action_entity = Action_Card:new(CreateItemActionEntity( action_id ))
    self:add_child(action_entity)
	-- we need to add a slot to the ability_comp
    
	local ability_comp = self:ability_comp(true) 
	if( ability_comp ~= nil ) then
        local deck_capacity = Component:new_object(self.id,ability_comp:get_id(),"gun_config")
        deck_capacity.deck_capacity = deck_capacity.deck_capacity +1
	end

	local item_component = action_entity:item_comp(false) 
	if( item_component ~= nil ) then
        item_component.permanently_attached = true
	end

	if action_entity ~= nil then
		EntitySetComponentsWithTagEnabled( action_entity:get_id(), "enabled_in_world", false )
	end
end

-- 天赋
Perk.__index = Entity
function Perk:new(eid)
    local obj  = Entity:new(eid)
    setmetatable(obj,Perk)
    return obj
end



return M


