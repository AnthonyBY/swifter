//
//  main.swift
//  SwifterOSX
//  Copyright (c) 2015 Damian Kołakowski. All rights reserved.
//

import Foundation
import Swifter

do {
    let server = mockServer()
    
    server["/stomp"] = websocket({ (session, text) in
        for command in server.responseCommandJson {
            if text.contains(command.key) {
                for responseCommand in command.value {
                    session.writeFrame(ArraySlice(responseCommand.utf8), WebSocketSession.OpCode.text)
                }
            }
        }
    }, { (session, binary) in
        session.writeBinary(binary)
    })
    
    
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
