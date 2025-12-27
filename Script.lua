-- Configuration
local EYE_TYPE = 2  -- 2 = female
local EYEBROW_TYPE = 3  -- 1 to 3
local MOUTH_TYPE = 1  -- 1 to 3
local FACE_SIZE = 1 -- Overall face size multiplier
local BLINK_INTERVAL_MIN = 2
local BLINK_INTERVAL_MAX = 6
local BLINK_SPEED = 0.125
local CLOSED_EYES_SLIDE_DISTANCE = 0.1
local EYE_SQUASH_AMOUNT = 0.7  -- How much to squash the eyes (0.7 = 70% of original height)
local MOUTH_SQUASH_AMOUNT = 0.7  -- How much to squash the mouth vertically when closed
local MOUTH_OPEN_SQUASH = 0.7  -- How much the open mouth is pre-squashed horizontally
local MOUTH_OPEN_SPEED = 0.03  -- Speed of mouth opening/closing
local CHARS_PER_MOUTH_OPEN = 4  -- Number of characters per mouth open event
local MAX_TALK_CHARS = 60  -- Maximum characters to process for talking
local ENABLE_EYE_TRACKING = true  -- Enable/disable eye tracking
local SHADOW_TWEEN_SPEED = 0.2

-- Setup
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local player = game.Players.LocalPlayer

local function setupFace(char)
	local humanoid = char:WaitForChild("Humanoid")
	local head = char:WaitForChild("Head")

	local function setupHeadMesh()
		task.wait(0.6)
		if head:FindFirstChild("face") then
			head.face:Destroy()
		end

		-- Check if R6 (has Mesh) or R15 (is MeshPart)
		if head:IsA("MeshPart") then
			-- R15
			head.TextureID = ""
		elseif head:FindFirstChild("Mesh") then
			-- R6
			head.Mesh.face:Destroy()
			head.Mesh.TextureId = ""
		end
	end

	task.spawn(setupHeadMesh)

	-- Create face part
	local facePart = Instance.new("Part")
	facePart.Name = "FacePart"
	facePart.Size = Vector3.new(1, 1, 0.1)
	facePart.CFrame = head.CFrame * CFrame.new(0, 0, -0.55)
	facePart.Anchored = false
	facePart.CanCollide = false
	facePart.Transparency = 1

	-- Weld to head
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = facePart
	weld.Parent = facePart

	facePart.Parent = head
	local faceParent = facePart

	-- Main face gui (mouth, eyebrows, closed eyes)
	local faceGui = Instance.new("SurfaceGui")
	faceGui.Name = "FaceGui"
	faceGui.Parent = faceParent
	faceGui.Face = Enum.NormalId.Front
	faceGui.CanvasSize = Vector2.new(200, 200)
	faceGui.LightInfluence = 1
	faceGui.ZOffset = 0

	-- Eye gui (ONLY open eyes)
	local eyeGui = Instance.new("SurfaceGui")
	eyeGui.Name = "EyeGui"
	eyeGui.Parent = faceParent
	eyeGui.Face = Enum.NormalId.Front
	eyeGui.CanvasSize = Vector2.new(200, 200)
	eyeGui.Enabled = true
	eyeGui.LightInfluence = 1
	eyeGui.ZOffset = 1

	-- Determine eye textures based on gender
	local eyePrefix = EYE_TYPE == 2 and "FemEye" or "Eye"
	local closedPrefix = EYE_TYPE == 2 and "FemClosed" or "Closed"

	-- Calculate centered position and size based on FACE_SIZE
	local faceOffset = (1 - FACE_SIZE) / 2
	local faceSizeUDim = UDim2.new(FACE_SIZE, 0, FACE_SIZE, 0)
	local facePositionUDim = UDim2.new(faceOffset, 0, faceOffset, 0)

	-- Create eye direction images for tracking
	local eyeDirections = {"UL", "U", "UR", "L", "C", "R", "DL", "D", "DR"}
	local leftEyeImages = {}
	local rightEyeImages = {}

	for _, dir in ipairs(eyeDirections) do
		local leftImg = Instance.new("ImageLabel")
		leftImg.Name = "LeftEye" .. dir
		leftImg.Parent = eyeGui
		leftImg.Image = "rbxasset://facial/" .. eyePrefix .. dir .. "L.png"
		leftImg.Size = faceSizeUDim
		leftImg.Position = facePositionUDim
		leftImg.BackgroundTransparency = 1
		leftImg.ImageTransparency = 1
		leftEyeImages[dir] = leftImg

		local rightImg = Instance.new("ImageLabel")
		rightImg.Name = "RightEye" .. dir
		rightImg.Parent = eyeGui
		rightImg.Image = "rbxasset://facial/" .. eyePrefix .. dir .. "R.png"
		rightImg.Size = faceSizeUDim
		rightImg.Position = facePositionUDim
		rightImg.BackgroundTransparency = 1
		rightImg.ImageTransparency = 1
		rightEyeImages[dir] = rightImg
	end

	-- Set center as default visible
	leftEyeImages["C"].ImageTransparency = 0
	rightEyeImages["C"].ImageTransparency = 0

	-- Reference center eyes as leftEye and rightEye for compatibility
	local leftEye = leftEyeImages["C"]
	local rightEye = rightEyeImages["C"]

	-- Create closed eyes (ImageLabels that will slide)
	local leftClosedEye = Instance.new("ImageLabel")
	leftClosedEye.Name = "LeftClosedEye"
	leftClosedEye.Parent = faceGui
	leftClosedEye.Image = "rbxasset://facial/" .. closedPrefix .. "L.png"
	leftClosedEye.Size = faceSizeUDim
	leftClosedEye.Position = facePositionUDim
	leftClosedEye.BackgroundTransparency = 1
	leftClosedEye.ImageTransparency = 1  -- Start invisible

	local rightClosedEye = Instance.new("ImageLabel")
	rightClosedEye.Name = "RightClosedEye"
	rightClosedEye.Parent = faceGui
	rightClosedEye.Image = "rbxasset://facial/" .. closedPrefix .. "R.png"
	rightClosedEye.Size = faceSizeUDim
	rightClosedEye.Position = facePositionUDim
	rightClosedEye.BackgroundTransparency = 1
	rightClosedEye.ImageTransparency = 1  -- Start invisible

	-- Create eyebrows (ImageLabels that will slide with closed eyes)
	local leftEyebrow = Instance.new("ImageLabel")
	leftEyebrow.Name = "LeftEyebrow"
	leftEyebrow.Parent = faceGui
	leftEyebrow.Image = "rbxasset://facial/" .. EYEBROW_TYPE .. "EyebrowL.png"
	leftEyebrow.Size = faceSizeUDim
	leftEyebrow.Position = facePositionUDim
	leftEyebrow.BackgroundTransparency = 1

	local rightEyebrow = Instance.new("ImageLabel")
	rightEyebrow.Name = "RightEyebrow"
	rightEyebrow.Parent = faceGui
	rightEyebrow.Image = "rbxasset://facial/" .. EYEBROW_TYPE .. "EyebrowR.png"
	rightEyebrow.Size = faceSizeUDim
	rightEyebrow.Position = facePositionUDim
	rightEyebrow.BackgroundTransparency = 1

	-- Create mouth (ImageLabels - closed and open)
	local mouthClosed = Instance.new("ImageLabel")
	mouthClosed.Name = "MouthClosed"
	mouthClosed.Parent = faceGui
	mouthClosed.Image = "rbxasset://facial/" .. MOUTH_TYPE .. "MouthClosed.png"
	mouthClosed.Size = faceSizeUDim
	mouthClosed.Position = facePositionUDim
	mouthClosed.BackgroundTransparency = 1

	local mouthOpen = Instance.new("ImageLabel")
	mouthOpen.Name = "MouthOpen"
	mouthOpen.Parent = faceGui
	mouthOpen.Image = "rbxasset://facial/" .. MOUTH_TYPE .. "MouthOpened.png"
	mouthOpen.Size = faceSizeUDim
	mouthOpen.Position = facePositionUDim
	mouthOpen.BackgroundTransparency = 1
	mouthOpen.ImageTransparency = 1  -- Start invisible

	local mouthIdle = Instance.new("ImageLabel")
	mouthIdle.Name = "MouthIdle"
	mouthIdle.Parent = faceGui
	mouthIdle.Image = "rbxasset://facial/" .. MOUTH_TYPE .. "MouthIdle.png"
	mouthIdle.Size = faceSizeUDim
	mouthIdle.Position = facePositionUDim
	mouthIdle.BackgroundTransparency = 1
	mouthIdle.ImageTransparency = 1  -- Start invisible
	
	local faceShadow = Instance.new("ImageLabel")
	faceShadow.Name = "FaceShadow"
	faceShadow.Parent = faceGui
	faceShadow.Image = "rbxasset://facial/Shadow.png"
	faceShadow.Size = UDim2.fromScale(1, 1)
	faceShadow.Position = UDim2.fromScale(0, 0)
	faceShadow.BackgroundTransparency = 1
	faceShadow.ImageTransparency = 1  -- Start invisible
	faceShadow.ZIndex = 0

	faceGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	eyeGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	
	local allEyeImages = {}

	for _, img in pairs(leftEyeImages) do
		table.insert(allEyeImages, img)
	end

	for _, img in pairs(rightEyeImages) do
		table.insert(allEyeImages, img)
	end
	
	local eyeOriginalSize = leftEyeImages["C"].Size
	local eyeOriginalPos = leftEyeImages["C"].Position

	-- Store initial positions and sizes
	local leftClosedStartPos = leftClosedEye.Position
	local rightClosedStartPos = rightClosedEye.Position
	local leftEyebrowStartPos = leftEyebrow.Position
	local rightEyebrowStartPos = rightEyebrow.Position
	local mouthClosedOriginalSize = mouthClosed.Size
	local mouthOpenOriginalSize = mouthOpen.Size
	

	local faceShadowTween = nil
	local faceLightTween = nil
	local faceShadowEnabled = false

	local shadowTweenInfo = TweenInfo.new(
		SHADOW_TWEEN_SPEED,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)
	
	local function setDownwardFaceEffects(enable)
		if faceShadowEnabled == enable then
			return
		end
		faceShadowEnabled = enable

		-- Cancel running tweens
		if faceShadowTween then faceShadowTween:Cancel() end
		if faceLightTween then faceLightTween:Cancel() end

		if enable then
			faceShadowTween = TweenService:Create(
				faceShadow,
				shadowTweenInfo,
				{ ImageTransparency = 0.5 }
			)

			faceLightTween = TweenService:Create(
				eyeGui,
				shadowTweenInfo,
				{ LightInfluence = 0.5 }
			)
		else
			faceShadowTween = TweenService:Create(
				faceShadow,
				shadowTweenInfo,
				{ ImageTransparency = 1 }
			)

			faceLightTween = TweenService:Create(
				eyeGui,
				shadowTweenInfo,
				{ LightInfluence = 1 }
			)
		end

		faceShadowTween:Play()
		faceLightTween:Play()
	end

	-- Idle detection variables
	local lastInputTime = tick()
	local isIdle = false
	local nextIdleTime = tick() + math.random(10, 20)
	
	-- Blink function
	local isBlinking = false
	local function blink()
		if isBlinking then return end
		isBlinking = true
		local closeTweenInfo = TweenInfo.new(BLINK_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local openTweenInfo = TweenInfo.new(BLINK_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		local squashedSize = UDim2.new(eyeOriginalSize.X.Scale, 0, eyeOriginalSize.Y.Scale * EYE_SQUASH_AMOUNT, 0)

		local squashOffset = (1 - EYE_SQUASH_AMOUNT) * eyeOriginalSize.Y.Scale / 2
		local squashedPos = UDim2.new(eyeOriginalPos.X.Scale, 0, eyeOriginalPos.Y.Scale + squashOffset, 0)

		local squashTweens = {}
		for _, eye in ipairs(allEyeImages) do
			local t = TweenService:Create(
				eye,
				closeTweenInfo,
				{ Size = squashedSize, Position = squashedPos }
			)
			table.insert(squashTweens, t)
			t:Play()
		end

		squashTweens[#squashTweens].Completed:Wait()

		eyeGui.Enabled = false
		leftClosedEye.ImageTransparency = 0
		rightClosedEye.ImageTransparency = 0

		local leftClosedDown = UDim2.new(leftClosedStartPos.X.Scale, 0, leftClosedStartPos.Y.Scale + CLOSED_EYES_SLIDE_DISTANCE, 0)

		local rightClosedDown = UDim2.new(rightClosedStartPos.X.Scale, 0, rightClosedStartPos.Y.Scale + CLOSED_EYES_SLIDE_DISTANCE, 0)

		local leftBrowDown = UDim2.new(leftEyebrowStartPos.X.Scale, 0, leftEyebrowStartPos.Y.Scale + CLOSED_EYES_SLIDE_DISTANCE / 2, 0)

		local rightBrowDown = UDim2.new(rightEyebrowStartPos.X.Scale, 0, rightEyebrowStartPos.Y.Scale + CLOSED_EYES_SLIDE_DISTANCE / 2, 0)

		local closeLeft = TweenService:Create(leftClosedEye, closeTweenInfo, { Position = leftClosedDown })
		local closeRight = TweenService:Create(rightClosedEye, closeTweenInfo, { Position = rightClosedDown })
		local browDownLeft = TweenService:Create(leftEyebrow, closeTweenInfo, { Position = leftBrowDown })
		local browDownRight = TweenService:Create(rightEyebrow, closeTweenInfo, { Position = rightBrowDown })

		closeLeft:Play()
		closeRight:Play()
		browDownLeft:Play()
		browDownRight:Play()

		closeLeft.Completed:Wait()

		task.wait(BLINK_SPEED * 0.3)

		local openLeft = TweenService:Create(leftClosedEye, openTweenInfo, { Position = leftClosedStartPos })
		local openRight = TweenService:Create(rightClosedEye, openTweenInfo, { Position = rightClosedStartPos })
		local browUpLeft = TweenService:Create(leftEyebrow, openTweenInfo, { Position = leftEyebrowStartPos })
		local browUpRight = TweenService:Create(rightEyebrow, openTweenInfo, { Position = rightEyebrowStartPos })

		openLeft:Play()
		openRight:Play()
		browUpLeft:Play()
		browUpRight:Play()

		openLeft.Completed:Wait()

		leftClosedEye.ImageTransparency = 1
		rightClosedEye.ImageTransparency = 1
		eyeGui.Enabled = true

		for _, eye in ipairs(allEyeImages) do
			eye.Size = squashedSize
			eye.Position = squashedPos
		end

		for _, eye in ipairs(allEyeImages) do
			TweenService:Create(
				eye,
				openTweenInfo,
				{ Size = eyeOriginalSize, Position = eyeOriginalPos }
			):Play()
		end
		isBlinking = false
	end

	-- Eye tracking function
	local currentEyeDirection = "C"
	local function updateEyeTracking()
		if not ENABLE_EYE_TRACKING then return end

		local camera = workspace.CurrentCamera
		if not camera then return end

		-- Get direction from head to camera
		local headPos = head.Position
		local camPos = camera.CFrame.Position
		local direction = (camPos - headPos).Unit

		-- Convert to head local space
		local localDir = head.CFrame:VectorToObjectSpace(direction)

		-- Determine which direction to show
		local horizontal = ""
		local vertical = ""

		if localDir.X < -0.3 then
			horizontal = "R"
		elseif localDir.X > 0.3 then
			horizontal = "L"
		else
			horizontal = ""
		end

		if localDir.Y > 0.3 then
			vertical = "U"
		elseif localDir.Y < -0.4 then
			vertical = "D"
		else
			vertical = ""
		end

		local newDirection = vertical .. horizontal
		if newDirection == "" then newDirection = "C" end
		local isDown = (newDirection == "D")
		setDownwardFaceEffects(isDown)

		-- Update eyes if direction changed
		if newDirection ~= currentEyeDirection then
			-- Hide old direction instantly
			leftEyeImages[currentEyeDirection].ImageTransparency = 1
			rightEyeImages[currentEyeDirection].ImageTransparency = 1

			-- Show new direction instantly
			leftEyeImages[newDirection].ImageTransparency = 0
			rightEyeImages[newDirection].ImageTransparency = 0

			currentEyeDirection = newDirection
		end
	end

	-- Mouth talk function
	local currentMouthTween = nil
	local mouthState = "closed"  -- "closed", "opening", "open", "closing", "idle"

	local function resetIdleMouth()
		if mouthState == "idle" then
			mouthIdle.ImageTransparency = 1
			mouthClosed.ImageTransparency = 0
			mouthClosed.Size = mouthClosedOriginalSize
			mouthClosed.Position = facePositionUDim
			mouthState = "closed"
			isIdle = false
		end
		lastInputTime = tick()
		nextIdleTime = tick() + math.random(10, 20)
	end

	-- Detect humanoid movement only
	local lastMoveDirection = humanoid.MoveDirection
	humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if humanoid.MoveDirection.Magnitude > 0 and lastMoveDirection.Magnitude == 0 then
			resetIdleMouth()
		end
		lastMoveDirection = humanoid.MoveDirection
	end)

	local function talkMouth()
		resetIdleMouth()
		lastInputTime = tick()  -- Reset idle timer when talking

		local openTweenInfo = TweenInfo.new(MOUTH_OPEN_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local closeTweenInfo = TweenInfo.new(MOUTH_OPEN_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		-- If currently closing, cancel and wait until fully closed
		if mouthState == "closing" then
			if currentMouthTween then
				currentMouthTween:Cancel()
			end
			-- Force close immediately
			mouthOpen.ImageTransparency = 1
			mouthClosed.ImageTransparency = 0
			mouthClosed.Size = mouthClosedOriginalSize
			mouthClosed.Position = facePositionUDim
			mouthState = "closed"
		end

		-- Wait until mouth is fully closed
		while mouthState ~= "closed" do
			task.wait(0.01)
		end

		mouthState = "opening"

		-- Squash closed mouth on Y axis (centered)
		local closedSquashedSize = UDim2.new(mouthClosedOriginalSize.X.Scale, 0, mouthClosedOriginalSize.Y.Scale * MOUTH_SQUASH_AMOUNT, 0)
		local closedSquashOffset = (1 - MOUTH_SQUASH_AMOUNT) * mouthClosedOriginalSize.Y.Scale / 2
		local closedSquashedPos = UDim2.new(facePositionUDim.X.Scale, 0, facePositionUDim.Y.Scale + closedSquashOffset, 0)

		currentMouthTween = TweenService:Create(mouthClosed, closeTweenInfo, {Size = closedSquashedSize, Position = closedSquashedPos})
		currentMouthTween:Play()
		currentMouthTween.Completed:Wait()

		-- Hide closed mouth, show open mouth (pre-squashed on X axis, centered)
		mouthClosed.ImageTransparency = 1
		mouthOpen.ImageTransparency = 0
		local openSquashedSize = UDim2.new(mouthOpenOriginalSize.X.Scale * MOUTH_OPEN_SQUASH, 0, mouthOpenOriginalSize.Y.Scale, 0)
		local openSquashOffset = (1 - MOUTH_OPEN_SQUASH) * mouthOpenOriginalSize.X.Scale / 2
		local openSquashedPos = UDim2.new(facePositionUDim.X.Scale + openSquashOffset, 0, facePositionUDim.Y.Scale, 0)
		mouthOpen.Size = openSquashedSize
		mouthOpen.Position = openSquashedPos

		-- Reset closed mouth size and position
		mouthClosed.Size = mouthClosedOriginalSize
		mouthClosed.Position = facePositionUDim

		-- Unsquash open mouth on X axis
		currentMouthTween = TweenService:Create(mouthOpen, openTweenInfo, {Size = mouthOpenOriginalSize, Position = facePositionUDim})
		currentMouthTween:Play()
		currentMouthTween.Completed:Wait()

		mouthState = "open"
		local openTime = math.random(40, 75) / 1000  -- Random between 0.04 - 0.075
		task.wait(openTime)

		-- Start closing
		mouthState = "closing"

		local openSquashedSize = UDim2.new(mouthOpenOriginalSize.X.Scale * MOUTH_OPEN_SQUASH, 0, mouthOpenOriginalSize.Y.Scale, 0)
		local openSquashOffset = (1 - MOUTH_OPEN_SQUASH) * mouthOpenOriginalSize.X.Scale / 2
		local openSquashedPos = UDim2.new(facePositionUDim.X.Scale + openSquashOffset, 0, facePositionUDim.Y.Scale, 0)

		local closedSquashedSize = UDim2.new(mouthClosedOriginalSize.X.Scale, 0, mouthClosedOriginalSize.Y.Scale * MOUTH_SQUASH_AMOUNT, 0)
		local closedSquashOffset = (1 - MOUTH_SQUASH_AMOUNT) * mouthClosedOriginalSize.Y.Scale / 2
		local closedSquashedPos = UDim2.new(facePositionUDim.X.Scale, 0, facePositionUDim.Y.Scale + closedSquashOffset, 0)

		-- Squash open mouth back on X axis
		currentMouthTween = TweenService:Create(mouthOpen, closeTweenInfo, {Size = openSquashedSize, Position = openSquashedPos})
		currentMouthTween:Play()
		currentMouthTween.Completed:Wait()

		-- Hide open mouth, show closed mouth (squashed)
		mouthOpen.ImageTransparency = 1
		mouthClosed.ImageTransparency = 0
		mouthClosed.Size = closedSquashedSize
		mouthClosed.Position = closedSquashedPos

		-- Unsquash closed mouth on Y axis
		currentMouthTween = TweenService:Create(mouthClosed, openTweenInfo, {Size = mouthClosedOriginalSize, Position = facePositionUDim})
		currentMouthTween:Play()
		currentMouthTween.Completed:Wait()

		mouthState = "closed"
	end

	-- Chat listener
	local chatConnection = player.Chatted:Connect(function(message)
		local limitedMessage = message:sub(1, MAX_TALK_CHARS)
		local mouthOpenEvents = math.ceil(#limitedMessage / CHARS_PER_MOUTH_OPEN)

		for i = 1, mouthOpenEvents do
			talkMouth()
		end
	end)

	-- Blink loop
	local running = true

	local diedConnection = humanoid.Died:Connect(function()
		running = false
		chatConnection:Disconnect()
	end)

	-- Idle mouth checker - runs in parallel with blink loop
	task.spawn(function()
		while running and char.Parent do
			task.wait(0.5)

			-- Check if it's time for idle animation
			local currentTime = tick()
			local timeUntilIdle = nextIdleTime - currentTime

			if currentTime >= nextIdleTime and mouthState == "closed" and not isIdle then
				isIdle = true
				mouthState = "idle"

				local idleTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

				-- Squash closed mouth on X axis (centered)
				local closedSquashedSize = UDim2.new(mouthClosedOriginalSize.X.Scale * 0.85, 0, mouthClosedOriginalSize.Y.Scale, 0)
				local squashAmount = mouthClosedOriginalSize.X.Scale * (1 - 0.85)
				local closedSquashOffset = squashAmount / 2
				local closedSquashedPos = UDim2.new(facePositionUDim.X.Scale + closedSquashOffset, 0, facePositionUDim.Y.Scale, 0)

				local squashClosed = TweenService:Create(mouthClosed, idleTweenInfo, {Size = closedSquashedSize, Position = closedSquashedPos})
				squashClosed:Play()
				squashClosed.Completed:Wait()

				-- Switch to idle mouth (unsquashed)
				if mouthState == "idle" then
					mouthClosed.ImageTransparency = 1
					mouthIdle.ImageTransparency = 0

					-- Reset closed mouth
					mouthClosed.Size = mouthClosedOriginalSize
					mouthClosed.Position = facePositionUDim

					task.wait(2)  -- Show idle mouth for 2 seconds
				end

				-- Return to closed mouth if still idle
				if mouthState == "idle" then
					-- Switch back to closed (squashed)
					mouthIdle.ImageTransparency = 1
					mouthClosed.ImageTransparency = 0
					mouthClosed.Size = closedSquashedSize
					mouthClosed.Position = closedSquashedPos

					-- Unsquash closed mouth
					local unsquashClosed = TweenService:Create(mouthClosed, idleTweenInfo, {Size = mouthClosedOriginalSize, Position = facePositionUDim})
					unsquashClosed:Play()
					unsquashClosed.Completed:Wait()

					if mouthState == "idle" then
						mouthState = "closed"
						isIdle = false
						nextIdleTime = tick() + math.random(10, 20)
					end
				end
			end
		end
	end)
	
	-- Eye tracking loop
	task.spawn(function()
		while running and char.Parent do
			updateEyeTracking()
			task.wait(0.1)
		end
	end)


	-- Blink loop runs separately
	task.spawn(function()
		while running and char.Parent do
			local waitTime = math.random(BLINK_INTERVAL_MIN + BLINK_SPEED, BLINK_INTERVAL_MAX)
			task.wait(waitTime)
			blink()
		end
	end)
end

-- Initial setup
if player.Character then
	setupFace(player.Character)
end

-- Setup on respawn
player.CharacterAdded:Connect(function(char)
	setupFace(char)
end)
