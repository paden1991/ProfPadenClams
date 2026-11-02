local addon,C=...
local function now() return GetTime() end
function C:Print(text) print("|cffffd100Clam Keeper:|r "..text) end
function C:Status(text,attention)
    self.status=text
    if self.RefreshUI then self:RefreshUI(attention) end
end
function C:Busy(allowOwnLoot)
    if InCombatLockdown() or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return true end
    if (GetCursorInfo and GetCursorInfo()) or (UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player")) then return true end
    if next(self.interactions) then return true end
    for _,name in ipairs({"MerchantFrame","BankFrame","MailFrame","TradeFrame","AuctionFrame","AuctionHouseFrame"}) do
        local f=_G[name];if f and f:IsShown() then return true end
    end
    local lootVisible=self.lootOpen or (LootFrame and LootFrame:IsShown()) or (GetNumLootItems and GetNumLootItems()>0)
    return lootVisible and not (allowOwnLoot and self.pending and self.pending.ownsLoot)
end
function C:Schedule(delay)
    if self.scheduled or not self.db or not C_Timer then return end
    self.scheduled=true
    C_Timer.After(delay or .3,function() self.scheduled=false;self:Step() end)
end
function C:Pause(text)
    self:RestoreLootWindow()
    if self.pending then self.failed[self:Key(self.pending.bag,self.pending.slot,self.pending.item)]=true end
    self.pending=nil;self:Status(text,true)
end
function C:Begin(clam)
    self:InstallQuickLoot()
    if self:Busy(false) then return false end
    local current=self:Item(clam.bag,clam.slot)
    if not self:Same(clam.item,current) or current.isLocked or not self.clams[current.itemID] or self.db.keep[current.itemID] then return false end
    local snapshot={};for k,v in pairs(current) do snapshot[k]=v end
    clam.item=snapshot;clam.started=now();clam.removed=0;self.pending=clam
    if ItemLocation and C_Item and C_Item.GetItemGUID then
        clam.guid=C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(clam.bag,clam.slot))
    end
    self:Status("Opening "..self.clams[current.itemID].."...")
    self:Schedule(.5)
    return true
end
function C:Open(clam)
    if not self:Begin(clam) then return end
    -- Only the common bag/slot arguments: newer clients changed the fourth argument.
    self.opening=true
    local ok=pcall(self.Container,self,"UseContainerItem",clam.bag,clam.slot)
    self.opening=nil
    if not ok then self.manualOpen=true;self:Pause("Click Open clam to continue on this client.") end
end
function C:DeleteJunk(candidate)
    if self:Busy(true) or not self.pending or not self.pending.full or not self.db.cleanup or self:FreeSlots()>0 then return false end
    local current=self:Item(candidate.bag,candidate.slot)
    local value=self:JunkValue(candidate.bag,candidate.slot,current)
    if not self:Same(candidate.item,current) or value~=candidate.value then return false end
    if not GetCursorInfo or GetCursorInfo() or not DeleteCursorItem then return false end
    -- Claim just this stack; recheck cursor identity before any irreversible action.
    self.action="delete"
    local picked=pcall(self.Container,self,"PickupContainerItem",candidate.bag,candidate.slot)
    local kind,id=GetCursorInfo()
    if not picked or kind~="item" or id~=current.itemID then
        self.action=nil;self.manualDelete=true
        return false
    end
    local ok=pcall(DeleteCursorItem)
    self.action=nil
    if not ok or GetCursorInfo() then
        -- Return only the stack we just picked up; never disturb a preexisting cursor.
        local k,i=GetCursorInfo();if k=="item" and i==current.itemID and ClearCursor then ClearCursor() end
        self.manualDelete=true;return false
    end
    self.pending.removed=self.pending.removed+1
    self.pending.full=false
    self.pending.waitSpace=now()
    self.pending.reopen=not self.pending.ownsLoot
    local entry={id=current.itemID,count=current.stackCount or 1,value=value,time=time()}
    table.insert(self.db.history,1,entry);while #self.db.history>20 do table.remove(self.db.history) end
    self:Print("Discarded "..(current.hyperlink or candidate.name or ("item:"..current.itemID)).." x"..entry.count.." ("..self:Money(value).." total vendor value) for clam loot.")
    self:Status("Making room for clam loot...");self:Schedule(.4)
    return true
end
function C:LootOwnClam()
    local p=self.pending
    if not p or not p.ownsLoot or not self.lootOpen or self:Busy(true) then return end
    if not GetNumLootItems or not LootSlot then self:Pause("Loot the clam in the loot window to continue.");return end
    -- No confirmation overrides. Never loot a corpse, chest or another player's loot.
    for slot=GetNumLootItems(),1,-1 do
        if self.pending~=p or not self.lootOpen or p.full then break end
        local ok=pcall(LootSlot,slot)
        if not ok then self:Pause("Loot the clam in the loot window to continue.");break end
    end
end
function C:Step()
    if not self.db or not self.db.enabled then return end
    if self:Busy(true) then return end
    local p=self.pending
    if p then
        if p.waitSpace then
            if self:FreeSlots()>0 then p.waitSpace=nil;p.started=now()
            elseif now()-p.waitSpace>3 then self:Pause("Bag update did not confirm free space. Retry when ready.");return
            else self:Schedule(.4);return end
        end
        local current=self:Item(p.bag,p.slot)
        if not p.ownsLoot and not self:Same(p.item,current) then
            self.pending=nil;self:Status("Ready");self:Schedule();return
        end
        if p.reopen then
            p.reopen=nil;self.opening=true
            local ok=pcall(self.Container,self,"UseContainerItem",p.bag,p.slot)
            self.opening=nil
            if not ok then self.manualOpen=true;self:Pause("Click Open clam to continue.");return end
        end
        if p.full then
            if self:FreeSlots()>0 then p.full=false;p.started=now()
            else
                local junk=self:FindJunk()
                if not self.db.cleanup then self:Pause("Bags full. Free a slot or enable junk cleanup.");return end
                if not junk then self:Pause("Bags full. No disposable gray junk; useful items kept.");return end
                if p.removed>=2 then self:Pause("Still full after two stacks. Check your bags, then Retry.");return end
                if self.manualDelete or not self:DeleteJunk(junk) then self:Pause("Free a slot manually. Pick up junk selects the cheapest safe stack.") end
                return
            end
            if not p.ownsLoot then
                self.opening=true
                local ok=pcall(self.Container,self,"UseContainerItem",p.bag,p.slot)
                self.opening=nil
                if not ok then self.manualOpen=true;self:Pause("Click Open clam to continue.");return end
            end
        end
        if p.ownsLoot then self:LootOwnClam() end
        if self.pending and now()-p.started>8 then
            self.manualOpen=true;self:Pause("Opening paused. Click Open clam or Retry when ready.")
        elseif self.pending then self:Schedule(.5) end
        return
    end
    local clam,total=self:FindClam()
    if not clam then if total==0 then self:Status("No clams in your bags.") end;return end
    if self.manualOpen then self:Status("Clams ready. Click Open clam to continue.",true);return end
    self:Open(clam)
end
function C:Retry()
    if self.lootOpen then self:Status("Close the loot window, then Retry.",true);return end
    self.failed={};self.pending=nil
    self:Status("Ready");self:Schedule()
end
function C:Init()
    ProfPadenClamsDB=ProfPadenClamsDB or {}
    self.db=ProfPadenClamsDB
    if self.db.enabled==nil then self.db.enabled=true end
    if self.db.cleanup==nil then self.db.cleanup=true end
    if self.db.quickLoot==nil then self.db.quickLoot=true end
    self:InstallQuickLoot()
    self.db.keep=self.db.keep or {};self.db.history=self.db.history or {}
    self.interactions={};self:BuildProtection();self:Status("Ready");self:Schedule(2)
end
local opens={MERCHANT_SHOW="merchant",BANKFRAME_OPENED="bank",MAIL_SHOW="mail",TRADE_SHOW="trade",AUCTION_HOUSE_SHOW="auction"}
local closes={MERCHANT_CLOSED="merchant",BANKFRAME_CLOSED="bank",MAIL_CLOSED="mail",TRADE_CLOSED="trade",AUCTION_HOUSE_CLOSED="auction"}
function C:Event(event,a,b)
    if event=="PLAYER_LOGIN" then self:Init();return end
    if not self.db then return end
    if opens[event] then self:RestoreLootWindow();self.interactions[opens[event]]=true;self.pending=nil;return end
    if closes[event] then self.interactions[closes[event]]=nil;self:Schedule();return end
    if event=="ADDON_ACTION_BLOCKED" or event=="ADDON_ACTION_FORBIDDEN" then
        if a==addon then
            if self.action=="delete" or tostring(b):find("DeleteCursorItem",1,true) then self.manualDelete=true
            else self.manualOpen=true;self:Pause("This client needs a click. Use Open clam.") end
        end
        return
    end
    if event=="PLAYER_REGEN_DISABLED" or event=="PLAYER_LEAVING_WORLD" then self:RestoreLootWindow();self.pending=nil;return end
    if event=="LOOT_OPENED" then
        self.lootOpen=true
        local p=self.pending
        if p and now()-p.started<=8 then
            if self:VerifyClamLoot() then
                p.ownsLoot=true
                if self.db.quickLoot then self:QueueQuickLoot(p) end
                self:Schedule(.1)
            else self:Pause("Loot source could not be verified. Loot the clam manually.") end
        end
        return
    end
    if event=="LOOT_CLOSED" then
        self.lootOpen=false;self.silentLoot=nil
        if self.pending then
            local p=self.pending
            self.pending.ownsLoot=nil;self.pending.quickQueued=nil;self.pending.showLoot=nil
            if not p.full and not p.waitSpace then
                if self:Same(p.item,self:Item(p.bag,p.slot)) then self.failed[self:Key(p.bag,p.slot,p.item)]=true end
                self.pending=nil
            end
        end
        self:Schedule(.5);return
    end
    if event=="LOOT_BIND_CONFIRM" then
        if self.pending and self.pending.ownsLoot then self:Pause("Confirm the clam loot in the loot window to continue.") end
        return
    end
    if event=="UI_ERROR_MESSAGE" then
        local message=b or a
        if self.pending and (self.pending.ownsLoot or self.opening) and self.db.enabled and now()-self.pending.started<=8 and message==ERR_INV_FULL and not self:Busy(true) then
            self.pending.full=true;self:RestoreLootWindow();self:Schedule(.3)
        end
        return
    end
    if event=="GET_ITEM_INFO_RECEIVED" and not b then return end
    self:Schedule()
end
C.events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","BAG_UPDATE_DELAYED","ITEM_UNLOCKED","GET_ITEM_INFO_RECEIVED","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_CHANNEL_STOP","CURSOR_CHANGED","LOOT_OPENED","LOOT_CLOSED","LOOT_SLOT_CLEARED","LOOT_BIND_CONFIRM","UI_ERROR_MESSAGE","ADDON_ACTION_BLOCKED","ADDON_ACTION_FORBIDDEN"}) do pcall(C.events.RegisterEvent,C.events,event) end
for event in pairs(opens) do pcall(C.events.RegisterEvent,C.events,event) end
for event in pairs(closes) do pcall(C.events.RegisterEvent,C.events,event) end
C.events:SetScript("OnEvent",function(_,...) C:Event(...) end)
