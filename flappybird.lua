--------------------------------------
-- FlappyBird Lua
-- v1.0a
--------------------------------------
-- 13/02/2014
--------------------------------------
-- Adrien "Adriweb" Bertrand
-- Inspired-Lua.org / TI-Planet.org
--------------------------------------


--------------------------------------
---------    Common stuff    ---------
--------------------------------------

local sprites = {
	bird = image.new("\016\000\000\000\016\000\000\000\000\000\000\000\032\000\000\000\016\000\001\000alalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalalal\000\128\000\128\000\128\000\128\000\128alalalalalalalalal\000\128\000\128\243\255\243\255\000\128\255\255\255\255\000\128alalalalalalal\000\128\243\255\243\255\224\255\000\128\255\255\255\255\255\255\255\255\000\128alalalal\000\128\000\128\000\128\000\128\224\255\224\255\000\128\255\255\255\255\255\255\000\128\255\255\000\128alal\000\128\243\255\243\255\243\255\243\255\000\128\224\255\000\128\255\255\255\255\255\255\000\128\255\255\000\128alal\000\128\243\255\243\255\243\255\243\255\243\255\000\128\224\255\000\128\255\255\255\255\255\255\255\255\000\128alal\000\128\224\255\243\255\243\255\243\255\224\255\000\128\224\255\224\255\000\128\000\128\000\128\000\128\000\128\000\128alal\000\128\224\255\224\255\224\255\000\128\224\255\224\255\000\128\074\237\074\237\074\237\074\237\074\237\074\237\000\128alal\000\128\000\128\000\128\160\238\160\238\000\128\074\237\000\128\000\128\000\128\000\128\000\128\000\128alalal\000\128\160\238\160\238\160\238\160\238\160\238\000\128\074\237\074\237\074\237\074\237\074\237\000\128alalalal\000\128\000\128\160\238\160\238\160\238\160\238\000\128\000\128\000\128\000\128\000\128alalalalalalal\000\128\000\128\000\128\000\128\000\128\000\128alalalalal"),
	--tubeUp = image.new(),
	--tubeDown = image.new(),
	--ground = image.new()
}

local t_period = 0.01
local window = platform.window
local the_highscore = 0



--------------------------------------
---------     Utilities      ---------
--------------------------------------

-- fix of TI Bug....
local tstart = timer.start
function timer.start(ms)
	if not timer.isRunning then
		tstart(ms)
	end
	timer.isRunning = true
end
local tstop = timer.stop
function timer.stop()
	timer.isRunning = false
	tstop()
end

----------------

-- Smarter table.remove
__tableremove = table.remove
function table.remove(t, e)
	if type(e) == "number" then
		return __tableremove(t, e)
	else
		local p = 1
		while p <= #t do
			if e == t[p] then
				break
			end
			p = p + 1
		end
		__tableremove(t, p)
	end
end

----------------

_debug = false
function debugPrint(...)
	if _debug then print(...) end
end

----------------

local nilfunc = function() end
local unimplemented = function(name) debugPrint("Unimplemented method : " .. name) return nilfunc end

class = function(prototype)
	local derived={}
	if prototype then
		function derived.__index(t,key)
			return rawget(derived,key) or prototype[key] or unimplemented(key)
		end
	else
		function derived.__index(t,key)
			return rawget(derived,key) or unimplemented(key)
		end
	end
	function derived.__call(proto,...)
		local instance={}
		setmetatable(instance,proto)
		local init=instance.init
		if init then
			init(instance,...)
		end
		return instance
	end
	setmetatable(derived,derived)
	return derived
end

----------------

if not platform.withGC then
	function platform.withGC(f)
		local gc = platform.gc()
		gc:begin()
		local result = { f(gc) }
		gc:finish()
		return unpack(result)
	end
end

-- See http://inspired-lua.org/index.php/2013/05/how-to-add-your-own-functions-to-gc/
function AddToGC(key, func)
	local gcMetatable = platform.withGC(getmetatable)
	gcMetatable[key] = func
end

----------------

-- Nspire OS 3.2+ only
if (platform.registerErrorHandler) then
	local function myErrorHandler(line, errMsg, callStack, locals)
		print("Error handled ! ", errMsg)
		return true -- let the script continue
	end
	-- platform.registerErrorHandler(myErrorHandler)
end


--------------------------------------
---------    GC Extensions    --------
--------------------------------------

local function drawCenteredRect(gc, w, h)
	gc:drawRect((platform.window:width()-w) / 2, (platform.window:height()-h) / 2, w, h)
end

local function fillCenteredRect(gc, w, h)
	gc:fillRect((platform.window:width()-w) / 2, (platform.window:height()-h) / 2, w, h)
end

local function drawCenteredString(gc, str)
	gc:drawString(str, (platform.window:width()-gc:getStringWidth(str)) / 2, platform.window:height() / 2, "middle")
end

local function drawXCenteredString(gc, str, y)
	gc:drawString(str, (platform.window:width()-gc:getStringWidth(str)) / 2, y, "top")
end

local function setTitleFont(gc)
	gc:setColorRGB(0,0,0)
	gc:setFont("serif", "b", platform.window:width()/25)
end

local function setNormalFont(gc)
	gc:setColorRGB(0,0,0)
	gc:setFont("serif", "r", platform.window:width()/30)
end

AddToGC("drawCenteredRect", drawCenteredRect)
AddToGC("fillCenteredRect", fillCenteredRect)
AddToGC("drawCenteredString", drawCenteredString)
AddToGC("drawXCenteredString", drawXCenteredString)
AddToGC("setTitleFont", setTitleFont)
AddToGC("setNormalFont", setNormalFont)



--------------------------------------
-- Screen Manager
-- More info : http://inspired-lua.org/index.php/2013/05/a-new-smarter-way-to-create-a-screen-manager
--------------------------------------

local screens = {}
local screenLocation = {}
local currentScreen = 0

function RemoveScreen(screen)
	screen:removed()
	table.remove(screens, screenLocation[screen])
	screenLocation[screen] = nil
	currentScreen = #screens
	if #screens<=0 then debugPrint("Uh oh. This shouldn't have happened ! You must have removed too many screens.") end
	collectgarbage()
end

function PushScreen(screen)
	-- if already activated, remove it first (so that it will be on front later)
	if screenLocation[screen] then
		RemoveScreen(screen)
	end

	table.insert(screens, screen)
	screenLocation[screen] = #screens

	currentScreen = #screens
	screen:pushed()
end

function GetScreen()
	return screens[currentScreen] or RootScreen
end

-------------------------

Screen = class()

function Screen:init() end
function Screen:pushed() end
function Screen:removed() end

function Screen:replaceBy(newScreen)
	RemoveScreen(self)
	PushScreen(newScreen)
end

RootScreen = Screen() -- dummy screen.

----------------

local eventCatcher = {}
local triggeredEvent = "paint"

local eventDistributer = function (...)
	if (triggeredEvent == 'paint' or triggeredEvent == 'timer') then -- stacking
		for _, currentScreen in pairs(screens) do
			currentScreen[triggeredEvent](currentScreen, ...)
		end
	else
		local currentScreen = GetScreen()
		if currentScreen[triggeredEvent] then
			currentScreen[triggeredEvent](currentScreen, ...)
		end
	end
end

eventCatcher.__index = function (tbl, event)
	triggeredEvent = event
	return eventDistributer
end

setmetatable(on, eventCatcher)



--------------------------------------
-----------     Events    ------------
---------    (overrides)    ----------
--------------------------------------

local pww, pwh = 318, 212
function on.resize(w, h)
	window = platform.window
	pww, pwh = w, h
	GetScreen():resize(w, h)
end

function on.save()
	return { ["highscore"] = the_highscore }
end

function on.restore(data)
	the_highscore = data["highscore"] or 0
end



--------------------------------------
----------     Classes     -----------
--------------------------------------

Bird = class()

function Bird:init()
	self.x = .15*pww
	self.y = .4*pwh
end

function Bird:paint(gc)
	gc:drawImage(sprites.bird, self.x-8, self.y-8)
	gc:fillRect(self.x, self.y, 2, 2)
	--[[	if ( (self.x>=GameScreen.tubes[1].x-8 and self.x<=GameScreen.tubes[1].x+30)
			 and self.y>=GameScreen.tubes[1].holeY and self.y<=(GameScreen.tubes[1].holeY+GameScreen.tubes[1].holeSize)) then
			gc:setColorRGB(0, 0, 255)
		else
			gc:setColorRGB(255, 0, 0)
		end
		gc:drawString(self.x .. " , " .. self.y, self.x-25, self.y+15, "top") ]]
end

function Bird:move(delta)
	self.y = self.y + delta
end

-------------------

Tube = class()

function Tube:init()
	self.x = .85*pww
	self.w = 30
	self.holeSize = math.random(.17*pwh, .20*pwh)
	self.holeY = math.random(.1*pwh, .6*pwh)
end

function Tube:paint(gc)
	gc:setColorRGB(0, 255, 0)
	gc:fillRect(self.x, 0, self.w, self.holeY)
	gc:fillRect(self.x, self.holeY+self.holeSize, self.w, pwh) -- we don't care about the height
	gc:setColorRGB(0, 0, 0)
	gc:drawRect(self.x, 0, self.w, self.holeY)
	gc:drawRect(self.x, self.holeY+self.holeSize, self.w, pwh)

	gc:setColorRGB(0, 255, 0)
	gc:fillRect(self.x-8, self.holeY-16, self.w+16, 16)
	gc:fillRect(self.x-8, self.holeY+self.holeSize, self.w+16, 16)
	gc:setColorRGB(0, 0, 0)
	gc:drawRect(self.x-8, self.holeY-16, self.w+16, 16)
	gc:drawRect(self.x-8, self.holeY+self.holeSize, self.w+16, 16)
end

function Tube:scroll()
	self.x = self.x - 2
end

function Tube:checkCollisionWith(bird)
	return (not ( bird.x > self.x-8 and bird.x < self.x+self.w+8 and bird.y > self.holeY and bird.y < self.holeY+self.holeSize) )
end


--------------------------------------
----------     Screens     -----------
--------------------------------------

----------------------
-- Main Menu Screen --
----------------------

GameScreen = Screen()

function GameScreen:pushed()
	self.started = false
	self.score = 0
	self.pause = false
	self.gameOver = false
	self.statusText = "Game Screen. Enter to start, Escape to stop."

	self.lastAction = 0
	self.hasPressedTab = false

	self.bird = Bird()
	self.tubes = { Tube() }
end

function GameScreen:removed()
	timer.stop()
end

function GameScreen:paint(gc)
	gc:setColorRGB(155,230,245)
	gc:fillRect(0,0,pww,pwh)

	for i,tube in ipairs(self.tubes) do
		tube:paint(gc)
	end

	self.bird:paint(gc)

	gc:setTitleFont()
	if (not self.started or self.gameOver) then gc:drawXCenteredString(self.statusText,.2*pwh) end
	gc:setNormalFont()
	if (self.started) then
		gc:drawXCenteredString("Score : " .. tostring(self.score) .. ((self.score > 0 and the_highscore==self.score) and " (Highscore !)" or ""), .05*pwh)
	else
		gc:drawXCenteredString("Highscore : " .. tostring(the_highscore), .05*pwh)
	end
	if (self.started and self.pause) then gc:drawXCenteredString("-- PAUSE --", .9*pwh) end
end

function GameScreen:enterKey()
	if (not self.started) then
		if self.gameOver then self:pushed() end
		timer.start(t_period)
		self.started = true
	end
	window:invalidate()
end

function GameScreen:charIn(ch)
	if ch=="p" and self.started then
		self.pause = not self.pause
	elseif ch=="h" then
		self.pause = true
		PushScreen(AboutScreen)
	end
	window:invalidate()
end

function GameScreen:tabKey()
	if self.started then
		self.hasPressedTab = true
		self.lastAction = timer.getMilliSecCounter()
	end
end

function GameScreen:escapeKey()
	self:stopGame()
	window:invalidate()
end

function GameScreen:timer()
	if self.started and not self.pause then
		local timeNow = timer.getMilliSecCounter()
		if (self.bird.y < 2) then
			self.bird.y = 2
		end
		self.bird:move((self.hasPressedTab and (timeNow-self.lastAction < 100)) and -1.8 or 1.5)

		if (self.tubes[#self.tubes].x < .7*pwh and math.random(1,4)==1) then
			table.insert(self.tubes, Tube())
		end

		if self.tubes[1].x < -50 then
			self.score = self.score + 1
			table.remove(self.tubes, 1)
		end

		for i,tube in ipairs(self.tubes) do
			tube:scroll()
			if (self.bird.y>pwh-10 or i==1 and self.bird.x >= tube.x-8 and self.bird.x <= tube.x+tube.w+8 and tube:checkCollisionWith(self.bird)) then
				timer.stop()
				self.gameOver = true
				print("game over")
			end
		end



		-------
		if (self.score > the_highscore) then
			the_highscore = self.score
			document.markChanged()
		end

		if (timeNow-self.lastAction > 100) then
			self.hasPressedTab = false
		end

		window:invalidate()
	end
end

function GameScreen:stopGame()
	timer.stop()
	self:pushed() -- resets stuff
end

---------------

-----------------------
-- Help/About Screen --
-----------------------

AboutScreen = Screen()

function AboutScreen:pushed()
end

function AboutScreen:removed()
	GameScreen.pause = false
end

function AboutScreen:paint(gc)
	gc:setColorRGB(210, 210, 210)
	gc:fillCenteredRect(.6*pww, .5*pwh)
	gc:setColorRGB(0, 0, 0)
	gc:drawCenteredRect(.6*pww, .5*pwh)
	gc:setColorRGB(75, 75, 75)
	gc:drawCenteredRect(.6*pww-2, .5*pwh-2)
	gc:setColorRGB(150, 150, 150)
	gc:drawCenteredRect(.6*pww-4, .5*pwh-4)
	gc:setColorRGB(0, 0, 0)
	gc:setFont("serif", "b", pww/32)
	gc:drawXCenteredString("FlappyBird TI-Nspire Lua", .26*pwh)
	gc:setFont("serif", "i", pww/40)
	gc:drawXCenteredString("Original game by .GEARS", .39*pwh)
	gc:setFont("serif", "r", pww/40)
	gc:drawXCenteredString("(C) 2014 Adriweb -  tiplanet.org", .335*pwh)
	gc:drawXCenteredString("Start/Stop : [Enter]/[Esc]", .49*pwh)
	gc:drawXCenteredString("Fly up : [tab]", .55*pwh)
	gc:drawXCenteredString("(un)Pause : [p]", .61*pwh)
	gc:drawXCenteredString("Help/About : [h]", .67*pwh)
end

function AboutScreen:escapeKey()
	RemoveScreen(self)
	window:invalidate()
end
AboutScreen.enterKey = AboutScreen.escapeKey

function AboutScreen:charIn(ch)
	if ch=='h' then
		self:escapeKey()
	end
end

--------------------------------------
------   Launching the game   --------
--------------------------------------

PushScreen(GameScreen)
