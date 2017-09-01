//
//  main.swift
//  SwifterOSX
//  Copyright (c) 2015 Damian Kołakowski. All rights reserved.
//

import Foundation
import Swifter

func randomBaseUrlString() -> String {
    
    let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    let len = UInt32(letters.length)
    
    var randomString = ""
    
    for _ in 0 ..< 10 {
        let rand = arc4random_uniform(len)
        var nextChar = letters.character(at: Int(rand))
        randomString += NSString(characters: &nextChar, length: 1) as String
    }
    
    return randomString
}

do {
    
    let httpServer = HttpServer()
    
    httpServer.GET["/startSession"] = { r in
        do {
            let randomToken = randomBaseUrlString()
            startWebsocketSession(token: randomToken)
            return HttpResponse.ok(.text(randomToken))
        }
    }
    
    func startWebsocketSession(token: String!) {
        let stompServer = mockServer()
        var currentWebsocketSession = WebSocketSession(Socket(socketFileDescriptor: 9090))
        stompServer["/stomp?\(token!)"] = websocket({ (session, text) in
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
        
        stompServer.POST["/configure?\(token!)"] = { r in
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
        
        stompServer.POST["/sendSequence?\(token!)"] = { r in
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
        
        stompServer.GET["/stopSession?\(token!)"] = { r in
            stompServer.responseCommandJson = [String: [String]]()
            return HttpResponse.ok(.html(""))
        }
        
        if #available(OSXApplicationExtension 10.10, *) {
            do {
                print("WebSocket instanse for token - \(token) have been started")
                try stompServer.start(9090, forceIPv4: true)
            } catch {
                print("Start server with token - \(token) have failed")
            }
        }
        
        let stopServerInTime = DispatchTime.now() + .seconds(180)
        DispatchQueue.main.asyncAfter(deadline: stopServerInTime) {
            print("Server with token - \(token) have been stopped")
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
