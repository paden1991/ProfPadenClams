local _,C=...
function C:Money(c)
    return string.format("%dg %ds %dc",math.floor(c/10000),math.floor(c/100)%100,c%100)
end
function C:SetEnabled(enabled)
    self:RestoreLootWindow()
    self.db.enabled=enabled;self.pending=nil
    self:Status(enabled and "Ready" or "Paused. Your bags are unchanged.")
    if enabled then self:Retry() end
end
function C:CreateUI()
    if self.panel or InCombatLockdown() then return end
    local f=CreateFrame("Frame","ProfPadenClamsPanel",UIParent,"BackdropTemplate")
    f:SetSize(410,382);f:SetPoint("CENTER",UIParent,"CENTER",0,80);f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG");f:SetMovable(true);f:EnableMouse(true);f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function() if not InCombatLockdown() then f:StartMoving() end end)
    f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
    f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",tile=true,tileSize=32,edgeSize=32,insets={left=8,right=8,top=8,bottom=8}})
    local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("TOPLEFT",22,-20);title:SetText("ProfPaden - Clam Keeper")
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-4,-4)
    local function label(y,h,font)
        local t=f:CreateFontString(nil,"OVERLAY",font or "GameFontHighlightSmall");t:SetPoint("TOPLEFT",22,y);t:SetWidth(366);t:SetHeight(h);t:SetJustifyH("LEFT");t:SetJustifyV("TOP");return t
    end
    f.summary=label(-52,22,"GameFontNormal")
    f.status=label(-79,40)
    local function button(name,text,x,y,w,secure)
        local b=CreateFrame("Button",name,f,secure and "SecureActionButtonTemplate,UIPanelButtonTemplate" or "UIPanelButtonTemplate")
        b:SetSize(w,24);b:SetPoint("TOPLEFT",x,y);b:SetText(text);return b
    end
    f.auto=button(nil,"",22,-123,174)
    f.auto:SetScript("OnClick",function() C:SetEnabled(not C.db.enabled) end)
    f.cleanup=button(nil,"",208,-123,180)
    f.cleanup:SetScript("OnClick",function() C.db.cleanup=not C.db.cleanup;C:Retry() end)
    f.quick=button(nil,"",22,-156,174)
    f.quick:SetScript("OnClick",function() C:SetQuickLoot(not C.db.quickLoot) end)
    f.quickHint=label(-188,20)
    f.quickHint:SetText("Clams only. Loot window returns when attention is needed.")
    f.policy=label(-216,52)
    f.policy:SetText("Full bags: discard the lowest TOTAL vendor-value gray junk stack, only when clam loot needs space.\nMaterials, gear, food and quest items stay protected.")
    f.junk=label(-270,24,"GameFontNormalSmall")
    f.open=button("ProfPadenClamsOpen","Open clam",22,-298,112,true)
    f.open:RegisterForClicks("AnyUp","AnyDown");f.open:SetAttribute("useOnKeyDown",false)
    f.open:SetScript("PreClick",function(b,_,down)
        if down or InCombatLockdown() then return end
        b:SetAttribute("type",nil)
        local clam=C:FindClam(true)
        C.manualClick=true
        if C.db.enabled and clam and C:Begin(clam) then b:SetAttribute("type","item");b:SetAttribute("item",clam.bag.." "..clam.slot) end
    end)
    f.open:SetScript("PostClick",function(_,_,down) if not down then C.manualClick=nil;C:RefreshUI();C:Schedule(.3) end end)
    f.pick=button(nil,"Pick up junk",145,-298,124)
    f.pick:SetScript("OnClick",function()
        if C:Busy(false) then C:Status("Close loot or trading windows and leave combat first.");return end
        local junk=C:FindJunk()
        if junk then
            C.pending=nil
            C:Container("PickupContainerItem",junk.bag,junk.slot)
            C:Status("Drag the selected junk outside your bags to discard it, or return it. Then Retry.")
        end
    end)
    f.retry=button(nil,"Retry",280,-298,108);f.retry:SetScript("OnClick",function() C:Retry() end)
    f.hint=label(-332,38);f.hint:SetText("/ppclams keep <item link or ID> protects an item.\n/ppclams history shows the last 20 discarded stacks.")
    -- Hide the secure action in combat without insecure visibility changes.
    if RegisterStateDriver then RegisterStateDriver(f.open,"visibility","[combat] hide; show") end
    f:Hide();self.panel=f
    UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,"ProfPadenClamsPanel")
end
function C:RefreshUI(attention)
    if not self.db or InCombatLockdown() then return end
    if attention then self:CreateUI() end
    local f=self.panel;if not f then return end
    local clam,total=self:FindClam(true);local junk=self:FindJunk()
    f.summary:SetText(total.." clam(s)  |  "..self:FreeSlots().." free general bag slots")
    local reason=self:BusyReason(false)
    f.status:SetText(not self.db.enabled and "Auto-open is off. Turn it on to continue." or reason and ("Waiting: "..reason) or total>0 and not clam and "Waiting: clam items are locked." or self.status or "Ready")
    f.auto:SetText(self.db.enabled and "Auto-open: On" or "Auto-open: Off")
    f.quick:SetText(self.db.quickLoot and "Silent quick loot: On" or "Silent quick loot: Off")
    f.cleanup:SetText(self.db.cleanup and "Junk cleanup: On" or "Junk cleanup: Off")
    f.junk:SetText(junk and ("Cheapest junk: "..(junk.name or ("Item "..junk.item.itemID)).." x"..junk.item.stackCount.." - "..self:Money(junk.value)) or "No disposable gray junk. Useful items are protected.")
    -- Begin refreshes the UI from PreClick. Do not disable this same button
    -- before its native secure item handler has received the click.
    if not self.manualClick then f.open:SetEnabled(clam~=nil and self.db.enabled and not self.pending and not reason) end
    f.pick:SetEnabled(junk~=nil and not self:Busy(false))
    if attention then f:Show() end
end
SLASH_PROFPADENCLAMS1="/ppclams"
SlashCmdList.PROFPADENCLAMS=function(msg)
    if not C.db then return end
    local command,arg=(msg or ""):match("^(%S*)%s*(.-)%s*$");command=command:lower()
    if command=="on" or command=="off" then C:SetEnabled(command=="on");C:Print("Auto-open "..command..".")
    elseif command=="quickloot" and (arg=="on" or arg=="off") then C:SetQuickLoot(arg=="on");C:Print("Silent quick loot "..arg..".")
    elseif command=="retry" then C:Retry()
    elseif command=="status" then C:Diagnostics()
    elseif command=="cleanup" and (arg=="on" or arg=="off") then C.db.cleanup=arg=="on";C:Retry();C:Print("Junk cleanup "..arg..".")
    elseif command=="keep" or command=="unkeep" then
        local id=tonumber(arg:match("item:(%d+)")) or tonumber(arg)
        if not id or id<=0 or id~=math.floor(id) then C:Print("Use /ppclams "..command.." <item link or ID>.");return end
        C.db.keep[id]=command=="keep" or nil;C:Retry();C:Print("Item "..id..(command=="keep" and " protected." or " removed from your keep list; built-in protections still apply."))
    elseif command=="history" then
        if #C.db.history==0 then C:Print("No stacks discarded.") end
        for _,v in ipairs(C.db.history) do C:Print(date("%d %b %H:%M",v.time).." - item:"..v.id.." x"..v.count.." - "..C:Money(v.value)) end
    else
        if InCombatLockdown() then C:Print("Clam controls are available outside combat.");return end
        C:CreateUI();C:RefreshUI();C.panel:SetShown(not C.panel:IsShown())
    end
end
