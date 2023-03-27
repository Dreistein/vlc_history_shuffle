
local played = {} -- holds all music items form the current playlist
local store = {}	-- holds all music items from the database

-- constant for seconds in one day
local day_in_seconds = 60*60*24

 -- used in playing_changed
 -- the event gets triggered multiple times and we don't want to
 -- set the rating down multiple times
local last_played = ""

-- prefix to all logs
local prefix = "[HShuffle] "

-- path to data file
local data_file = ""

function descriptor()
  return {
    title = "History Shuffle",
    version = "1.0.1", 
    shortdesc = "Shuffle Playlist", 
    description = "Shuffles playlists based on the liking of the songs",
    author = "Stefan Steininger", 
    capabilities = { "playing-listener"}
  }
end

function activate()
	vlc.msg.info(prefix ..  "starting")

	-- init the random generator
	-- not crypto secure, but we have no crypto here :)
	math.randomseed( os.time() )

	path_separator = ""
	if string.find(vlc.config.userdatadir(), "\\") then
		vlc.msg.info(prefix .. "windows machine")
		path_separator = "\\"
	else
		vlc.msg.info(prefix .. "unix machine")
		path_separator = "/"
	end

	data_file = vlc.config.userdatadir() .. path_separator .. "better_playlist_data.csv"
	vlc.msg.info(prefix ..  "using data file " .. data_file)
    
    init_playlist()
    randomize_playlist()
    vlc.playlist.random("off")
end

function deactivate()
	vlc.msg.info(prefix ..  "deactivating.. Bye!")
end

-- -- Helpers -- --

-- loads the database and initializes the played variable with the like ratings
-- increases the rating of a song by the days since it was last updated
-- if there are new songs or changes, it adds them to the database file
function init_playlist( )
	vlc.msg.dbg(prefix .. "initializing playlist")

	-- load playlist items from file
	load_data_file()

	local time = os.time() -- current time for comparison of last played
	local playlist = vlc.playlist.get("playlist",false).children
	local changed = false -- do we have any updates for the db ?

	for i,path in pairs(playlist) do
		-- decode path and remove escaping
		path = path.item:uri()
		path = vlc.strings.decode_uri(path)

		-- check if we have the song in the database
		-- and copy the like else create a new entry
		if store[path] then
			played[path] = store[path].like
		else
			played[path] = 100
			store[path] = {like=100,time=time}
			changed = true
		end

		-- increase the rating after some days
		local elapsed_days = os.difftime(time, store[path].time) / day_in_seconds
		elapsed_days = math.floor(elapsed_days)
		local new_like = store[path].like + elapsed_days
		if elapsed_days >= 1 then
			if new_like > 200 then
				new_like = 200
			end
			store[path].like = new_like
			store[path].time = store[path].time + elapsed_days*day_in_seconds
			changed = true
		end
	end

	-- save changes
	if changed then
		save_data_file()
	end
end

-- randomizes the playlist based on the ratings
-- higher ratings have a higher chance to be higher up
-- in the playlist
function randomize_playlist( )
	vlc.msg.dbg(prefix ..  "randomizing playlist")
	vlc.playlist.stop() -- stop the current song, takes some time

	-- create a table with all songs and the liking being the probability over cumulative liking
	local queue = {}

	-- add songs to queue
	local cum_sum = 0
	for path,like in pairs(played) do
		item = {}
		item["path"] = path
		item["probability"] = like
		item["inserted"] = false
		table.insert(queue, item)
		cum_sum = cum_sum + like
	end

	-- sort in ascending order
	table.sort(queue, function(a,b) return a['probability'] < b['probability'] end)

	-- clear the playlist before adding items back
	vlc.playlist.clear()

	-- loop until all items are added to the playlist
	-- takes n^2 time -> could be improved
	local to_insert = {}
	while #queue ~= #to_insert do
		-- get random number in the range
		local p = math.random(0, cum_sum)
		local probability = 0
		-- iterate over items until cumulative probability is greater or equal than the random number
		for k=1,#queue do
			item = queue[k]
			-- skip items that are already added
			if not item.inserted then
				probability = probability + item["probability"]
				if p <= probability then
					table.insert(to_insert, item)
					queue[k].inserted = true
					cum_sum = cum_sum - item["probability"]
					break
				end
			end
		end
	end
	vlc.playlist.enqueue(to_insert)
	
	-- wait until the current song stops playing
	-- to start the song at the beginning of the playlist
	while vlc.input.is_playing() do
	end
	vlc.playlist.play()
end

-- finds the last occurence of findString in mainString
-- and returns the index
-- otherwise nil if not found
function find_last(mainString, findString)
    local reversed = string.reverse(mainString)
    local last = string.find(reversed, findString)
    if last == nil then
        return nil
    end
    return #mainString - last + 1
end

-- -- IO operations -- --

-- Loads the data from
function load_data_file()

	-- open file
	local file,err = io.open(data_file, "r")
	store = {}
	if err then
		vlc.msg.warn(prefix .. "data file does not exist, creating...")
		file,err = io.open(data_file, "w");
		if err then
			vlc.msg.err(prefix .. "unable to open data file.. exiting")
			vlc.deactivate()
			return
		end
	else
		-- file successfully opened
		vlc.msg.info(prefix .. "data file successfully opened")
		local count = 0
		for line in file:lines() do
			-- csv layout is `path,like,timestamp`
			local num_split = find_last(line, ",")
			local date = tonumber(string.sub(line, num_split+1))

			if date == nil then
				vlc.msg.warn(prefix .. "date nil: " .. line .. " => " .. string.sub(line, 1, num_split-1))
			end
			
			line = string.sub(line, 0, num_split-1)
			num_split = find_last(line, ",")
			local path = string.sub(line, 1, num_split-1)
			local like = tonumber(string.sub(line, num_split+1))

			if like == nil then
				like = 100
			end

			if date == nil then
				date = os.time()
			end
			if path then
				count = count + 1
				store[path] = {like=like, time=date}
			end
		end
		vlc.msg.info(prefix .. "processed " .. count)
	end
	io.close(file)
end

function clean_csv(text_string)
	return '"' .. text_string:gsub('"', '""') .. '"'
end

function save_data_file()
	local file,err = io.open(data_file, "w")
	if err then
		vlc.msg.err(prefix .. "Unable to open data file.. exiting")
		vlc.deactivate()
		return
	else
		for path,item in pairs(store) do
			file:write(clean_csv(path)..",")
			file:write(store[path].like..",")
			file:write(store[path].time.."\n")
		end
	end
	io.close(file)
end

-- -- Listeners -- --

-- called when the playing status changes
-- detects if playing items are skipped or ending normally
-- derates the songs accordingly
function playing_changed()

	local item = vlc.input.item()

	local time = vlc.var.get(vlc.object.input(), "time")
	local total = item:duration()
  	local path = vlc.strings.decode_uri(item:uri())

  	if last_played == path then
  		return
  	end

  	-- when time is 0, the song is the new song
	if time > 0 then
		vlc.msg.info(prefix ..  "song ended: " .. item:name())
  		last_played = path

		time = math.floor(time / 1000000)
	  	total = math.floor(total)
	  	
	  	-- when the current time == total time, 
	  	-- then the song ended normally
	  	-- if there is remaining time, the song was skipped
	  	if time < total then

	  		-- % of the total time the song was playing
	  		local ratio = time/total*100
			vlc.msg.info(prefix ..  "skipped song at " .. ratio .. "%")
			
			if ratio > 90 then
				ratio = 90
			end
			
			-- subtract the remaining % of the playing song ±3
			ratio = ratio + math.random(-3,3)
			store[path].like = math.floor(ratio)
		else
			-- song ended normally, set between 87 and 93
			vlc.msg.info(prefix ..  "song ended normally")
			local previous_like = 100
			if store[path].like < 100 then
				previous_like = store[path].like
			end
			store[path].like = math.floor(previous_like - 7 - math.random(0,6))
	  	end

	  	-- check if we didn't remove too much
	  	if store[path].like < 0 then
	  		store[path].like = 0
	  	end
	  	
	  	-- save the song in the database with updated time
	  	store[path].time = os.time()
	  	save_data_file()
	end
end

function meta_changed() end
