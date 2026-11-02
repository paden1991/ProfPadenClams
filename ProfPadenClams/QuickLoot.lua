local _,C=...

function C:VerifyClamLoot()
    local p=self.pending
    if not p or not self.db or not self.db.enabled or GetTime()-p.started>8 then return false end
    local verified,hasSources=false,false
    if GetLootSourceInfo and GetNumLootItems then
        verified=p.guid~=nil and GetNumLootItems()>0
        for slot=1,GetNumLootItems() do
            local sources={GetLootSourceInfo(slot)}
            if #sources>0 then hasSources=true else verified=false end
            for i=1,#sources,2 do if sources[i]~=p.guid then verified=false end end
        end
    end
    -- Only our synchronous bag-use call can substitute for missing source data.
    -- Explicit foreign sources always win, even when the item GUID is unavailable.
    return verified or (self.opening and not hasSources) or false
end

function C:RestoreLootWindow()
    local s=self.silentLoot
    self.silentLoot=nil
    if s and self.lootOpen and GetNumLootItems and GetNumLootItems()>0 then
        s.pending.showLoot=true
        -- Replay the normal open event with manual looting. Hide() would close
        -- the underlying loot session, so never hide an already-open LootFrame.
        s.handler(s.frame,"LOOT_OPENED",false)
    end
end

function C:InstallQuickLoot()
    local frame=LootFrame
    if not frame or self.lootFrame==frame or not frame.GetScript then return end
    local handler=frame:GetScript("OnEvent")
    if type(handler)~="function" then return end
    self.lootFrame=frame
    frame:SetScript("OnEvent",function(f,event,...)
        local p=C.pending
        if event=="LOOT_OPENED" and C.db and C.db.quickLoot and C_Timer and C_Timer.After
            and not InCombatLockdown() and p and not p.showLoot and C:VerifyClamLoot() then
            -- Evaluate here too: Blizzard's frame may receive this event before
            -- our own frame. No event registrations or global loot settings change.
            C.silentLoot={pending=p,frame=f,handler=handler}
            C:QueueQuickLoot(p)
            return
        end
        return handler(f,event,...)
    end)
end

function C:QueueQuickLoot(p)
    if p.quickQueued or not C_Timer or not C_Timer.After then return end
    p.quickQueued=true
    -- Next frame, after every LOOT_OPENED listener has run. A separate timer
    -- avoids the general bag-update timer delaying this pass by half a second.
    C_Timer.After(0,function()
        if C.pending~=p or not C.lootOpen then return end
        if C.db.enabled and C.db.quickLoot then C:LootOwnClam() end
    end)
    C_Timer.After(1,function()
        if C.pending==p and C.silentLoot and C.silentLoot.pending==p then
            C:RestoreLootWindow() -- blocked/locked loot must remain accessible
        end
    end)
end

function C:SetQuickLoot(enabled)
    self.db.quickLoot=enabled
    if not enabled then self:RestoreLootWindow() end
    self:RefreshUI()
end
