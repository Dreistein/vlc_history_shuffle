
played = {} -- holds all music items form the current playlist
store = {}	-- holds all music items from the database
 -- used in playing_changed
 -- the event gets triggered multiple times and we don't want to
 -- set the rating down multiple times
last_played = ""

-- prefix to all logs
prefix = "[HShuffle] "

-- path to data file
data_file = ""

function descriptor()
  return {
    title = "History Shuffle",
    version = "1.0.0", 
    shortdesc = "Shuffle Playlist", 
    description = "Shuffles playlists based on the liking of the songs",
    author = "Stefan Steininger", 
    capabilities = { "playing-listener"}
  }
end

function activate()
	vlc.msg.info(prefix ..  "starting")

	data_file = vlc.config.userdatadir() .. "/better_playlist_data.csv"
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
		local elapsed_days = os.difftime(time, store[path].time) / 60 / 60 / 24
		elapsed_days = math.floor(elapsed_days)
		local new_like = store[path].like + elapsed_days
		if elapsed_days >= 1 then
			if new_like > 200 then
				new_like = 200
			end
			store[path].like = new_like
			store[path].time = time
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

	-- create a table with the index being the rating
	local bins = {}
	for i=0,200 do
		bins[i] = Queue.new()
	end

	-- add song to appropriate bin
	local num_items = 0
	for path,like in pairs(played) do
		Queue.enqueue(bins[like], path)
		num_items = num_items + 1
	end

	-- shuffle non-empty bins
	-- to randomize the items in the same bin
	for i=0,200 do
		if Queue.size(bins[i]) > 0 then
			Queue.shuffle(bins[i])
		end
	end

	-- clear the playlist before adding items back
	vlc.playlist.clear()
	local mult = 1 -- factor to increase chance over time (to speed things up)
	local inserted = 0 -- number of inserted songs

	-- loop until all items are added to the playlist
	while inserted < num_items do

		-- go through all non-empty bins and start adding songs
		-- the rating (bin index) is the threshold for which the
		-- song gets added if its bigger than a random number [0,100]
		-- if the threshold is not met, the next bin gets selected
		for i=200,0,-1 do

			local continue = Queue.size(bins[i]) > 0
			local to_insert = {}
			
			while continue do
				local r = math.random(100)
				if (i+1)*mult >= r then -- check if random num meets threshold
					local item = Queue.dequeue(bins[i])
					item = {["path"] = item}
					table.insert(to_insert, item)
					inserted = inserted + 1
				else
					continue = false
				end
				if Queue.size(bins[i]) <= 0 then
					continue = false
				end
			end
			-- add all items to the playlist, that met the threshold
			vlc.playlist.enqueue(to_insert)
		end

		-- we went through all bins,
		-- increase the chance factor for the next round
		mult = mult*1.2
	
	end
	
	-- wait until the current song stops playing
	-- to start the song at the beginning of the playlist
	while vlc.input.is_playing() do
	end
	vlc.playlist.play()
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
		for line in file:lines() do
			-- csv layout is `path,like,timestamp`
			local num_split = string.find(line, ",")
			local path = string.sub(line, 1, num_split-1)
			
			line = string.sub(line, num_split+1)
			num_split = string.find(line, ",")
			local like = tonumber(string.sub(line, 1, num_split-1))
			local date = tonumber(string.sub(line, num_split+1))

			if like == nil then
				like = 100
			end

			if date == nil then
				date = os.time()
			end
			if path then
				store[path] = {like=like, time=date}
			end
		end
	end
	io.close(file)
end

function save_data_file()
	local file,err = io.open(data_file, "w")
	if err then
		vlc.msg.err("[Playlist] unable to open data file.. exiting")
		vlc.deactivate()
		return
	else
		for path,item in pairs(store) do
			file:write(path..",")
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
			ratio = store[path].like - (100 - ratio - math.random(-3,3))
			store[path].like = math.floor(ratio)
		else
			-- song ended normally, remove between 7 and 13 from the rating
			vlc.msg.info(prefix ..  "song ended normally")
			store[path].like = store[path].like - 7 - math.random(0,6)
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

-- -- Queue implementation -- --
-- Idea from https://www.lua.org/pil/11.4.html

Queue = {}
function Queue.new ()
  return {first = 0, last = -1}
end

function Queue.enqueue (q, value)
  local last = q.last + 1
  q.last = last
  q[last] = value
end

function Queue.dequeue (q)
  local first = q.first
  if first > q.last then error("queue is empty") end
  local value = q[first]
  q[first] = nil
  q.first = first + 1
  return value
end

function Queue.size(q)
	return q.last - q.first + 1
end

-- implements the fisher yates shuffle on the queue
-- based on the wikipedia page
function Queue.shuffle(q)
	local first = q.first
	local last = q.last
	if first > last then error("queue is empty") end
	if first == last then return end
	for i=first,last-1 do
		local r = math.random(i,last-1)
		local temporary = q[i]
		q[i] = q[r]
		q[r] = temporary
	end
end