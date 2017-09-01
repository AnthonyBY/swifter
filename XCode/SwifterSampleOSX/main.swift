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
    
    let server = mockServer()
    var currentWebsocketSession = WebSocketSession(Socket(socketFileDescriptor: 9080))
    
    server.GET["/setupWebsocketBaseUrl"] = { r in
        do {
            let randomString = randomBaseUrlString()
           
            server["/\(randomString)"] = websocket({ (session, text) in
                print("text - \(text)")
                currentWebsocketSession = session;
                for command in server.responseCommandJson {
                    if text == command.key {
                        for responseCommand in command.value {
                            session.writeFrame(ArraySlice(responseCommand.utf8), WebSocketSession.OpCode.text)
                        }
                    }
                }
            }, { (session, binary) in
                session.writeBinary(binary)
            })
        return HttpResponse.ok(.text("ws://localhost:9080/\(randomString)"))
        }
    }
    
    
    server.POST["/sendSequence"] = { r in
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
    
    
    if #available(OSXApplicationExtension 10.10, *) {
        try server.start(9080, forceIPv4: true)
    }
    
    print("Server has started ( port = \(try server.port()) ). Try to connect now...")
    
    RunLoop.main.run()
    
} catch {
    print("Server start error: \(error)")
}
