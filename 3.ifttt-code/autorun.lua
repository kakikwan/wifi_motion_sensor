--email: kaki.kwan@gmail.com
--last modified: 16 Dec 2016
--application: provide a web interface to set IFTTT maker
--push button and clear IFTTT channel setting

--settingpage1
newuser = false
ready = false
event = ""
key = ""
ssid = ""
pass = ""
url = ""
--settingpage2
offset = 0
delay = 0
lasttrig = 0
sch_start = {0,0,0,0,0,0,0}
sch_end = {0,0,0,0,0,0,0}

s1=0
s2=0

ir = 5
gpio.mode(ir,gpio.INT)
btn = 2
gpio.mode(btn,gpio.INT,gpio.PULLUP)
--led1 is high active, led2 is low active
led1 = 1
gpio.mode(led1,gpio.OUTPUT)
led2 = 4
gpio.mode(led2,gpio.OUTPUT)

--send http to ifttt channel
function ir_action()
	sec = rtctime.get()
	weekday = math.floor(((sec - 259200)% 604800)/ 86400)
	if weekday == 0 then weekday = 7 end
	mins = math.floor((sec % 86400)/ 60)
	if  (mins>=sch_start[weekday]) and (mins<=sch_end[weekday]) then
		work = true
		if sec < (lasttrig+delay*60) then 
			work = false
			print("trig too fast")
		end
	else
		work = false
		print("not in working schedule")
	end
	
	if (work) then
		print("sending request to IFTTT")
		lasttrig = sec
		--LED1 blink 0.3s
		gpio.write(led1,gpio.HIGH)
		tmr.delay(300000)
		gpio.write(led1,gpio.LOW)
		if (ready) then
			ready = false
			http.post(url,nil,nil, function(code, data)
			if (code < 0) then
				ready = true
				gpio.write(led2,gpio.LOW)
			else
				ready = true
				gpio.write(led2,gpio.HIGH)
			end
			end)
		end
	end
end

function btn_action()
	file.remove("ifttt.txt")
	node.restart()
end
gpio.trig(btn,"down",btn_action)

if (not file.exists("ifttt.txt")) then
	newuser = true
end

function update_time()
	sntp.sync('time1.google.com',
	function(sec,usec,server)
		sec = sec + offset * 3600
		rtctime.set(sec, 0)
		gpio.write(led2,gpio.HIGH)
		ready = true
	end,
	function()
		ready = false
		gpio.write(led2,gpio.LOW)
		update_time()
	end)	
end

if (not newuser) then
	file.open("ifttt.txt", "r")
	event = file.readline()
	keys = file.readline()
	ssid = file.readline()
	pass = file.readline()
	file.close()
	if (wifi.getmode() ~= 1) then
		if (ssid == nil) then ssid = "" else ssid = string.sub(ssid,1,string.len(ssid)-1) end
		if (pass == nil) then pass = "" else pass = string.sub(pass,1,string.len(pass)-1) end
		wifi.setmode(wifi.STATION)
		wifi.sta.config(ssid,pass)
	end
	if ((event == nil) or (keys == nil)) then
		file.remove("ifttt.txt")
		newuser = true
	else
		event = string.sub(event,1,string.len(event)-1)
		keys = string.sub(keys,1,string.len(keys)-1)
		url = "http://maker.ifttt.com/trigger/" .. event .. "/with/key/" .. keys
		gpio.trig(ir, "up",ir_action)
		ready = true
	end
	
	--load working schedule
	if (file.exists("ifttt-time.txt")) then
		file.open("ifttt-time.txt", "r")
		for i=1,7 do 
			time_s = file.readline()
			time_e = file.readline()
			sch_start[i] = tonumber(time_s)
			sch_end[i] = tonumber(time_e)
		end
		offset_s = file.readline()
		delay_s = file.readline()
		offset = tonumber(offset_s)
		delay = tonumber(delay_s)
		file.close()
	else
		file.remove("ifttt.txt")
		file.remove("ifttt-time.txt")
		node.restart()
	end
	
	update_time()
	
end



if (newuser) then
	wifi.setmode(wifi.SOFTAP)
	wifi.ap.config({ssid="IFTTT Setting", auth=wifi.OPEN})
	  
	srv = net.createServer(net.TCP)
	srv:listen(80, function(conn)
	conn:on("receive", function(sck, req)
	print(req)
	local response = {}
	
	if string.find(req, "restart") then
		--web restart request
		response[#response + 1] = "HTTP/1.1 200 OK\nContent-Length: 0\nConnection: close\n\n"
		node.restart()
	elseif (string.find(req, "GET /??ssid=") or string.find(req, "GET /?ssid=")) then
		--web setting upload
		s1 = string.find(req, "ssid=")
		s2 = string.find(req, "&", s1)
		ssid = string.sub(req,s1+5,s2-1)
		s1 = string.find(req, "pass=")
		s2 = string.find(req, "&", s1)
		pass = string.sub(req,s1+5,s2-1)
		s1 = string.find(req, "even=")
		s2 = string.find(req, "&", s1)
		event = string.sub(req,s1+5,s2-1)
		s1 = string.find(req, "keys=")
		s2 = string.find(req, " ", s1)
		keys = string.sub(req,s1+5,s2-1)
		if ((ssid~="") and (event~="") and (keys~="")) then
			--save
			file.open("ifttt.txt", "w")
			file.writeline(event)
			file.writeline(keys)
			file.writeline(ssid)
			if (pass~="") then file.writeline(pass) end
			file.close()
			--send page2 to client
			response[#response + 1] = "HTTP/1.1 200 OK\nConnection: close\n\n"
			file.open("settingpage2.html", "r")
			temp = file.readline()
			while temp do
				response[#response + 1] = temp
				temp = file.readline()
			end
			file.close()
		else
			--send page1 to client
			response[#response + 1] = "HTTP/1.1 301 Moved Permanently\nLocation: http://192.168.4.1\n\n"
		end
	elseif (string.find(req, "GET /??mon1=") or string.find(req, "GET /?mon1=")) then
		file.open("ifttt-time.txt", "w")
		s1 = string.find(req, "mon1=")
		for i=0,6 do
			file.writeline(tonumber(string.sub(req, s1+5+i*26, s1+6+i*26)) * 60 + tonumber(string.sub(req, s1+10+i*26, s1+11+i*26)))
			file.writeline(tonumber(string.sub(req, s1+18+i*26, s1+19+i*26)) * 60 + tonumber(string.sub(req, s1+23+i*26, s1+24+i*26)))
		end
		s1 = string.find(req,"offset=")
		s2 = string.find(req,"&",s1)
		file.writeline(string.sub(req, s1+7, s2-1))
		s1 = string.find(req,"delay=")
		s2 = string.find(req," ",s1)
		file.writeline(string.sub(req, s1+6, s2-1))
		file.close()
		--send page3 to client
		response[#response + 1] = "HTTP/1.1 200 OK\nConnection: close\n\n"
		file.open("settingpage3.html", "r")
		temp = file.readline()
		while temp do
			response[#response + 1] = temp
			temp = file.readline()
		end
		file.close()
		
	elseif string.find(req, "GET / HTTP") then
		--get
		response[#response + 1] = "HTTP/1.1 200 OK\nConnection: close\n\n"
		file.open("settingpage1.html", "r")
		temp = file.readline()
		while temp do
			response[#response + 1] = temp
			temp = file.readline()
	end
		file.close()
	elseif string.find(req, "favicon") then
		response[#response + 1] = "HTTP/1.1 200 OK\nContent-Length: 0\nConnection: close\n\n"
	else
		response[#response + 1] = "HTTP/1.1 301 Moved Permanently\nLocation: http://192.168.4.1\n\n"
	end
	
	local function send(sk)
		if #response > 0
			then sk:send(table.remove(response, 1))
		else
			sk:close()
			response = nil
		end
    end
    sck:on("sent", send)
    send(sck)
	end)
	end)
end

  
