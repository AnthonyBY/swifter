//
//  main.swift
//  SwifterOSX
//  Copyright (c) 2015 Damian Kołakowski. All rights reserved.
//

import Foundation
import Swifter

do {
    
    let httpServer = HttpServer()
    var openPorts : Set = [9080]
    
    httpServer.GET["/startSession"] = { r in
        do {
            var randomPort : Int
            repeat {
                randomPort = Int(arc4random_uniform(8999) + 1000)
            } while (openPorts.contains(randomPort));
            openPorts.insert(randomPort)
            
            startWebsocketSession(port: randomPort)
            return HttpResponse.ok(.text(String(randomPort)))
        }
    }
    
    func startWebsocketSession(port: Int) {
        let stompServer = mockServer()
        var currentWebsocketSession = WebSocketSession(Socket(socketFileDescriptor: Int32(port)))
        stompServer["/stomp"] = websocket({ (session, text) in
            print("text - \(text)")
            
            currentWebsocketSession = session;
            for command in stompServer.responseCommandJson {
                if text == command.key {
                    for responseCommand in command.value {
                        session.writeFrame(ArraySlice(responseCommand.utf8), WebSocketSession.OpCode.text)
                    }
                }
            }
        }, { (session, binary) in
            session.writeBinary(binary)
        })
        
        stompServer.POST["/configure"] = { r in
            //Confgure JSON example handlers for mock socket server
            do {
                let json = try JSONSerialization.jsonObject(with: Data(r.body), options: [])
                if let object = json as? [String: Any] {
                    stompServer.responseCommandJson = object as! [String : [String]]
                    print(object)
                } else {
                    return HttpResponse.badRequest(HttpResponseBody.text("Incorrect JSON format. Expected format: [String : [String]]"))
                }
            } catch {
                return HttpResponse.badRequest(HttpResponseBody.text(error.localizedDescription))
            }
            
            return HttpResponse.ok(.html(""))
        }
        
        stompServer.POST["/sendSequence"] = { r in
            do {
                let json = try JSONSerialization.jsonObject(with: Data(r.body), options: [])
                if let object = json as? [[String:Any]] {
                    print(object)
                    for message in object {
                        let delay = message["delay"] as! Int
                        let responseMessage = message["message"] as! String
                        
                        let deadlineTime = DispatchTime.now() + .seconds(delay)
                        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                            currentWebsocketSession.writeFrame(ArraySlice(responseMessage.utf8), WebSocketSession.OpCode.text)
                            print("message - \(message)")
                            print("timer fired after delay - \(delay)")
                        }
                    }
                } else {
                    return HttpResponse.badRequest(HttpResponseBody.text("Incorrect JSON format. Expected format: [String : [String]]"))
                }
            } catch {
                return HttpResponse.badRequest(HttpResponseBody.text(error.localizedDescription))
            }
            
            return HttpResponse.ok(.html(""))
        }
        
        stompServer.GET["/stopSession"] = { r in
            stopMockInstance()
            return HttpResponse.ok(.html(""))
        }
        
        if #available(OSXApplicationExtension 10.10, *) {
            do {
                print("WebSocket instanse for port - \(port) have started")
                try stompServer.start(in_port_t(port), forceIPv4: true)
            } catch {
                print("WebSocket instanse for port - \(port) have failed")
            }
        }
        
        let stopServerInTime = DispatchTime.now() + .seconds(180)
        DispatchQueue.main.asyncAfter(deadline: stopServerInTime) {
            stopMockInstance()
        }
        
        func stopMockInstance() {
            print("Server with port - \(port) have been stopped")
            openPorts.remove(port)
            stompServer.stop()
        }
    }
    
    if #available(OSXApplicationExtension 10.10, *) {
        try httpServer.start(9080, forceIPv4: true)
    }
    
    print("HTTP Server has started ( port = \(try httpServer.port()) ). Try to connect now...")
    
    RunLoop.main.run()
    
} catch {
    print("Server start error: \(error)")
}
