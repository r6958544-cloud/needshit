AddCSLuaFile()
if not CLIENT then return end

-- =====================================================================
--  FPV Дроны: меню настроек в собственном дизайне
--  Открывается: C-меню → иконка «FPV Дроны», либо командой zfpv_menu
-- =====================================================================

local FPVMenu = {}
local W, H = 820, 580

local C = {
    bg        = Color(21, 23, 29),
    side      = Color(27, 30, 38),
    card      = Color(35, 39, 49),
    chip      = Color(50, 41, 38),
    line      = Color(52, 57, 70),
    track     = Color(52, 57, 70),
    off       = Color(66, 72, 90),
    accent    = Color(255, 122, 48),
    accentDim = Color(150, 95, 60),
    text      = Color(236, 239, 246),
    sub       = Color(141, 150, 168),
    good      = Color(76, 175, 120),
    bad       = Color(214, 76, 76),
    warn      = Color(70, 48, 44),
}

surface.CreateFont("FPVMenu_Title", { font = "Roboto", size = 24, weight = 800, extended = true })
surface.CreateFont("FPVMenu_Label", { font = "Roboto", size = 17, weight = 600, extended = true })
surface.CreateFont("FPVMenu_Head",  { font = "Roboto", size = 14, weight = 800, extended = true })
surface.CreateFont("FPVMenu_Small", { font = "Roboto", size = 14, weight = 400, extended = true })

local CENTER = TEXT_ALIGN_CENTER

local function LerpColor(t, a, b)
    return Color(
        Lerp(t, a.r, b.r), Lerp(t, a.g, b.g), Lerp(t, a.b, b.b), Lerp(t, a.a or 255, b.a or 255)
    )
end

local function Fmt(v, def)
    return string.format("%." .. (def.dec or 0) .. "f", v) .. (def.unit or "")
end

-- =====================================================================
--  Строительные блоки
-- =====================================================================
local function NewRow(page, h)
    local row = vgui.Create("DPanel")
    page:Add(row)
    row:Dock(TOP)
    row:SetTall(h)
    row:DockMargin(0, 0, 0, 8)
    row.Paint = function() end
    return row
end

local function MakeHeader(page, text)
    local row = vgui.Create("DPanel")
    page:Add(row)
    row:Dock(TOP)
    row:SetTall(32)
    row:DockMargin(0, 8, 0, 6)
    row.Paint = function(s, w, h)
        draw.SimpleText(text, "FPVMenu_Head", 2, h - 8, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
        surface.SetDrawColor(C.line)
        surface.DrawRect(0, h - 1, w, 1)
    end
end

local function MakeToggle(page, def, locked)
    local row = NewRow(page, 62)
    local pendingUntil, pendingVal = 0, false

    local function current()
        if CurTime() < pendingUntil then return pendingVal end
        local cv = GetConVar(def.cvar)
        return cv and cv:GetBool() or false
    end

    row.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.card)
        draw.SimpleText(def.label, "FPVMenu_Label", 16, 13, locked and C.sub or C.text)
        draw.SimpleText(def.desc, "FPVMenu_Small", 16, 36, C.sub)
    end

    local sw = vgui.Create("DButton", row)
    sw:SetText("")
    sw:SetSize(48, 26)
    sw:SetCursor(locked and "no" or "hand")

    local k = current() and 1 or 0
    sw.Paint = function(s, w, h)
        k = Lerp(FrameTime() * 14, k, current() and 1 or 0)
        draw.RoundedBox(h / 2, 0, 0, w, h, LerpColor(k, C.off, locked and C.accentDim or C.accent))
        draw.RoundedBox((h - 8) / 2, 4 + k * (w - h), 4, h - 8, h - 8, C.text)
    end
    sw.DoClick = function()
        if locked then return end
        local new = not current()
        if def.server then
            pendingVal, pendingUntil = new, CurTime() + 0.8
            ZFPV.SendSetting(def.cvar, new and 1 or 0)
        else
            RunConsoleCommand(def.cvar, new and "1" or "0")
        end
        surface.PlaySound("garrysmod/ui_click.wav")
    end

    row.PerformLayout = function(s, w, h)
        sw:SetPos(w - 48 - 16, (h - 26) / 2)
    end
end

local function MakeSlider(page, def, locked)
    local row = NewRow(page, 78)
    local dragging, holdUntil = false, 0

    local function getVal()
        local cv = GetConVar(def.cvar)
        return cv and cv:GetFloat() or def.default
    end

    local value = getVal()

    row.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.card)
        draw.SimpleText(def.label, "FPVMenu_Label", 16, 12, locked and C.sub or C.text)
        draw.SimpleText(def.desc, "FPVMenu_Small", 16, 34, C.sub)
        draw.SimpleText(Fmt(value, def), "FPVMenu_Label", w - 16, 12, locked and C.accentDim or C.accent, TEXT_ALIGN_RIGHT)
    end

    local bar = vgui.Create("DPanel", row)
    bar:SetCursor(locked and "no" or "hand")

    bar.Paint = function(s, w, h)
        local frac = math.Clamp((value - def.min) / (def.max - def.min), 0, 1)
        local ty = h / 2 - 3
        draw.RoundedBox(3, 0, ty, w, 6, C.track)
        draw.RoundedBox(3, 0, ty, math.max(6, w * frac), 6, locked and C.accentDim or C.accent)
        local kx = 8 + (w - 16) * frac
        draw.RoundedBox(8, kx - 8, h / 2 - 8, 16, 16, locked and C.sub or C.text)
    end

    local function update()
        local x = bar:CursorPos()
        local frac = math.Clamp((x - 8) / math.max(1, bar:GetWide() - 16), 0, 1)
        local mult = 10 ^ (def.dec or 0)
        local v = math.Round((def.min + frac * (def.max - def.min)) * mult) / mult
        if v ~= value then
            value = v
            if not def.server then RunConsoleCommand(def.cvar, tostring(v)) end
        end
    end

    bar.OnMousePressed = function(s, key)
        if locked or key ~= MOUSE_LEFT then return end
        dragging = true
        s:MouseCapture(true)
        update()
    end
    bar.OnMouseReleased = function(s, key)
        if not dragging then return end
        dragging = false
        s:MouseCapture(false)
        if def.server then
            ZFPV.SendSetting(def.cvar, value)
            holdUntil = CurTime() + 0.8
        end
    end
    bar.Think = function()
        if dragging then
            update()
        elseif CurTime() > holdUntil then
            value = getVal()
        end
    end

    row.PerformLayout = function(s, w, h)
        bar:SetPos(16, h - 30)
        bar:SetSize(w - 32, 20)
    end
end

local SWATCHES = {
    "120 255 120", "255 255 255", "80 220 255", "255 160 60", "255 80 80", "255 230 80", "255 120 220",
}

local function MakeColors(page, def)
    local row = NewRow(page, 88)

    row.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.card)
        draw.SimpleText(def.label, "FPVMenu_Label", 16, 12, C.text)
        draw.SimpleText(def.desc, "FPVMenu_Small", 16, 34, C.sub)
    end

    local buttons = {}
    for i, str in ipairs(SWATCHES) do
        local b = vgui.Create("DButton", row)
        b:SetText("")
        b:SetSize(32, 32)
        b:SetCursor("hand")
        local r, g, bl = string.match(str, "(%d+)%s+(%d+)%s+(%d+)")
        local col = Color(tonumber(r), tonumber(g), tonumber(bl))
        b.Paint = function(s, w, h)
            if GetConVar(def.cvar):GetString() == str then
                draw.RoundedBox(9, 0, 0, w, h, C.text)
                draw.RoundedBox(6, 3, 3, w - 6, h - 6, col)
            else
                draw.RoundedBox(8, 2, 2, w - 4, h - 4, col)
            end
        end
        b.DoClick = function()
            RunConsoleCommand(def.cvar, str)
            surface.PlaySound("garrysmod/ui_click.wav")
        end
        buttons[i] = b
    end

    row.PerformLayout = function(s, w, h)
        for i, b in ipairs(buttons) do
            b:SetPos(16 + (i - 1) * 42, h - 46)
        end
    end
end

local function StyleButton(btn, text, col, locked)
    btn:SetText("")
    btn:SetCursor(locked and "no" or "hand")
    local k = 0
    btn.Paint = function(s, w, h)
        k = Lerp(FrameTime() * 12, k, (s:IsHovered() and not locked) and 1 or 0)
        local base = locked and C.off or col
        draw.RoundedBox(10, 0, 0, w, h, LerpColor(k, base, LerpColor(0.22, base, C.text)))
        draw.SimpleText(text, "FPVMenu_Label", w / 2, h / 2, locked and C.sub or C.text, CENTER, CENTER)
    end
end

-- buttons = { { text = "", color = Color, fn = function, locked = bool }, ... }
local function MakeButtonRow(page, buttons)
    local row = NewRow(page, 48)
    local btns = {}
    for i, def in ipairs(buttons) do
        local b = vgui.Create("DButton", row)
        StyleButton(b, def.text, def.color, def.locked)
        b.DoClick = function()
            if def.locked then return end
            surface.PlaySound("garrysmod/ui_click.wav")
            def.fn()
        end
        btns[i] = b
    end
    row.PerformLayout = function(s, w, h)
        local gap = 10
        local bw = (w - gap * (#btns - 1)) / #btns
        for i, b in ipairs(btns) do
            b:SetPos((i - 1) * (bw + gap), 0)
            b:SetSize(bw, h)
        end
    end
end

local function MakeBanner(page, text, col)
    local row = NewRow(page, 46)
    row.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, col)
        draw.RoundedBox(4, 0, 8, 4, h - 16, C.accent)
        draw.SimpleText(text, "FPVMenu_Small", 18, h / 2, C.text, TEXT_ALIGN_LEFT, CENTER)
    end
end

local function MakeKeyRow(page, key, desc)
    local row = NewRow(page, 46)
    row.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.card)
        draw.RoundedBox(8, 10, 8, 150, h - 16, C.chip)
        draw.SimpleText(key, "FPVMenu_Label", 10 + 75, h / 2, C.accent, CENTER, CENTER)
        draw.SimpleText(desc, "FPVMenu_Label", 178, h / 2, C.text, TEXT_ALIGN_LEFT, CENTER)
    end
end

local function MakeInfoCard(page, title, lines)
    local row = NewRow(page, 44 + #lines * 24)
    row.Paint = function(s, w, h)
        draw.RoundedBox(10, 0, 0, w, h, C.card)
        draw.SimpleText(title, "FPVMenu_Label", 16, 12, C.text)
        for i, line in ipairs(lines) do
            draw.SimpleText("•  " .. line, "FPVMenu_Small", 18, 22 + i * 24, C.sub)
        end
    end
end

local function StyleScroll(sp)
    local vbar = sp:GetVBar()
    vbar:SetWide(6)
    vbar:SetHideButtons(true)
    vbar.Paint = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, C.track) end
    vbar.btnGrip.Paint = function(s, w, h) draw.RoundedBox(3, 0, 0, w, h, C.accent) end
end

local function FillSettings(page, list, isServer, locked)
    for _, def in ipairs(list) do
        def.server = isServer
        if def.type == "header" then
            MakeHeader(page, def.text)
        elseif def.type == "slider" then
            MakeSlider(page, def, locked)
        elseif def.type == "toggle" then
            MakeToggle(page, def, locked)
        elseif def.type == "colors" then
            MakeColors(page, def)
        end
    end
end

-- =====================================================================
--  Сборка окна
-- =====================================================================
function FPVMenu.Build(window)
    local w, h = window:GetSize()
    local isAdmin = IsValid(LocalPlayer()) and LocalPlayer():IsAdmin()

    window:SetTitle("")
    window:ShowCloseButton(false)
    window:SetDraggable(false)
    window:SetSizable(false)
    window.Paint = function(s, pw, ph)
        draw.RoundedBox(14, 0, 0, pw, ph, C.bg)
    end

    window:SetAlpha(0)
    window:AlphaTo(255, 0.18, 0)

    -- ----- Шапка (за неё можно таскать окно) -----
    local header = vgui.Create("DPanel", window)
    header:SetPos(0, 0)
    header:SetSize(w, 60)
    header:SetCursor("sizeall")
    header.Paint = function(s, pw, ph)
        draw.RoundedBoxEx(14, 0, 0, pw, ph, C.side, true, true, false, false)
        draw.RoundedBox(6, 20, 18, 26, 26, C.accent)
        draw.SimpleText("FPV", "FPVMenu_Head", 33, 31, C.bg, CENTER, CENTER)
        draw.SimpleText("FPV ДРОНЫ", "FPVMenu_Title", 58, 17, C.text)
        draw.SimpleText("Настройки аддона", "FPVMenu_Small", 58, 40, C.sub)
    end

    local dragging, ox, oy = false, 0, 0
    header.OnMousePressed = function(s, key)
        if key ~= MOUSE_LEFT then return end
        local wx, wy = window:GetPos()
        ox, oy = gui.MouseX() - wx, gui.MouseY() - wy
        dragging = true
        s:MouseCapture(true)
    end
    header.OnMouseReleased = function(s)
        dragging = false
        s:MouseCapture(false)
    end
    header.Think = function()
        if dragging then window:SetPos(gui.MouseX() - ox, gui.MouseY() - oy) end
    end

    local close = vgui.Create("DButton", header)
    close:SetText("")
    close:SetSize(34, 34)
    close:SetPos(w - 34 - 14, 13)
    close:SetCursor("hand")
    local ck = 0
    close.Paint = function(s, bw, bh)
        ck = Lerp(FrameTime() * 12, ck, s:IsHovered() and 1 or 0)
        draw.RoundedBox(8, 0, 0, bw, bh, LerpColor(ck, C.side, C.bad))
        surface.SetDrawColor(C.text)
        local m = 11
        surface.DrawLine(m, m, bw - m, bh - m)
        surface.DrawLine(m + 1, m, bw - m + 1, bh - m)
        surface.DrawLine(bw - m, m, m, bh - m)
        surface.DrawLine(bw - m + 1, m, m + 1, bh - m)
    end
    close.DoClick = function() window:Close() end

    -- ----- Боковая панель -----
    local sidebar = vgui.Create("DPanel", window)
    sidebar:SetPos(0, 60)
    sidebar:SetSize(196, h - 60)
    sidebar.Paint = function(s, pw, ph)
        draw.RoundedBoxEx(14, 0, 0, pw, ph, C.side, false, false, true, false)
        draw.SimpleText("FPV Drones v1.1 (by kabukig)", "FPVMenu_Small", 22, ph - 24, C.sub)
    end

    -- ----- Область страниц -----
    local content = vgui.Create("DPanel", window)
    content:SetPos(196, 60)
    content:SetSize(w - 196, h - 60)
    content.Paint = function() end

    local pages = {}
    for i = 1, 3 do
        local sp = vgui.Create("DScrollPanel", content)
        sp:Dock(FILL)
        sp:GetCanvas():DockPadding(22, 14, 26, 16)
        StyleScroll(sp)
        sp:SetVisible(false)
        pages[i] = sp
    end

    -- Страница 1: игрок
    FillSettings(pages[1], ZFPV.ClientSettings, false, false)
    MakeHeader(pages[1], "ДЕЙСТВИЯ")
    MakeButtonRow(pages[1], {
        { text = "Сбросить мои настройки", color = C.off, fn = function()
            for _, def in ipairs(ZFPV.ClientSettings) do
                if def.cvar then RunConsoleCommand(def.cvar, tostring(def.default)) end
            end
        end },
    })

    -- Страница 2: сервер
    local locked = not isAdmin
    if locked then
        MakeBanner(pages[2], "Только для администраторов: значения можно смотреть, но нельзя менять.", C.warn)
    end

    MakeHeader(pages[2], "ПРЕСЕТЫ")
    local presetButtons = {}
    local presetColors = { C.good, C.accent, C.bad }
    for i, preset in ipairs(ZFPV.Presets) do
        presetButtons[i] = {
            text = preset.name, color = presetColors[i] or C.off, locked = locked,
            fn = function()
                for cvar, val in pairs(preset.values) do ZFPV.SendSetting(cvar, val) end
            end,
        }
    end
    MakeButtonRow(pages[2], presetButtons)

    FillSettings(pages[2], ZFPV.ServerSettings, true, locked)

    MakeHeader(pages[2], "ДЕЙСТВИЯ АДМИНА")
    MakeButtonRow(pages[2], {
        { text = "Сбросить настройки сервера", color = C.off, locked = locked,
          fn = function() ZFPV.SendAction("reset") end },
        { text = "Убрать все дроны на карте", color = C.bad, locked = locked,
          fn = function() ZFPV.SendAction("clear") end },
    })

    -- Страница 3: управление
    MakeHeader(pages[3], "КЛАВИШИ")
    MakeKeyRow(pages[3], "ЛКМ", "Запустить дрон с пульта / взорвать в полёте")
    MakeKeyRow(pages[3], "МЫШЬ", "Курс и наклон дрона")
    MakeKeyRow(pages[3], "W A S D", "Движение относительно взгляда")
    MakeKeyRow(pages[3], "ПРОБЕЛ / CTRL", "Подъём / снижение")
    MakeKeyRow(pages[3], "SHIFT", "Ускорение")
    MakeKeyRow(pages[3], "R", "Вернуть дрон без взрыва")
    MakeHeader(pages[3], "ПОЛЕЗНО ЗНАТЬ")
    MakeInfoCard(pages[3], "Когда дрон взрывается", {
        "при ударе о стену, пропы или игроков на достаточной скорости",
        "если в него выстрелили",
        "если пилот погиб: дрон падает и взрывается по таймеру",
    })
    MakeInfoCard(pages[3], "Советы", {
        "тело пилота остаётся на месте и уязвимо: прячься перед полётом",
        "медленное касание не взрывает дрон, можно аккуратно приземлиться",
        "пульт берётся во вкладке Weapons → FPV Drones",
    })

    -- ----- Вкладки -----
    local tabNames = { "Игрок", "Сервер", "Управление" }
    local tabButtons = {}
    local active = 1

    local function SetTab(i)
        active = i
        for idx, p in ipairs(pages) do p:SetVisible(idx == i) end
    end

    for i, name in ipairs(tabNames) do
        local b = vgui.Create("DButton", sidebar)
        b:SetText("")
        b:SetPos(12, 16 + (i - 1) * 52)
        b:SetSize(172, 44)
        b:SetCursor("hand")
        local k = 0
        b.Paint = function(s, bw, bh)
            local on = active == i
            k = Lerp(FrameTime() * 12, k, (on and 1) or (s:IsHovered() and 0.5 or 0))
            draw.RoundedBox(10, 0, 0, bw, bh, LerpColor(k, C.side, C.card))
            if on then draw.RoundedBox(3, 0, 10, 4, bh - 20, C.accent) end
            draw.SimpleText(name, "FPVMenu_Label", 22, bh / 2, on and C.text or C.sub, TEXT_ALIGN_LEFT, CENTER)
            if i == 2 and not isAdmin then
                draw.SimpleText("админ", "FPVMenu_Small", bw - 14, bh / 2, C.accentDim, TEXT_ALIGN_RIGHT, CENTER)
            end
        end
        b.DoClick = function()
            surface.PlaySound("garrysmod/ui_click.wav")
            SetTab(i)
        end
        tabButtons[i] = b
    end

    SetTab(1)
end

-- =====================================================================
--  Точки входа
-- =====================================================================
-- C-меню: иконка «FPV Дроны»
list.Set("DesktopWindows", "ZFPVMenu", {
    title     = "Z-City FPV",
    icon      = "icon64/tool.png",
    width     = W,
    height    = H,
    onewindow = true,
    init      = function(icon, window)
        FPVMenu.Build(window)
    end,
})

-- Отдельное окно: консольная команда zfpv_menu
concommand.Add("zfpv_menu", function()
    if IsValid(FPVMenu.Frame) then FPVMenu.Frame:Remove() end

    local f = vgui.Create("DFrame")
    f:SetSize(W, H)
    f:Center()
    f:MakePopup()
    FPVMenu.Build(f)
    FPVMenu.Frame = f
end)

-- Q-меню → Utilities: полноценные настройки дрона
local function toolSlider(parent, cvarName, label, minv, maxv, dec)
    local cv = GetConVar(cvarName)
    local slider = vgui.Create("DNumSlider", parent)
    slider:SetText(label)
    slider:SetMin(minv or 0)
    slider:SetMax(maxv or 1)
    slider:SetDecimals(dec or 0)
    slider:SetValue(cv and cv:GetFloat() or (minv or 0))
    slider.OnValueChanged = function(_, val)
        local v = (dec or 0) > 0 and val or math.Round(val)
        ZFPV.SendSetting(cvarName, v)
    end
    parent:AddItem(slider)
    return slider
end

local function toolToggle(parent, cvarName, label, hint)
    local cv = GetConVar(cvarName)
    local cb = vgui.Create("DCheckBoxLabel", parent)
    cb:SetText(label)
    cb:SetValue((cv and cv:GetFloat() or 0) ~= 0)
    cb.OnChange = function(_, val)
        ZFPV.SendSetting(cvarName, val and 1 or 0)
    end
    parent:AddItem(cb)

    if hint then
        parent:ControlHelp(hint)
    end
    return cb
end

hook.Add("PopulateToolMenu", "ZFPV_ToolMenu", function()
    spawnmenu.AddToolMenuOption("Utilities", "Z-City FPV", "zfpv_drone_menu", "Дрон FPV", "", "", function(panel)
        panel:ClearControls()

        panel:Help("Настройки сервера, применяются сразу (нужны права админа).")

        -- КОГДА ВЗРЫВАЕТСЯ: два варианта
        panel:Help("КОГДА ВЗРЫВАЕТСЯ")
        local combo = vgui.Create("DComboBox", panel)
        combo:AddChoice("Только ЛКМ (удары безвредны)", 0)
        combo:AddChoice("Удар + ЛКМ", 1)

        local cvImpact = GetConVar("zfpv_blast_on_impact")
        local current = (cvImpact and cvImpact:GetFloat() or 0) ~= 0 and 1 or 0
        combo:SetValue(current == 1 and "Удар + ЛКМ" or "Только ЛКМ (удары безвредны)")
        combo.OnSelect = function(_, _, _, data)
            ZFPV.SendSetting("zfpv_blast_on_impact", data)
        end
        panel:AddItem(combo)

        toolToggle(panel, "zfpv_blast_on_damage", "Взрывать, когда дрон сбили", "0 = просто исчезает")
        toolToggle(panel, "zfpv_blast_on_lost", "Взрывать, когда пилот потерян", "0 = просто исчезает через таймер")

        panel:Help("ПОЛЁТ")
        toolSlider(panel, "zfpv_speed", "Скорость", 150, 3000, 0)
        toolSlider(panel, "zfpv_boost", "Ускорение (Shift), x", 1, 4, 1)
        toolSlider(panel, "zfpv_health", "Прочность", 1, 200, 0)
        toolSlider(panel, "zfpv_fuse", "Исчезновение без пилота, сек", 3, 120, 0)
        toolSlider(panel, "zfpv_cooldown", "Задержка запуска, сек", 0, 60, 0)
        toolSlider(panel, "zfpv_freeze_time", "«Нет сигнала», сек", 0, 6, 1)

        panel:Help("ВЗРЫВ (Z-City)")
        toolSlider(panel, "zfpv_blast_radius", "Радиус, м", 1, 40, 0)
        toolSlider(panel, "zfpv_blast_damage", "Blast-урон", 0, 500, 0)
        toolSlider(panel, "zfpv_blast_frag", "Осколков", 0, 2000, 0)
        toolSlider(panel, "zfpv_blast_frag_damage", "Урон осколка", 1, 200, 0)
        toolSlider(panel, "zfpv_blast_frag_pen", "Пробитие осколка", 0, 50, 0)

        panel:Help("ПРОЧЕЕ")
        toolToggle(panel, "zfpv_admin_only", "Пульт только для админов")
        panel:Button("Открыть полное меню", "zfpv_menu")
        panel:Button("Дать себе пульт", "zfpv_give")
    end)
end)
