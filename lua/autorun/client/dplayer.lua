-- Не очень хорошо написано, правда?

local tag = "dplayer"

local filen = "unit/dplayer_favorits.txt"

--

local tagcol = Color( 120, 125, 250 )

local white, gray, black = Color( 255, 255, 255 ), Color( 120, 120, 120 ), Color( 50, 50, 50 )
local red, green, blue = Color( 255, 0, 0 ), Color( 70, 210, 70 ), Color( 50, 160, 240 )

local selected = Color( 120, 190, 255 )

--

local expl = string.Explode
local nal = notification.AddLegacy

--

local function log( ... )
	chat.AddText( 
		tagcol, "[DPlayer]",
		white, " ", ...
	)	
end

local function encode( data ) -- wire
	local ndata = string.gsub( data, "[^%w _~%.%-]", function( str )
		local nstr = string.format( "%X", string.byte( str ) )

		return "%" .. ( ( string.len( nstr ) == 1 ) and "0" or "" ) .. nstr
	end )

	return string.gsub( ndata, " ", "+" )
end

--

local foundmusic = {}

local nextsearch = CurTime()
local function searchMusic( what, ondone )
	if nextsearch > CurTime() then return ondone "cooldown" end
	nextsearch = CurTime() + 3
	
	what = string.Left( what, 128 )
	
	if what:Trim():len() < 1 then return ondone "nothing" end
	
	http.Fetch( 
		( "https://mp3cc.biz/search/f/%s/" ):format( encode( what ) ),
		function( body, size, headers, code ) -- success
			local toreturn = {}
			local data = expl( "<li", body )
			local now = 0
			local pos = 0
			
			table.Empty( foundmusic )
			
			while ( now < table.Count( data ) ) do -- I got this from my player
				now = now + 1
				pos = now + 12
				
				local m = data[pos]
				if not m then continue end
				
				local murl = expl( "mp3=", m )
				if not murl[2] then continue end
				murl = expl( "\"", murl[2] )
				murl = murl[ 2 ]
				
				local mauthor = expl( "<b>", m ) -- Сюда проверку уже пихать не нужно, т.к. проверка выше остановит скрипт, если элемента нету
				mauthor = expl( ">", mauthor[2] )
				mauthor = expl( "<", mauthor[2] )
				mauthor = mauthor[ 1 ]
				mauthor = mauthor:gsub( "&amp;", "&" )
				
				local mname = expl( "<em>", m )
				mname = expl( ">", mname[3] )
				mname = expl( "<", mname[2] )
				mname = mname[ 1 ]
				
				local mduration = expl( "-duration", m )
				mduration = expl( ">", mduration[3] )
				mduration = expl( "<", mduration[2] )
				mduration = mduration[ 1 ]
				
				local data = {
					url = murl,
					author = mauthor,
					name = mname,
					duration = mduration
				}
				foundmusic[ now ] = data
				
				table.insert( toreturn, data )
			end
			
			ondone( toreturn )
		end,
		
		function( err )
			log( "Fail: ", red, err )
			
			ondone "fail"
		end
	)	
end

local music = {
	duration = 0, starttime = RealTime(),
	paused = false, replay = false,
	volume = 1,
}

local function playMusic( url )
	if music.paused then music.Toggle() end
	if IsValid( music.snd ) then music.snd:Stop() end
	
	sound.PlayURL( url, "noblock", function( s, eid, err )
		if not IsValid( s ) then return log( "Error: ", red, err ) end
		
		s:SetVolume( music.volume )
		
		local len = s:GetLength()
		
		music.snd = s
		music.duration = len
		music.starttime = RealTime()
	end )
end

--

local fav_list
local favorites = {}
local function addToFavorites( data, save )
	if not IsValid( fav_list ) then return end
	
	favorites[ data.url ] = { id = data.id, name = data.name, author = data.author, duration = data.duration }
	
	music.createMPanel( fav_list, data.id, data, true )
	
	if save then file.Write( filen, util.TableToJSON( favorites ) ) end
end

--

local lastchosen
local function createMPanel( list, i, d, isfav )
	local mname = music.mname
	local mstime = music.mstime
	
	--
	
	local np = list:Add "DPanel"
	np:DockMargin( 2, 2, 2, 0 )
	np:Dock( TOP )
	
	local play = np:Add "DButton" play.parent = np
	play:DockMargin( 1, 1, 2, 1 )
	play:Dock( LEFT )
	play:SetWidth( 24 ) play:SetText "" play:SetTooltip "Play"
	play:SetImage "icon16/control_play.png"
	
	local fav = np:Add "DButton" play.parent = np
	fav:DockMargin( 1, 1, 5, 1 )
	fav:Dock( LEFT )
	fav:SetWidth( 24 ) fav:SetText "" fav:SetImage "icon16/star.png"
	
	if isfav then
		fav:SetTooltip "Unfavorite"
		
		fav.DoClick = function()
			np:Remove()
			
			favorites[ d.url ] = nil
			file.Write( filen, util.TableToJSON( favorites ) )
		end
	else
		fav:SetTooltip "Favorite"
		
		d.id = i
		fav.DoClick = function() addToFavorites( d, true ) end
	end
	
	local id = np:Add "DLabel"
	id:Dock( LEFT )
	id:SetWidth( 20 )
	id:SetText( i )
	id:SetColor( black )
	
	local aut = np:Add "DLabel"
	aut:Dock( LEFT )
	aut:SetWidth( 120 )
	aut:SetText( d.author )
	aut:SetColor( gray )
	
	local name = np:Add "DLabel"
	name:Dock( FILL )
	name:SetText( d.name )
	name:SetColor( black )
	
	local time = np:Add "DLabel"
	time:DockPadding( 5, 1, 0, 1 )
	time:Dock( RIGHT )
	time:SetWidth( 35 )
	time:SetText( d.duration )
	time:SetColor( gray )
	
	list:AddItem( np )
	
	--
	
	play.DoClick = function( self )
		playMusic( d.url )
		
		if IsValid( lastchosen ) then lastchosen:SetBackgroundColor( white ) end
		lastchosen = self.parent
		lastchosen:SetBackgroundColor( selected )
		
		--
		
		if IsValid( music.snd ) then music.snd:Stop() end
		
		mname:SetText( d.author .. " - " .. d.name )
		
		local tname = ( tag .. ":update" )
		timer.Create( tname, 1, 0, function()
			if not IsValid( music.snd ) or not IsValid( fav_list ) or music.snd:GetState() == 0 then 
				if music.replay then
					music.starttime = RealTime()
					music.snd:Play()
					
					return	
				else
					if IsValid( lastchosen ) then lastchosen:SetBackgroundColor( white ) end
					
					timer.Remove( tname ) 
				end
				
				return
			end
			
			if music.paused then
				music.starttime = music.starttime + 1
			end
			
			local t = ( RealTime() - music.starttime )
			
			mstime:SetText( string.FormattedTime( t, "%02i:%02i" ) .. " / " .. d.duration )
		end )
	end
	
	return np
end music.createMPanel = createMPanel

local function spawnpanel( icn, fr )
	fr:SetTitle "Derma-Player By Zvbhrf"
	fr:SetSize( 600, 400 )
	fr:Center()
	
	fr:SetMinWidth( 500 )
	fr:SetMinHeight( 300 )
	
	fr:SetSizable( true )
	fr:SetIcon "icon16/control_play_blue.png"
	
	fr.OnClose = function()
		if IsValid( music.snd ) then music.snd:Stop() end
		
		RunConsoleCommand "-menu_context"
	end
	
	if not file.Exists( filen, "DATA" ) then file.Write( filen, "[]" ) end
	
	--
	
	local sheet = fr:Add "DPropertySheet"
	sheet:Dock( FILL )
	
	--
	
	local sp = sheet:Add "DPanel"
	sheet:AddSheet( "Search", sp, "icon16/zoom.png" )
	
	local fav = sheet:Add "DPanel"
	sheet:AddSheet( "Favorites", fav, "icon16/star.png" )
	
	-- CONTROLS
	
	local controls = fr:Add "DPanel"
	controls:DockMargin( 5, 2, 5, 5 ) controls:Dock( BOTTOM )
	controls:SetHeight( 90 )
	
	local ctop = controls:Add "DPanel"
	ctop:DockMargin( 8, 5, 8, 0 ) ctop:Dock( FILL )
	
	local toggleb = ctop:Add "DButton"
	toggleb:DockMargin( 2, 2, 0, 2 ) toggleb:Dock( LEFT )
	toggleb:SetWidth( 24 ) toggleb:SetText "" toggleb:SetIcon "icon16/control_pause.png"
	toggleb.toggle = false
	toggleb.DoClick = function( self )
		if not IsValid( music.snd ) then return end
		
		self.toggle = ( not self.toggle )
		
		self:SetIcon( self.toggle and "icon16/control_play.png" or "icon16/control_pause.png" )
		
		if self.toggle then 
			music.snd:Pause() 
		else 
			music.snd:Play() 
		end
		
		music.paused = self.toggle
	end music.toggleb = toggleb
	music.Toggle = function() toggleb:DoClick() end
	
	local replay = ctop:Add "DButton"
	replay:DockMargin( 2, 2, 0, 2 ) replay:Dock( LEFT )
	replay:SetWidth( 24 ) replay:SetText "" replay:SetIcon "icon16/control_repeat.png"
	replay.toggle = false
	replay.DoClick = function( self )
		if not IsValid( music.snd ) then return end
		
		self.toggle = ( not self.toggle )
		
		self:SetIcon( self.toggle and "icon16/control_repeat_blue.png" or "icon16/control_repeat.png" )
		
		music.replay = self.toggle
	end
	
	local stop = ctop:Add "DButton"
	stop:DockMargin( 2, 2, 0, 2 ) stop:Dock( LEFT )
	stop:SetWidth( 24 ) stop:SetText "" stop:SetIcon "icon16/control_stop.png"
	stop.DoClick = function()
		if not IsValid( music.snd ) then return end
		if music.replay then replay:DoClick() end
		if music.paused then toggleb:DoClick() end
		
		music.snd:Stop()
	end
	
	local vol = ctop:Add "DNumSlider"
	vol:Dock( RIGHT ) vol:SetWidth( 200 ) vol:SetDark( true ) vol:SetText "Volume"
	vol:SetDecimals( 1 ) vol:SetMin( 0 ) vol:SetMinMax( 0, 3 )
	vol.OnValueChanged = function( self, val )
		music.volume = val
		
		if IsValid( music.snd ) then music.snd:SetVolume( val ) end
	end
	
	--
	
	local minfo = controls:Add "DPanel"
	minfo:DockMargin( 5, 5, 5, 5 ) minfo:Dock( BOTTOM )
	minfo:SetHeight( 50 )
	minfo.Paint = function( self, x, y )
		surface.SetDrawColor( 190, 190, 190 )
		surface.DrawRect( 0, 0, x, y )
	end
	
	local mtop = minfo:Add "DPanel"
	mtop:Dock( TOP ) mtop:DockMargin( 2, 2, 2, 2 )
	
	local mstime = mtop:Add "DLabel" music.mstime = mstime
	mstime:DockMargin( 5, 0, 0, 0 ) 	mstime:Dock( LEFT )
	mstime:SetWidth( 70 ) mstime:SetColor( gray )
	mstime:SetText "00:00 / 00:00"
	
	local mname = mtop:Add "DLabel" music.mname = mname
	mname:DockMargin( 2, 0, 2, 0 ) mname:Dock( FILL )
	mname:SetColor( gray )
	mname:SetText "..."
	
	--
	
	local mtime = minfo:Add "DPanel"
	mtime:Dock( FILL ) mtime:DockMargin( 2, 0, 2, 2 )
	
	mtime.Paint = function( self, x, y )
		surface.SetDrawColor( 120, 120, 120 )
		surface.DrawRect( 0, 0, x, y )
		
		surface.SetDrawColor( 150, 150, 150 )
		surface.DrawRect( 2, 2, x - 4, y - 4 )
		
		if not IsValid( music.snd ) then return end
		if music.paused then return end
		
		-- thx to: XZLTO to admins: размер делиш на количество секунд и умножаеш на текушие секунды

		local l = x / music.duration * ( RealTime() - music.starttime )
		l = math.min( l, x )
		
		surface.SetDrawColor( blue )
		surface.DrawRect( 2, 2, l - 4, y - 4 )
	end
	
	-- Search Page --
	
	local top = sp:Add "DPanel"
	top:DockMargin( 2, 2, 2, 0 )
	top:Dock( TOP )
	
	top:SetDrawBackground( false )
	
	local srch = top:Add "DTextEntry"
	srch:Dock( FILL )
	
	srch:SetPlaceholderText "Find music..."
	
	local srchb = top:Add "DButton"
	srchb:DockMargin( 2, 0, 0, 0 )
	srchb:Dock( RIGHT )
	srchb:SetText "Search"
	
	--
	
	local list = sp:Add "DScrollPanel"
	list:DockMargin( 2, 2, 2, 2 )
	list:Dock( FILL )
	
	--
	
	local function fnd( val )
		searchMusic( val, function( found )
			list:Clear()
			
			if isstring( found ) then
				if found == "cooldown" then
					nal( "Please wait!", NOTIFY_ERROR, 3 )	
				elseif found == "nothing" then
					nal( "There's nothing in the search entry!", NOTIFY_ERROR, 3 )
				end
				
				return	
			end
			
			for i, d in ipairs( found ) do
				createMPanel( list, i, d, false )
			end
		end )
	end
	
	srch.OnEnter = function( self, val )
		fnd( val )
	end
	
	srchb.DoClick = function( self )
		fnd( srch:GetValue() )	
	end
	
	-- Favorites Page
	
	local flist = fav:Add "DScrollPanel" fav_list = flist
	flist:DockMargin( 2, 2, 2, 2 )
	flist:Dock( FILL )
	
	local d = util.JSONToTable( file.Read( filen ) )
	for i, d in pairs( d ) do
		local tr = {
			id = d.id,
			url = i,
			author = d.author,
			name = d.name,
			duration = d.duration
		}
		
		addToFavorites( tr )
	end
end

list.Set(
	"DesktopWindows", tag, {
		title = "DPlayer",
		icon = "icon16/sound_add.png",
		onewindow = true,
		init = spawnpanel
	}
)

RunConsoleCommand "spawnmenu_reload"