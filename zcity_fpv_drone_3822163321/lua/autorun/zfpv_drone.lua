AddCSLuaFile()

ZFPV = ZFPV or {}

-- =====================================================================
--  Серверные настройки (реплицируются клиентам, меняются админами из меню)
-- =====================================================================
ZFPV.ServerSettings = {
    { type = "header", text = "ПОЛЁТ" },
    { type = "slider", cvar = "zfpv_speed", label = "Скорость дрона", desc = "Базовая скорость полёта",
      min = 150, max = 3000, dec = 0, default = 450 },
    { type = "slider", cvar = "zfpv_boost", label = "Ускорение (Shift)", desc = "Во сколько раз быстрее с зажатым Shift",
      min = 1, max = 4, dec = 1, default = 1.5, unit = "x" },

    { type = "header", text = "ВЗРЫВ И ПРОЧНОСТЬ" },
    { type = "slider", cvar = "zfpv_damage", label = "Урон взрыва", desc = "Сколько урона наносит взрыв",
      min = 10, max = 2000, dec = 0, default = 250 },
    { type = "slider", cvar = "zfpv_radius", label = "Радиус взрыва", desc = "Дальность поражения, юниты",
      min = 50, max = 1500, dec = 0, default = 300 },
    { type = "toggle", cvar = "zfpv_blast_on_impact", label = "Взрыв при ударе", desc = "1 = дрон взрывается, влетев в препятствие (по умолчанию 0 — только ЛКМ)",
      default = 0 },
    { type = "toggle", cvar = "zfpv_blast_on_damage", label = "Взрыв, когда сбили", desc = "1 = дрон взрывается, когда его расстреляли (0 = просто исчезает)",
      default = 0 },
    { type = "toggle", cvar = "zfpv_blast_on_lost", label = "Взрыв при потере пилота", desc = "1 = взрывается, когда пилот умер/вышел (0 = просто исчезает)",
      default = 0 },
    { type = "slider", cvar = "zfpv_min_impact_speed", label = "Скорость удара для взрыва", desc = "Работает только если включён «Взрыв при ударе»",
      min = 0, max = 600, dec = 0, default = 120 },
    { type = "slider", cvar = "zfpv_health", label = "Прочность дрона", desc = "Сколько урона выдержит до того, как пропадёт",
      min = 1, max = 200, dec = 0, default = 30 },
    { type = "slider", cvar = "zfpv_fuse", label = "Таймер потерянного дрона", desc = "Через сколько секунд дрон исчезнет без пилота",
      min = 3, max = 120, dec = 0, default = 20, unit = " с" },
    { type = "slider", cvar = "zfpv_freeze_time", label = "Заморозка кадра после взрыва", desc = "Сколько секунд пилот видит «нет сигнала» (0 = выключено)",
      min = 0, max = 6, dec = 1, default = 2.5, unit = " с" },

    { type = "header", text = "ДОСТУП" },
    { type = "slider", cvar = "zfpv_cooldown", label = "Задержка между запусками", desc = "Пауза после потери дрона",
      min = 0, max = 60, dec = 0, default = 1, unit = " с" },
    { type = "toggle", cvar = "zfpv_admin_only", label = "Пульт только для админов", desc = "Остальные игроки не смогут запускать дроны",
      default = 0 },
}

ZFPV.ServerLookup = {}
for _, def in ipairs(ZFPV.ServerSettings) do
    if def.cvar then
        ZFPV.ServerLookup[def.cvar] = def
        if def.type == "toggle" then def.min, def.max = 0, 1 end
        CreateConVar(def.cvar, tostring(def.default), bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED), def.desc)
    end
end

-- одноразовая миграция: старые сохранённые 800/1.8 меняем на новые 450/1.5
if SERVER then
    if not ConVarExists("zfpv_cfg_version") then
        CreateConVar("zfpv_cfg_version", "0", FCVAR_ARCHIVE, "Внутренняя версия настроек FPV")
    end

    timer.Simple(0, function()
        local ver = GetConVar("zfpv_cfg_version")
        if not ver or ver:GetFloat() >= 2 then return end

        local sp = GetConVar("zfpv_speed")
        local bo = GetConVar("zfpv_boost")
        if sp and sp:GetFloat() == 800 then sp:SetFloat(450) end
        if bo and bo:GetFloat() == 1.8 then bo:SetFloat(1.5) end

        ver:SetFloat(2)
    end)
end

ZFPV.Presets = {
    { name = "Аркада", values = {
        zfpv_speed = 450, zfpv_boost = 1.5, zfpv_damage = 250, zfpv_radius = 300,
        zfpv_min_impact_speed = 120, zfpv_health = 30, zfpv_fuse = 20 } },
    { name = "Реализм", values = {
        zfpv_speed = 380, zfpv_boost = 1.35, zfpv_damage = 140, zfpv_radius = 200,
        zfpv_min_impact_speed = 150, zfpv_health = 12, zfpv_fuse = 10 } },
    { name = "Хаос", values = {
        zfpv_speed = 750, zfpv_boost = 2.0, zfpv_damage = 600, zfpv_radius = 700,
        zfpv_min_impact_speed = 60, zfpv_health = 60, zfpv_fuse = 30 } },
}

-- =====================================================================
--  Клиентские настройки (у каждого игрока свои)
-- =====================================================================
ZFPV.ClientSettings = {
    { type = "header", text = "КАМЕРА" },
    { type = "slider", cvar = "zfpv_cl_fov", label = "Угол обзора (FOV)", desc = "Чем больше, тем шире картинка",
      min = 70, max = 130, dec = 0, default = 105, unit = "°" },
    { type = "slider", cvar = "zfpv_cl_roll", label = "Наклон камеры", desc = "Насколько камера кренится при боковом движении",
      min = 0, max = 1.5, dec = 1, default = 1, unit = "x" },

    { type = "header", text = "ИНТЕРФЕЙС" },
    { type = "toggle", cvar = "zfpv_cl_hud", label = "Телеметрия (HUD)", desc = "Скорость, высота, дистанция, таймер", default = 1 },
    { type = "toggle", cvar = "zfpv_cl_hints", label = "Подсказки по управлению", desc = "Строка с клавишами внизу экрана", default = 1 },
    { type = "toggle", cvar = "zfpv_cl_noise", label = "Помехи на экране", desc = "Эффект аналогового видеосигнала", default = 1 },
    { type = "toggle", cvar = "zfpv_cl_freeze", label = "Заморозка кадра при взрыве", desc = "Эффект «нет сигнала» после потери дрона (чуть грузит видеокарту)", default = 1 },
    { type = "colors", cvar = "zfpv_cl_hud_color", label = "Цвет HUD", desc = "Цвет телеметрии и прицела", default = "120 255 120" },
}

-- =====================================================================
--  Сеть: админские настройки и действия
-- =====================================================================
if SERVER then
    util.AddNetworkString("ZFPV_SetCvar")
    util.AddNetworkString("ZFPV_Action")
    util.AddNetworkString("ZFPV_SignalLost")

    net.Receive("ZFPV_SetCvar", function(_, ply)
        if not IsValid(ply) or not ply:IsAdmin() then return end

        local name = net.ReadString()
        local val  = net.ReadFloat()
        local def  = ZFPV.ServerLookup[name]
        if not def then return end

        local cv = GetConVar(name)
        if cv then cv:SetFloat(math.Clamp(val, def.min, def.max)) end
    end)

    net.Receive("ZFPV_Action", function(_, ply)
        if not IsValid(ply) or not ply:IsAdmin() then return end

        local action = net.ReadString()

        if action == "reset" then
            for name, def in pairs(ZFPV.ServerLookup) do
                local cv = GetConVar(name)
                if cv then cv:SetFloat(def.default) end
            end
            ply:ChatPrint("[FPV-ZC] Серверные настройки сброшены по умолчанию.")

        elseif action == "clear" then
            local count = 0
            for _, e in ipairs(ents.FindByClass("zcity_fpv_drone")) do
                e:Remove()
                count = count + 1
            end
            ply:ChatPrint("[FPV-ZC] Удалено дронов: " .. count)
        end
    end)
end

-- =====================================================================
--  Ввод пилота (сервер + клиент)
-- =====================================================================
hook.Add("StartCommand", "ZFPV_Cmd", function(ply, cmd)
    local drone = ply:GetNWEntity("ZFPVDrone")
    if not IsValid(drone) then return end

    if SERVER then
        ply.ZFPVInput = {
            f     = (cmd:KeyDown(IN_FORWARD) and 1 or 0) - (cmd:KeyDown(IN_BACK) and 1 or 0),
            s     = (cmd:KeyDown(IN_MOVERIGHT) and 1 or 0) - (cmd:KeyDown(IN_MOVELEFT) and 1 or 0),
            u     = (cmd:KeyDown(IN_JUMP) and 1 or 0) - (cmd:KeyDown(IN_DUCK) and 1 or 0),
            boost = cmd:KeyDown(IN_SPEED),
            ang   = cmd:GetViewAngles(),
        }

        -- ЛКМ — взрыв (только по новому нажатию, после того как кнопку отпустили)
        if cmd:KeyDown(IN_ATTACK) then
            if ply.ZFPVCanDet then drone.WantExplode = true end
        else
            ply.ZFPVCanDet = true
        end

        -- R — вернуть дрон без взрыва
        if cmd:KeyDown(IN_RELOAD) then drone.WantRecall = true end
    end

    -- Тело пилота стоит на месте.
    -- Кнопки здесь НЕ вырезаем: иначе сервер их не получит.
    cmd:ClearMovement()
end)

-- Прыжок и приседание не двигают тело пилота, но дрон их по-прежнему видит
hook.Add("SetupMove", "ZFPV_Move", function(ply, mv, cmd)
    if not IsValid(ply:GetNWEntity("ZFPVDrone")) then return end
    mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(bit.bor(IN_JUMP, IN_DUCK))))
end)

-- Во время полёта нельзя сменить оружие
hook.Add("PlayerSwitchWeapon", "ZFPV_NoSwitch", function(ply, oldWep, newWep)
    if IsValid(ply:GetNWEntity("ZFPVDrone")) then return true end
end)

-- =====================================================================
--  Камера и HUD (клиент)
-- =====================================================================
if CLIENT then
    -- Клиентские консольные переменные
    local cvars = {}
    for _, def in ipairs(ZFPV.ClientSettings) do
        if def.cvar then
            cvars[def.cvar] = CreateClientConVar(def.cvar, tostring(def.default), true, false)
        end
    end

    -- Отправка настроек и действий на сервер (используется меню)
    function ZFPV.SendSetting(name, value)
        net.Start("ZFPV_SetCvar")
        net.WriteString(name)
        net.WriteFloat(value)
        net.SendToServer()
    end

    function ZFPV.SendAction(action)
        net.Start("ZFPV_Action")
        net.WriteString(action)
        net.SendToServer()
    end

    surface.CreateFont("ZFPV_HUD", {
        font = "Courier New",
        size = math.max(16, math.floor(ScrH() * 0.022)),
        weight = 700,
    })

    local function GetDrone()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        local d = ply:GetNWEntity("ZFPVDrone")
        if IsValid(d) then return d end
    end

    local hudColStr, hudCol = "", Color(120, 255, 120, 230)
    local function GetHudColor()
        local s = cvars["zfpv_cl_hud_color"]:GetString()
        if s ~= hudColStr then
            hudColStr = s
            local r, g, b = string.match(s, "(%d+)%s+(%d+)%s+(%d+)")
            hudCol = Color(tonumber(r) or 120, tonumber(g) or 255, tonumber(b) or 120, 230)
        end
        return hudCol
    end

    -- Камера в "носу" дрона
    hook.Add("CalcView", "ZFPV_View", function(ply, origin, angles, fov)
        local d = GetDrone()
        if not d then return end

        local ea = ply:EyeAngles()
        return {
            origin = d:GetPos() + ea:Forward() * 20,
            angles = Angle(ea.p, ea.y, d:GetAngles().r * cvars["zfpv_cl_roll"]:GetFloat()),
            fov = cvars["zfpv_cl_fov"]:GetFloat(),
            drawviewer = false,
        }
    end)

    hook.Add("PreDrawViewModel", "ZFPV_HideVM", function()
        if GetDrone() then return true end
    end)

    hook.Add("HUDShouldDraw", "ZFPV_HideCrosshair", function(name)
        if name == "CHudCrosshair" and GetDrone() then return false end
    end)

    local lastPos, lastT, speedMS, startT = nil, 0, 0, 0

    hook.Add("HUDPaint", "ZFPV_HUD", function()
        local d = GetDrone()
        if not d then lastPos = nil startT = 0 return end

        local ply = LocalPlayer()
        local sw, sh = ScrW(), ScrH()
        local now = CurTime()
        local pos = d:GetPos()
        if startT == 0 then startT = now end

        -- Помехи аналогового видео
        if cvars["zfpv_cl_noise"]:GetBool() then
            surface.SetDrawColor(255, 255, 255, 14)
            for _ = 1, 3 do
                surface.DrawRect(0, math.random(0, sh), sw, 1)
            end
        end

        if not cvars["zfpv_cl_hud"]:GetBool() then return end

        -- Скорость по смещению позиции (1 юнит ~ 0.01905 м)
        if lastPos and now > lastT then
            local inst = (pos - lastPos):Length() / (now - lastT) * 0.01905
            speedMS = Lerp(0.2, speedMS, inst)
        end
        lastPos, lastT = pos, now

        local tr = util.TraceLine({ start = pos, endpos = pos - Vector(0, 0, 5000), mask = MASK_SOLID_BRUSHONLY })
        local alt = tr.Hit and (tr.Fraction * 5000 * 0.01905) or 0
        local dist = (pos - ply:GetPos()):Length() * 0.01905

        local col = Color(255, 255, 255, 230)
        local green = GetHudColor()

        -- Прицел
        local cx, cy = sw / 2, sh / 2
        surface.SetDrawColor(green)
        surface.DrawLine(cx - 14, cy, cx - 5, cy)
        surface.DrawLine(cx + 5, cy, cx + 14, cy)
        surface.DrawLine(cx, cy - 14, cx, cy - 5)
        surface.DrawLine(cx, cy + 5, cx, cy + 14)

        -- Телеметрия
        local x, y, step = sw * 0.04, sh * 0.80, sh * 0.03
        draw.SimpleText(string.format("СКОРОСТЬ %3d км/ч", speedMS * 3.6), "ZFPV_HUD", x, y, green)
        draw.SimpleText(string.format("ВЫСОТА   %3d м", alt), "ZFPV_HUD", x, y + step, green)
        draw.SimpleText(string.format("ДИСТАНЦИЯ %3d м", dist), "ZFPV_HUD", x, y + step * 2, green)

        -- REC и время полёта
        local t = now - startT
        if math.floor(now * 2) % 2 == 0 then
            draw.SimpleText("● REC", "ZFPV_HUD", sw * 0.04, sh * 0.05, Color(255, 50, 50))
        end
        draw.SimpleText(string.format("%02d:%02d", t / 60, t % 60), "ZFPV_HUD", sw * 0.04, sh * 0.05 + step, col)

        -- Подсказка
        if cvars["zfpv_cl_hints"]:GetBool() then
            draw.SimpleText("ЛКМ — взрыв  |  R — вернуть  |  Shift — ускорение  |  Пробел/Ctrl — вверх/вниз",
                "ZFPV_HUD", sw / 2, sh * 0.95, col, TEXT_ALIGN_CENTER)
        end
    end)

    -- =================================================================
    --  Потеря сигнала: экран замирает на последнем кадре
    -- =================================================================
    surface.CreateFont("ZFPV_Big", {
        font = "Courier New",
        size = math.max(32, math.floor(ScrH() * 0.07)),
        weight = 900,
    })

    local ringRT, ringMat, ringIdx, captured = {}, {}, 0, 0
    local freeze = nil

    local function EnsureRing()
        if ringRT[1] then return end
        local tag = ScrW() .. "x" .. ScrH()
        for i = 1, 3 do
            ringRT[i] = GetRenderTarget("ZFPV_Freeze" .. i .. "_" .. tag, ScrW(), ScrH())
            ringMat[i] = CreateMaterial("ZFPV_FreezeMat" .. i .. "_" .. tag, "UnlitGeneric", {
                ["$basetexture"] = ringRT[i]:GetName(),
                ["$ignorez"] = 1,
                ["$nolod"] = 1,
            })
        end
    end

    -- Пока летим, держим в памяти 3 последних кадра сцены (без HUD)
    hook.Add("PostDrawTranslucentRenderables", "ZFPV_Capture", function(bDepth, bSky)
        if bDepth or bSky or freeze then return end
        if render.GetRenderTarget() then return end
        if not cvars["zfpv_cl_freeze"]:GetBool() or not GetDrone() then return end

        EnsureRing()
        ringIdx = (ringIdx % 3) + 1
        render.CopyRenderTargetToTexture(ringRT[ringIdx])
        captured = math.min(captured + 1, 3)
    end)

    -- Сервер сообщает: дрон взорвался
    net.Receive("ZFPV_SignalLost", function()
        local dur = net.ReadFloat()
        if dur <= 0 or captured == 0 or not cvars["zfpv_cl_freeze"]:GetBool() then return end

        -- Берём самый старый из 3 кадров: это момент прямо перед взрывом
        local idx = (captured >= 3) and ((ringIdx % 3) + 1) or ringIdx
        if not ringMat[idx] then return end

        freeze = { start = CurTime(), dur = dur, mat = ringMat[idx] }
        captured = 0
        surface.PlaySound("ambient/energy/spark2.wav")
    end)

    local function GlitchText(text, font, x, y, main)
        local shake = math.random(-2, 2)
        draw.SimpleText(text, font, x - 4 + shake, y, Color(255, 40, 40, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(text, font, x + 4 + shake, y, Color(40, 220, 255, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(text, font, x + shake, y, main, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    hook.Add("PostDrawHUD", "ZFPV_Freeze", function()
        if not freeze then return end

        local ply = LocalPlayer()
        local t = CurTime() - freeze.start
        if t >= freeze.dur or not IsValid(ply) or not ply:Alive() then
            freeze = nil
            return
        end

        local sw, sh = ScrW(), ScrH()
        local p = t / freeze.dur
        local intensity = math.Clamp(0.15 + p * 1.2, 0, 1) -- помехи нарастают

        -- Последний кадр
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(freeze.mat)
        surface.DrawTexturedRect(0, 0, sw, sh)

        -- Рваные горизонтальные полосы (сбой видеосигнала)
        for _ = 1, math.floor(2 + intensity * 9) do
            local y = math.random(0, sh - 60)
            local hh = math.random(8, 56)
            local off = math.random(-70, 70) * intensity
            surface.DrawTexturedRectUV(off, y, sw, hh, 0, y / sh, 1, (y + hh) / sh)
        end

        -- Затемнение растёт со временем
        surface.SetDrawColor(0, 0, 0, 40 + 120 * p)
        surface.DrawRect(0, 0, sw, sh)

        -- Строки развёртки
        surface.SetDrawColor(0, 0, 0, 55)
        for y = 0, sh, 4 do surface.DrawRect(0, y, sw, 1) end

        -- Статический шум
        for _ = 1, math.floor(200 + 900 * intensity) do
            local g = math.random(120, 255)
            surface.SetDrawColor(g, g, g, math.random(30, 110) * intensity)
            surface.DrawRect(math.random(0, sw), math.random(0, sh), math.random(2, 10), math.random(1, 3))
        end

        -- Надпись
        if t > 0.2 and math.floor(t * 4) % 4 ~= 3 then
            GlitchText("НЕТ СИГНАЛА", "ZFPV_Big", sw / 2, sh * 0.46, Color(255, 255, 255, 240))
            draw.SimpleText("СВЯЗЬ С ДРОНОМ ПОТЕРЯНА", "ZFPV_HUD", sw / 2, sh * 0.46 + sh * 0.07,
                Color(255, 90, 90, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Плавное затухание в чёрное в конце
        local left = freeze.dur - t
        if left < 0.4 then
            surface.SetDrawColor(0, 0, 0, 255 * (1 - left / 0.4))
            surface.DrawRect(0, 0, sw, sh)
        end
    end)
end
