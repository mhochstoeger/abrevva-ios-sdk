//
//  NfcSession.swift
//  Plugin
//
//  Created by Matthias on 08.01.24.
//  Copyright © 2024 Max Lynch. All rights reserved.
//

import Foundation
import CoreNFC
import Capacitor
import CocoaMQTT

public class NfcSession: CAPPlugin, NFCTagReaderSessionDelegate {
    
    let GET_VERSION_REQ: NFCISO7816APDU = NFCISO7816APDU.init(instructionClass: 0x90, instructionCode: 0x60, p1Parameter: 0x00, p2Parameter: 0x00, data: Data(), expectedResponseLength: 256)
    let GET_VERSION_AF_REQ: NFCISO7816APDU = NFCISO7816APDU.init(instructionClass: 0x90, instructionCode: 0xAF, p1Parameter: 0x00, p2Parameter: 0x00, data: Data(), expectedResponseLength: 256)
    
    var readerSession: NFCTagReaderSession?
    var nfcTagReaderSession: NFCTagReaderSession?
    var nfcTag: NFCTag?
   // var response: (Data, UInt8, UInt8)?
    var identifier: String?
    var historicalBytes: String?
    var mqtt5Client: Mqtt5Client?
    
    override init() {
        super.init()
    }
    
    public func beginSession() {
        readerSession = NFCTagReaderSession(pollingOption: [.iso14443, .iso15693, .iso18092], delegate: self, queue: nil)
        readerSession?.alertMessage = "Hold your iPhone near an NFC tag."
        readerSession?.begin()
    }
    
    public func getNfcTagReaderSession() -> NFCTagReaderSession? {
        guard nfcTagReaderSession != nil else {
            return nil
        }
        return nfcTagReaderSession
    }
    
    public func setMqtt5Client(mqtt5: Mqtt5Client) {
        self.mqtt5Client = mqtt5
    }
    
    
    public func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("didInvalidateWithError")
        self.mqtt5Client?.publishMessage(topic: "readers/1/\(self.mqtt5Client?.getClientID() ?? "")", message: Message(t: "ky", e: "off", oid: self.identifier!, atr:self.historicalBytes!))
        session.invalidate()
    }
    

    public func send( apdu: NFCISO7816APDU ) async -> (Data, UInt8, UInt8)? {

        do {
            switch self.nfcTag {
            case let .iso7816(tag):
                var resp = try await tag.sendCommand(apdu: apdu)
                return resp
            case let .miFare(tag):
                var resp = try await tag.sendMiFareISO7816Command(apdu)
                print("done sending")
                return resp
            default:
                return nil
            }
        }
        catch {
                print("ERROR \(error)")
                return nil
            }
    }
    
    public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        print("reached did Detect")
        if tags.count > 1 {
            print("More than 1 tags was found. Please present only 1 tag.")
            return
        }
        
        self.historicalBytes = nil
        self.nfcTag = tags.first!
        
        switch tags.first! {
        case let .iso7816(tag):
            self.historicalBytes = tag.historicalBytes?.hexEncodedString()
        case let .miFare(tag):
            self.historicalBytes = tag.historicalBytes?.hexEncodedString()
        default:
            session.invalidate(errorMessage: "Tag not valid.")
            return
        }
        
        session.connect(to: self.nfcTag!)  {error in
            if error != nil {
                session.invalidate(errorMessage: "Connection error. Please try again.")
                return
            }
            
            self.sendGetVersionRequest(completion: {
                print("reached completion closure")
                if (self.identifier == nil || self.historicalBytes == nil){
                    session.invalidate(errorMessage: "Tag not valid.")
                    return
                }
                session.alertMessage = "Tag read success."
                self.mqtt5Client?.publishMessage(topic: "readers/1/\(self.mqtt5Client?.getClientID() ?? "")", message: Message(t: "ky", e: "on", oid: self.identifier!, atr:self.historicalBytes!))
            })

        }
    }
    
    public func sendGetVersionRequest(completion: @escaping () -> Void){
        Task {
            var dataSum: Data = Data()
            var response = await send(apdu: self.GET_VERSION_REQ)
            dataSum.append(response!.0)
            response = await send(apdu: self.GET_VERSION_AF_REQ)
            dataSum.append(response!.0)
            response = await send(apdu: self.GET_VERSION_AF_REQ)
            dataSum.append(response!.0)
            self.identifier = dataSum.hexEncodedString()
            completion()
        }
        print("done with task")
        }
    }
   

