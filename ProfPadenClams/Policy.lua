local _,C=...
_G.ProfPadenClams=C
C.clams={[5523]="Small Barnacled Clam",[5524]="Thick-shelled Clam",[7973]="Big-mouth Clam",[15874]="Soft-shelled Clam"}
C.failed={}
function C:Container(name,...)
    local f=C_Container and C_Container[name] or _G[name]
    if f then return f(...) end
end
function C:Item(bag,slot)
    if C_Container and C_Container.GetContainerItemInfo then return C_Container.GetContainerItemInfo(bag,slot) end
    if not GetContainerItemInfo then return end
    local icon,count,locked,quality,readable,loot,link,_,noValue,id=GetContainerItemInfo(bag,slot)
    id=id or (link and tonumber(link:match("item:(%d+)")))
    if id then return {itemID=id,stackCount=count,isLocked=locked,quality=quality,isReadable=readable,hasLoot=loot,hyperlink=link,hasNoValue=noValue,iconFileID=icon} end
end
function C:Key(bag,slot,item)
    return bag..":"..slot..":"..item.itemID..":"..(item.stackCount or 1)
end
function C:Same(a,b)
    return a and b and a.itemID==b.itemID and a.stackCount==b.stackCount and a.hyperlink==b.hyperlink
end
function C:EachBag(fn)
    -- Carried bags only: never bank, mail, keyring or equipped inventory slots.
    for bag=0,(NUM_BAG_SLOTS or 4) do
        local slots=self:Container("GetContainerNumSlots",bag) or 0
        for slot=1,slots do fn(bag,slot,self:Item(bag,slot)) end
    end
end
function C:FreeSlots()
    local total=0
    for bag=0,(NUM_BAG_SLOTS or 4) do
        local free,family=self:Container("GetContainerNumFreeSlots",bag)
        if free and family==0 then total=total+free end
    end
    return total
end
function C:BuildProtection()
    local P=ProfPaden
    if not P or not P.Catalog or not P.Recipes then self.protected=nil;return end
    local keep={}
    for _,index in ipairs({P.Items or {},P.ItemMeta or {},P.GatherItemNames or {},P.MaterialDisenchant or {}}) do
        for id in pairs(index) do keep[id]=true end
    end
    for _,groups in ipairs({P.Recipes,P.Catalog}) do
        for _,recipes in pairs(groups) do for _,recipe in ipairs(recipes) do
            if recipe.item then keep[recipe.item]=true end
            for _,mat in ipairs(recipe.mats or {}) do keep[mat.id]=true end
        end end
    end
    for _,id in ipairs(P.CampItems or {}) do keep[id]=true end
    for key in pairs(P.MaterialSkillRanges or {}) do
        local id=tonumber(tostring(key):match(":(%d+)$"));if id then keep[id]=true end
    end
    self.protected=keep
end
function C:JunkValue(bag,slot,item)
    if not self.protected or not item or item.isLocked or item.quality~=0 or item.hasLoot or item.isReadable then return end
    local id=item.itemID
    if not id or self.clams[id] or self.protected[id] or self.db.keep[id] then return end
    local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getInfo then return end
    local name,_,quality,_,_,_,_,_,equip,_,price,class,subclass,_,_,_,crafting=getInfo(item.hyperlink or id)
    -- Only poor-quality miscellaneous junk. Even gray gear and consumables stay.
    if not name or quality~=0 or class~=15 or subclass~=0 or equip~="" or crafting or type(price)~="number" or price<0 then return end
    local spell=C_Item and C_Item.GetItemSpell or GetItemSpell
    local family=C_Item and C_Item.GetItemFamily or GetItemFamily
    if not spell or not family or spell(id) or family(id)~=0 then return end
    local quest
    if C_Container and C_Container.GetContainerItemQuestInfo then quest=C_Container.GetContainerItemQuestInfo(bag,slot)
    elseif GetContainerItemQuestInfo then local isQuest,questID=GetContainerItemQuestInfo(bag,slot);quest={isQuestItem=isQuest,questID=questID}
    else return end
    if not quest or quest.isQuestItem or quest.questID then return end
    return price*(item.stackCount or 1),name
end
function C:FindJunk()
    -- Include newly learned/client-only recipes without rebuilding the static catalog.
    if self.protected and ProfPaden and ProfPaden.char then
        for _,recipes in pairs(ProfPaden.char.recipes or {}) do for _,recipe in pairs(recipes) do
            if recipe.item then self.protected[recipe.item]=true end
            for _,mat in ipairs(recipe.mats or {}) do if mat.id then self.protected[mat.id]=true end end
        end end
    end
    local best
    self:EachBag(function(bag,slot,item)
        local _,family=self:Container("GetContainerNumFreeSlots",bag)
        -- Deleting from a specialty bag would not free room for arbitrary clam loot.
        local value,name
        if family==0 then value,name=self:JunkValue(bag,slot,item) end
        if value and (not best or value<best.value) then best={bag=bag,slot=slot,item=item,value=value,name=name} end
    end)
    return best
end
function C:FindClam(includeFailed)
    local first,total
    total=0
    self:EachBag(function(bag,slot,item)
        if item and self.clams[item.itemID] and not self.db.keep[item.itemID] then
            total=total+(item.stackCount or 1)
            if not first and not item.isLocked and (includeFailed or not self.failed[self:Key(bag,slot,item)]) then first={bag=bag,slot=slot,item=item} end
        end
    end)
    return first,total
end
