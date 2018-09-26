//
//  MockServer.swift
//  SwifterSampleOSX
//
//  Created by Anthony Marchenko on 9/26/18.
//  Copyright © 2018 Damian Kołakowski. All rights reserved.
//

import Foundation

public func mockServer() -> HttpServer {
    
    let server = HttpServer()
    
    server.POST["/configure"] = { r in
        //Confgure JSON example handlers for mock socket server
        do {
            let json = try JSONSerialization.jsonObject(with: Data(r.body), options: [])
            if let object = json as? [String: Any] {
                server.responseCommandJson = object as! [String : [String]]
                print(object)
            } else {
                return HttpResponse.badRequest(HttpResponseBody.text("Incorrect JSON format. Expected format: [String : [String]]"))
            }
        } catch {
            return HttpResponse.badRequest(HttpResponseBody.text(error.localizedDescription))
        }
        
        return HttpResponse.ok(.html(""))
    }
    
    server.GET["/resetConfiguration"] = { r in
        server.responseCommandJson = [String: [String]]()
        return HttpResponse.ok(.html(""))
    }
    return server
    
}
