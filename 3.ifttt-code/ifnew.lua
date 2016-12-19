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
