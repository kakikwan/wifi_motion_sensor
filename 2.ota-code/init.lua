--email: kaki.kwan@gmail.com
--last modified: 3 Dec 2016
--application: provide a web interface to upload or delete file in ESP8266
--push button and power on to enter OTA mode(file update)

gpio.mode(2,gpio.INPUT,gpio.PULLUP)

if (gpio.read(2) == 0) then
--AP mode, IP:192.168.4.1
wifi.setmode(wifi.SOFTAP)
wifi.ap.config({ssid="ota", auth=wifi.OPEN})

newfile = ""
writingfile = false

srv = net.createServer(net.TCP, 30)
srv:listen(80, function(conn)
	conn:on("receive", function(sck, req)
	print(req)--for debug use
	--http receive upload file
	s1 = string.find(req, "***file***")
	if (s1 or writingfile) then
		if (s1) then
			s2 = string.find(req, "ename=\"", s1+10)
			s3 = string.find(req, "\"", s2+7)
			newfile = string.sub(req, s2+7, s3-1)
			t0 = string.find(req, "-Type:", s3)
			t1 = string.find(req, "\n", t0+7)+3
			t2 = string.find(req, "------Web", t1)
			if (t2) then t2 = t2-3 else t2 = string.len(req) writingfile = true end
			if ((newfile ~= "init.lua") and (newfile ~= "ota1.html")) then file.open(newfile, "w+") end
		else
			t1 = 0
			t2 = string.find(req, "------Web", t1)
			if (t2) then t2 = t2-3 writingfile = false else t2 = string.len(req) end
			file.open(newfile, "a+")
		end
			if ((newfile ~= "init.lua") and (newfile ~= "ota1.html")) then file.write(string.sub(req, t1, t2)) end
			file.close()
	end
	
	--delete file
	if (string.find(req, "?delete=")) then
	  s1 = string.find(req, "?delete=")
	  s2 = string.find(req, " HTTP/")
	  if s2 > s1 then	
		filename = string.sub(req, s1+8, s2-1)
		if (file.exists(filename) and (filename ~= "init.lua") and (filename ~= "ota1.html")) then file.remove(filename) end
	  end
	end
	
	--response website
	if (string.find(req, "HTTP") and writingfile==false) then
		local response = {}  
		if not(string.find(req, "POST")) then
			response[#response + 1] = "HTTP/1.1 200 OK\nConnection: Closed\n\n"
			file.open("ota1.html", "r")
			temp = file.readline()
			while temp do
				response[#response + 1] = temp
				temp = file.readline()
			end
			file.close()
			for k,v in pairs(file.list()) do l = string.format("%-15s",k) response[#response + 1] = l .. "<br>" end
			response[#response + 1] = "</p></body></html>"
		else
			response[#response + 1] = "HTTP/1.1 200 OK\nConnection: Closed\n\n"
			response[#response + 1] = "<head> <meta http-equiv=\"refresh\" content=\"2\">Auto refresh in 2 seconds......</head>"
		end
	  
      -- sends and removes the first element from the 'response' table
		local function send(sk)
			if #response > 0
				then sk:send(table.remove(response, 1))
		else
			sk:close()
			response = nil
		end
	end
		-- triggers the send() function again once the first chunk of data was sent
		sck:on("sent", send)
		send(sck)
	end
	--end response website
	end)
end)


else
--not pressed button
if (file.exists("autorun.lua")) then
	dofile("autorun.lua")
elseif (file.exists("autorun.lc")) then
	dofile("autorun.lc")
end

end

