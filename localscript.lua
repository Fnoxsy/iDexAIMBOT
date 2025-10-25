--======= НАСТРОЙКИ =======--
local mousebind = Enum.UserInputType.MouseButton3
local keybind = Enum.KeyCode.Q
local toggleMenuKey = Enum.KeyCode.L
local toggleFlyKey = Enum.KeyCode.F
local switch = "мышка" -- "мышка" или "клава"

--======= СЕРВИСЫ =======--
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--======= ПЕРЕМЕННЫЕ =======--
local aimEnabled = false
local flyEnabled = false
local lockedPlayer = nil
local targetPart = "Head"
local autoTarget = true
local guiOpen = false
local waitingForAimbotBind = false
local waitingForMenuBind = false
local waitingForFlyBind = false
local connections = {}
local currentHighlight = nil

local flyConnection
local flyBodyVel
local flyBodyGyro

--======= ФУНКЦИИ =======--
-- ближайший к прицелу игрок
local function getClosestPlayer()
	local closestPlayer = nil
	local smallestAngle = math.huge
	local cameraPos = Camera.CFrame.Position
	local cameraDir = Camera.CFrame.LookVector

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(targetPart) then
			local part = player.Character[targetPart]
			local direction = (part.Position - cameraPos).Unit
			local angle = math.acos(math.clamp(cameraDir:Dot(direction), -1, 1))
			if angle < smallestAngle then
				smallestAngle = angle
				closestPlayer = player
			end
		end
	end
	return closestPlayer
end

-- подсветка цели
local function applyHighlight(player)
	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end
	if player and player.Character then
		local hl = Instance.new("Highlight")
		hl.Name = "AimbotHighlight"
		hl.FillColor = Color3.fromRGB(255, 0, 0)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = player.Character
		currentHighlight = hl
	end
end

local function removeHighlight()
	if currentHighlight then
		currentHighlight:Destroy()
		currentHighlight = nil
	end
end

local function aimAtTarget()
	if not aimEnabled then
		removeHighlight()
		return
	end

	if autoTarget then
		local newTarget = getClosestPlayer()
		if newTarget ~= lockedPlayer then
			lockedPlayer = newTarget
			applyHighlight(lockedPlayer)
		end
	else
		if lockedPlayer and (not currentHighlight or not currentHighlight.Parent) then
			applyHighlight(lockedPlayer)
		end
	end

	if lockedPlayer and lockedPlayer.Character and lockedPlayer.Character:FindFirstChild(targetPart) then
		Camera.CFrame = CFrame.new(Camera.CFrame.Position, lockedPlayer.Character[targetPart].Position)
	end
end

--======= UI =======--
local statusLabel, toggleButton, toggleFlyButton, partButton, frame
local aimbotBindButton, menuBindButton, flyBindButton
local widgetStatus, widgetTarget, hud

local function updateStatus()
	if statusLabel and toggleButton then
		if aimEnabled then
			statusLabel.Text = "Статус Aimbot: Включен"
			statusLabel.TextColor3 = Color3.fromRGB(0,255,0)
			toggleButton.Text = "Выключить Aimbot"
		else
			statusLabel.Text = "Статус Aimbot: Выключен"
			statusLabel.TextColor3 = Color3.fromRGB(255,0,0)
			toggleButton.Text = "Включить Aimbot"
		end
	end

	if widgetStatus then
		widgetStatus.Text = "Aimbot: " .. (aimEnabled and "ВКЛ" or "ВЫКЛ")
		widgetStatus.TextColor3 = aimEnabled and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,0,0)
	end

	if toggleFlyButton then
		if flyEnabled then
			toggleFlyButton.Text = "Выключить Fly"
		else
			toggleFlyButton.Text = "Включить Fly"
		end
	end

	if widgetTarget then
		if autoTarget then
			widgetTarget.Text = "Цель: Ближайший"
		else
			widgetTarget.Text = "Цель: " .. (lockedPlayer and lockedPlayer.Name or "нет")
		end
	end
end

local function toggleFly(enabled, speed)
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if enabled then
		if humanoid then
			humanoid.PlatformStand = true
		end

		-- создаём силы для полёта
		flyBodyVel = Instance.new("BodyVelocity")
		flyBodyVel.MaxForce = Vector3.new(400000, 400000, 400000)
		flyBodyVel.Velocity = Vector3.zero
		flyBodyVel.P = 9e4
		flyBodyVel.Parent = hrp

		flyBodyGyro = Instance.new("BodyGyro")
		flyBodyGyro.MaxTorque = Vector3.new(400000, 400000, 400000)
		flyBodyGyro.P = 9e4
		flyBodyGyro.CFrame = hrp.CFrame
		flyBodyGyro.Parent = hrp

		-- подключаем управление
		flyConnection = RunService.Heartbeat:Connect(function(dt)
			local move = Vector3.zero
			local cam = workspace.CurrentCamera

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				move = move + cam.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				move = move - cam.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				move = move - cam.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				move = move + cam.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				move = move + Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				move = move - Vector3.new(0, 1, 0)
			end

			if move.Magnitude > 0 then
				move = move.Unit * speed
			end

			flyBodyVel.Velocity = move
			flyBodyGyro.CFrame = cam.CFrame
		end)
	else
		-- отключаем полёт
		if flyConnection then
			flyConnection:Disconnect()
			flyConnection = nil
		end
		if flyBodyVel then
			flyBodyVel:Destroy()
			flyBodyVel = nil
		end
		if flyBodyGyro then
			flyBodyGyro:Destroy()
			flyBodyGyro = nil
		end
		if humanoid then
			humanoid.PlatformStand = false
		end
	end
end

local function createWidget()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	hud = Instance.new("ScreenGui", playerGui)
	hud.Name = "AimWidget"
	hud.ResetOnSpawn = false
	hud.IgnoreGuiInset = true

	local frame = Instance.new("Frame", hud)
	frame.Size = UDim2.new(0, 190, 0, 60)
	frame.Position = UDim2.new(1, -200, 0, 20)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	Instance.new("UICorner", frame)

	widgetStatus = Instance.new("TextLabel", frame)
	widgetStatus.Size = UDim2.new(0.939, 0, 0.5, 0)
	widgetStatus.BackgroundTransparency = 1
	widgetStatus.Font = Enum.Font.Nunito
	widgetStatus.TextScaled = true
	widgetStatus.TextColor3 = Color3.fromRGB(255, 0, 0)
	widgetStatus.Text = "Aimbot: ВЫКЛ"
	widgetStatus.TextXAlignment = Enum.TextXAlignment.Right

	widgetTarget = Instance.new("TextLabel", frame)
	widgetTarget.Size = UDim2.new(0.939, 0, 0.5, 0)
	widgetTarget.Position = UDim2.new(0, 0, 0.5, 0)
	widgetTarget.BackgroundTransparency = 1
	widgetTarget.Font = Enum.Font.Nunito
	widgetTarget.TextScaled = true
	widgetTarget.TextColor3 = Color3.fromRGB(200, 200, 200)
	widgetTarget.Text = "Цель: Ближайший"
	widgetTarget.TextXAlignment = Enum.TextXAlignment.Right
	
	local frame2 = Instance.new("Frame", frame)
	frame2.Size = UDim2.new(0.03, 0, 1, 0)
	frame2.Position = UDim2.new(0.97, 0, 0, 0)
	frame2.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
	
	local textSize = Instance.new("UITextSizeConstraint", widgetStatus)
	textSize.MaxTextSize = 25
end

--======= УДАЛЕНИЕ =======--
local function unloadScript()
	aimEnabled = false
	removeHighlight()
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	connections = {}
	if hud then hud:Destroy() end
	if frame then frame.Parent:Destroy() end
end

--======= МЕНЮ =======--
local function createMenu()
	local gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
	gui.Name = "AimbotMenu"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	frame = Instance.new("Frame", gui)
	frame.Size = UDim2.new(0, 440, 0, 340)
	frame.Position = UDim2.new(0.5, -220, 1.5, 0)
	frame.Visible = false
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	frame.BorderSizePixel = 0
	Instance.new("UICorner", frame)

	local title = Instance.new("TextLabel", frame)
	title.Text = "iDex cheats"
	title.Size = UDim2.new(1, 0, 0.15, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 255, 255)

	statusLabel = Instance.new("TextLabel", frame)
	statusLabel.Position = UDim2.new(0.05, 0, 0.16, 0)
	statusLabel.Size = UDim2.new(0.9, 0, 0.1, 0)
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextScaled = true
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
	statusLabel.Text = "Статус Aimbot: Выключен"

	toggleButton = Instance.new("TextButton", frame)
	toggleButton.Position = UDim2.new(0.05, 0,0.28, 0)
	toggleButton.Size = UDim2.new(0.273, 0,0.12, 0)
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
	toggleButton.TextColor3 = Color3.new(1,1,1)
	toggleButton.TextScaled = true
	toggleButton.Font = Enum.Font.GothamBold
	toggleButton.Text = "Включить Aimbot"
	Instance.new("UICorner", toggleButton)
	toggleButton.UICorner.CornerRadius = UDim.new(1, 0)

	toggleFlyButton = Instance.new("TextButton", frame)
	toggleFlyButton.Position = UDim2.new(0.675, 0,0.28, 0)
	toggleFlyButton.Size = UDim2.new(0.273, 0,0.12, 0)
	toggleFlyButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
	toggleFlyButton.TextColor3 = Color3.new(1,1,1)
	toggleFlyButton.TextScaled = true
	toggleFlyButton.Font = Enum.Font.GothamBold
	toggleFlyButton.Text = "Включить Fly"
	Instance.new("UICorner", toggleFlyButton)
	toggleFlyButton.UICorner.CornerRadius = UDim.new(1, 0)

	partButton = Instance.new("TextButton", frame)
	partButton.Position = UDim2.new(0.348, 0,0.28, 0)
	partButton.Size = UDim2.new(0.302, 0,0.12, 0)
	partButton.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	partButton.TextColor3 = Color3.new(1,1,1)
	partButton.TextScaled = true
	partButton.Font = Enum.Font.Gotham
	partButton.Text = "Цель: " .. targetPart
	Instance.new("UICorner", partButton)
	partButton.UICorner.CornerRadius = UDim.new(1, 0)

	local playerListFrame = Instance.new("ScrollingFrame", frame)
	playerListFrame.Position = UDim2.new(0.05, 0, 0.43, 0)
	playerListFrame.Size = UDim2.new(0.9, 0, 0.35, 0)
	playerListFrame.ScrollBarThickness = 6
	playerListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	playerListFrame.BorderSizePixel = 0
	Instance.new("UICorner", playerListFrame)

	local layout = Instance.new("UIListLayout", playerListFrame)
	layout.Padding = UDim.new(0, 4)

	local function refreshPlayerList()
		for _, child in ipairs(playerListFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end

		local autoBtn = Instance.new("TextButton", playerListFrame)
		autoBtn.Size = UDim2.new(1, -4, 0, 26)
		autoBtn.BackgroundColor3 = Color3.fromRGB(70, 100, 255)
		autoBtn.TextColor3 = Color3.new(1,1,1)
		autoBtn.Font = Enum.Font.GothamBold
		autoBtn.TextSize = 16
		autoBtn.Text = "🔄 Авто (ближайший игрок)"
		Instance.new("UICorner", autoBtn)
		autoBtn.UICorner.CornerRadius = UDim.new(1, 0)
		autoBtn.MouseButton1Click:Connect(function()
			autoTarget = true
			removeHighlight()
			lockedPlayer = nil
			statusLabel.Text = "Таргет: Ближайший игрок"
			statusLabel.TextColor3 = Color3.fromRGB(0,255,0)
			updateStatus()
		end)

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local btn = Instance.new("TextButton", playerListFrame)
				btn.Size = UDim2.new(1, -4, 0, 26)
				btn.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
				btn.TextColor3 = Color3.new(1,1,1)
				btn.Font = Enum.Font.Gotham
				btn.TextSize = 16
				btn.Text = plr.Name
				Instance.new("UICorner", btn)
				btn.UICorner.CornerRadius = UDim.new(1, 0)
				btn.MouseButton1Click:Connect(function()
					autoTarget = false
					lockedPlayer = plr
					applyHighlight(plr)
					statusLabel.Text = "Таргет: " .. plr.Name
					statusLabel.TextColor3 = Color3.fromRGB(0,255,255)
					updateStatus()
				end)
			end
		end
	end
	refreshPlayerList()
	Players.PlayerAdded:Connect(refreshPlayerList)
	Players.PlayerRemoving:Connect(refreshPlayerList)

	-- бинды + unload
	local bindsTitle = Instance.new("TextLabel", frame)
	bindsTitle.Position = UDim2.new(0, 0, 0.8, 0)
	bindsTitle.Size = UDim2.new(0.223, 0,0.1, 0)
	bindsTitle.BackgroundTransparency = 1
	bindsTitle.Font = Enum.Font.GothamBold
	bindsTitle.TextScaled = true
	bindsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	bindsTitle.Text = "Бинды:"

	aimbotBindButton = Instance.new("TextButton", frame)
	aimbotBindButton.Position = UDim2.new(0.241, 0,0.8, 0)
	aimbotBindButton.Size = UDim2.new(0.282, 0,0.1, 0)
	aimbotBindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	aimbotBindButton.TextColor3 = Color3.new(1,1,1)
	aimbotBindButton.TextScaled = true
	aimbotBindButton.Font = Enum.Font.Gotham
	aimbotBindButton.Text = "Aimbot: " .. (switch == "мышка" and mousebind.Name or keybind.Name)
	Instance.new("UICorner", aimbotBindButton)
	aimbotBindButton.UICorner.CornerRadius = UDim.new(1, 0)

	menuBindButton = Instance.new("TextButton", frame)
	menuBindButton.Position = UDim2.new(0.523, 0,0.8, 0)
	menuBindButton.Size = UDim2.new(0.257, 0,0.1, 0)
	menuBindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	menuBindButton.TextColor3 = Color3.new(1,1,1)
	menuBindButton.TextScaled = true
	menuBindButton.Font = Enum.Font.Gotham
	menuBindButton.Text = "Меню: " .. toggleMenuKey.Name
	Instance.new("UICorner", menuBindButton)
	menuBindButton.UICorner.CornerRadius = UDim.new(1, 0)

	flyBindButton = Instance.new("TextButton", frame)
	flyBindButton.Position = UDim2.new(0.796, 0,0.8, 0)
	flyBindButton.Size = UDim2.new(0.204, 0,0.1, 0)
	flyBindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	flyBindButton.TextColor3 = Color3.new(1,1,1)
	flyBindButton.TextScaled = true
	flyBindButton.Font = Enum.Font.Gotham
	flyBindButton.Text = "Fly: " .. toggleFlyKey.Name
	Instance.new("UICorner", flyBindButton)
	flyBindButton.UICorner.CornerRadius = UDim.new(1, 0)

	local unload = Instance.new("TextButton", frame)
	unload.Position = UDim2.new(0.05, 0, 0.93, 0)
	unload.Size = UDim2.new(0.9, 0, 0.07, 0)
	unload.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	unload.TextColor3 = Color3.new(1,1,1)
	unload.TextScaled = true
	unload.Font = Enum.Font.GothamBold
	unload.Text = "UNLOAD (выгрузить)"
	Instance.new("UICorner", unload)
	unload.UICorner.CornerRadius = UDim.new(1, 0)
	unload.MouseButton1Click:Connect(unloadScript)

	-- кнопки
	toggleButton.MouseButton1Click:Connect(function()
		aimEnabled = not aimEnabled
		if aimEnabled then
			if autoTarget then
				lockedPlayer = getClosestPlayer()
			end
			applyHighlight(lockedPlayer)
		else
			removeHighlight()
		end
		updateStatus()
	end)
	
	toggleFlyButton.MouseButton1Click:Connect(function()
		flyEnabled = not flyEnabled
		if flyEnabled then
			toggleFly(false)
		else
			toggleFly(true, 60)
		end
		updateStatus()
	end)

	partButton.MouseButton1Click:Connect(function()
		targetPart = (targetPart == "Head") and "HumanoidRootPart" or "Head"
		partButton.Text = "Цель: " .. targetPart
	end)

	aimbotBindButton.MouseButton1Click:Connect(function()
		waitingForAimbotBind = true
		aimbotBindButton.Text = "Нажмите клавишу..."
	end)

	menuBindButton.MouseButton1Click:Connect(function()
		waitingForMenuBind = true
		menuBindButton.Text = "Нажмите клавишу..."
	end)
	flyBindButton.MouseButton1Click:Connect(function()
		waitingForFlyBind = true
		flyBindButton.Text = "Нажмите клавишу..."
	end)
end

--======= ЗАПУСК =======--
task.spawn(function()
	createWidget()
	createMenu()
end)

--======= СОБЫТИЯ =======--
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	-- смена бинда
	if waitingForAimbotBind then
		if input.UserInputType.Name:find("MouseButton") then
			mousebind = input.UserInputType
			switch = "мышка"
		else
			keybind = input.KeyCode
			switch = "клава"
		end
		waitingForAimbotBind = false
		if aimbotBindButton then
			aimbotBindButton.Text = "Aimbot: " .. (switch == "мышка" and mousebind.Name or keybind.Name)
		end
		return
	end

	if waitingForMenuBind then
		toggleMenuKey = input.KeyCode
		waitingForMenuBind = false
		if menuBindButton then
			menuBindButton.Text = "Меню: " .. toggleMenuKey.Name
		end
		return
	end

	if waitingForFlyBind then
		toggleFlyKey = input.KeyCode
		waitingForFlyBind = false
		if flyBindButton then
			flyBindButton.Text = "Fly: " .. toggleFlyKey.Name
		end
		return
	end

	-- включение аима
	if (switch == "мышка" and input.UserInputType == mousebind)
		or (switch == "клава" and input.KeyCode == keybind) then
		aimEnabled = not aimEnabled
		if aimEnabled then
			if autoTarget then
				lockedPlayer = getClosestPlayer()
			end
			applyHighlight(lockedPlayer)
		else
			removeHighlight()
		end
		updateStatus()
	end

	-- открытие/закрытие меню
	if input.KeyCode == toggleMenuKey and frame then
		guiOpen = not guiOpen
		frame.Visible = true
		local pos = guiOpen and UDim2.new(0.5, -220, 0.5, -170) or UDim2.new(0.5, -220, 1.5, 0)
		TweenService:Create(frame, TweenInfo.new(0.3), {Position = pos}):Play()
		if not guiOpen then
			task.delay(0.3, function() if not guiOpen then frame.Visible = false end end)
		end
	end
	
	-- включение fly
	if input.KeyCode == toggleFlyKey then
		flyEnabled = not flyEnabled
		toggleFly(flyEnabled, 60)
		updateStatus()
	end
end))

table.insert(connections, RunService.Heartbeat:Connect(aimAtTarget))
