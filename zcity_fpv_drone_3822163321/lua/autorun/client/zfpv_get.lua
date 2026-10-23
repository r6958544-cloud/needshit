--[[ Z-City FPV Drone — меню выдачи пульта (zfpv_get) ]]

if not CLIENT then return end

local frame

concommand.Add("zfpv_get", function()
	if IsValid(frame) then
		frame:Remove()
		frame = nil
		return
	end

	frame = vgui.Create("DFrame")
	frame:SetSize(390, 200)
	frame:Center()
	frame:SetTitle("Z-City FPV")
	frame:MakePopup()

	local info = vgui.Create("DLabel", frame)
	info:Dock(TOP)
	info:DockMargin(10, 10, 10, 0)
	info:SetTall(70)
	info:SetWrap(true)
	info:SetText("Пульт FPV — это оружие (категория «Z-City FPV»).\nЕсли его нет в спавн-меню — забери кнопкой ниже.\nЛКМ — запуск дрона, ЛКМ в полёте — взрыв, R — вернуть.")

	local btn = vgui.Create("DButton", frame)
	btn:Dock(BOTTOM)
	btn:DockMargin(10, 10, 10, 10)
	btn:SetTall(44)
	btn:SetText("Получить FPV пульт")
	btn.DoClick = function()
		net.Start("ZFPV_GiveController")
		net.SendToServer()
		frame:Remove()
		frame = nil
	end
end)
