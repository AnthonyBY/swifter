//
//  main.swift
//  SwifterOSX
//  Copyright (c) 2015 Damian Kołakowski. All rights reserved.
//

import Foundation
import Swifter

do {
    let server = mockServer()
    var currentWebsocketSession = WebSocketSession(Socket(socketFileDescriptor: 9080))
    
    server["/stomp"] = websocket({ (session, text) in
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
    
    
    server.POST["/sendSequence"] = { r in
        var responseMessage = "MESSAGE\nexpires:0\ndestination:/user/topic/DEVICE.B8BCA60F-37EC-485A-8832-BC275B710BA8\nsubscription:sub-0\npriority:4\nmessage-id:ID\\cip-172-16-179-96.eu-west-1.compute.internal-40273-1495614934523-5\\c1\\c-1\\c1\\c10674\ncontent-type:application/json;charset=UTF-8\ntimestamp:1500371504833\ncontent-length:64\n\n{\"messageType\":\"SubscriptionAccepted\",\"vin\":\"SALCA2AG0HH671076\"}"
        
        if #available(OSXApplicationExtension 10.12, *) {
            let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { (timer) in
                // do stuff 3 seconds later
                 currentWebsocketSession.writeFrame(ArraySlice(responseMessage.utf8), WebSocketSession.OpCode.text)
            }
        }
        
        return HttpResponse.ok(.html(""))
    }
    
    
    
    
    if #available(OSXApplicationExtension 10.10, *) {
        try server.start(9080, forceIPv4: true)
    } else {
        // Fallback on earlier versions
    }
    
    print("Server has started ( port = \(try server.port()) ). Try to connect now...")
    
    RunLoop.main.run()
    
} catch {
    print("Server start error: \(error)")
}
