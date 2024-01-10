//
//  Mqtt5Client.swift
//  Plugin
//
//  Created by Matthias on 08.01.24.
//  Copyright © 2024 Max Lynch. All rights reserved.
//

import Foundation
import CocoaMQTT
import CoreNFC

public class Mqtt5Client: CocoaMQTT5Delegate {
    
    private var clientID: String
    
    private var mqtt5: CocoaMQTT5
    private var nfcSession: NfcSession? = nil
    
    private let DOCUMENT_DIR = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path

    init(clientID: String, host: String, port: UInt16, clientCertArray: CFArray?) {
        self.clientID = clientID
        print("\(clientID) - \(host) - \(port)")
        self.mqtt5 = CocoaMQTT5(clientID: clientID, host: host, port: port)

        let connectProperties = MqttConnectProperties()
        connectProperties.topicAliasMaximum = 0
        connectProperties.sessionExpiryInterval = 0
        connectProperties.receiveMaximum = 100
        connectProperties.maximumPacketSize = 500
        mqtt5.connectProperties = connectProperties
  
        mqtt5.username = ""
        mqtt5.password = ""
        mqtt5.keepAlive = 60
        mqtt5.delegate = self
        mqtt5.enableSSL = true
        mqtt5.allowUntrustCACertificate = true
        
        var sslSettings: [String: NSObject] = [:]
        sslSettings[kCFStreamSSLCertificates as String] = clientCertArray
        mqtt5.sslSettings = sslSettings
        mqtt5.connect(timeout: 10)
        print("connect")
    }
    
    public func getClientID() -> String {
        return clientID
    }
    
    public func setNfcSession(nfcSession: NfcSession){
        self.nfcSession = nfcSession
    }
    
    public func disconnect() {
        self.publishMessage(topic: "readers/1", message: Message(t: "cr", e: "off", oid: self.clientID, atr: nil))
        self.mqtt5.disconnect()
    }
    
    public func publishMessage(topic: String, payload: [UInt8]?) {
        guard payload != nil else {
            print("Error creating Msg - no Payload")
            return
        }
        mqtt5.publish(CocoaMQTT5Message(topic: topic, payload: payload!), properties: MqttPublishProperties.init())
    }
    
    public func publishMessage(topic: String, message: Message?) {
        guard message != nil && message!.toJson() != nil else {
            print("Error creating Msg")
            return
        }
        mqtt5.publish(topic, withString: message!.toJson()!, properties: MqttPublishProperties.init())
    }
    
    public func mqtt5(_ mqtt5: CocoaMQTT5, didStateChangeTo state: CocoaMQTTConnState) {
        print("state reached \(state)")

        if state == .connected {
            mqtt5.subscribe([MqttSubscription.init(topic: "readers/1/\(clientID)/t")])
            self.publishMessage(topic: "readers/1", message: Message(t: "cr", e: "on", oid: self.clientID, atr: nil))
            self.nfcSession?.setMqtt5Client(mqtt5: self)
        }
        else if state == .disconnected && nfcSession != nil && nfcSession?.getNfcTagReaderSession() != nil {
            nfcSession!.getNfcTagReaderSession()?.invalidate(errorMessage: "Connection to broker lost.")
        }
    }

    public func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveMessage message: CocoaMQTT5Message, id: UInt16, publishData: MqttDecodePublish?) {
        print("did reciveMsg")
        Task {
            print("Start task")
            let resp = await self.nfcSession?.send(apdu: NFCISO7816APDU(data: Data(message.payload))!)
            var apduArr:[UInt8] = [UInt8](resp!.0)
            apduArr.append(resp!.1)
            apduArr.append(resp!.2)
            print("publishing")
            print(apduArr)
            self.publishMessage(topic: "readers/1/\(clientID)/f", payload: apduArr)
        }
    }

    public func mqtt5DidPing(_ mqtt5: CocoaMQTT5) {
        self.publishMessage(topic: "readers/1", message: Message(t: "cr", e: "hb", oid: self.clientID, atr: nil))
    }
    
    public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishMessage message: CocoaMQTT5Message, id: UInt16) {
        let payData = Data(message.payload)
        print("Did publish: \(payData.hexEncodedString())")
    }

    public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishAck id: UInt16, pubAckData: MqttDecodePubAck?) {

        if(pubAckData != nil){
            print("pubAckData reasonCode: \(String(describing: pubAckData!.reasonCode))")
        }
    }

    public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishRec id: UInt16, pubRecData: MqttDecodePubRec?) {

        if(pubRecData != nil){
            print("pubRecData reasonCode: \(String(describing: pubRecData!.reasonCode))")
        }
    }

    public func mqtt5(_ mqtt5: CocoaMQTT5, didPublishComplete id: UInt16,  pubCompData: MqttDecodePubComp?){
        if(pubCompData != nil){
            print("pubCompData reasonCode: \(String(describing: pubCompData!.reasonCode))")
        }
    }
    
    public func mqtt5(_ mqtt5: CocoaMQTT5, didSubscribeTopics success: NSDictionary, failed: [String], subAckData: MqttDecodeSubAck?) {
        print("subscribed successfully")
        if(subAckData != nil){
            print("subAckData.reasonCodes \(String(describing: subAckData!.reasonCodes))")
        }
    }

    public func mqtt5(_ mqtt5: CocoaMQTT5, didUnsubscribeTopics topics: [String], unsubAckData: MqttDecodeUnsubAck?) {
        if(unsubAckData != nil){
            print("unsubAckData.reasonCodes \(String(describing: unsubAckData!.reasonCodes))")
        }

    }
    
    public func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveDisconnectReasonCode reasonCode: CocoaMQTTDISCONNECTReasonCode) {
        print("disconnect res : \(reasonCode)")
    }

    public func mqtt5(_ mqtt5: CocoaMQTT5, didReceiveAuthReasonCode reasonCode: CocoaMQTTAUTHReasonCode) {
        print("auth res : \(reasonCode)")
    }

    // Optional ssl CocoaMQTT5Delegate
    public func mqtt5(_ mqtt5: CocoaMQTT5, didReceive trust: SecTrust, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    public func mqtt5(_ mqtt5: CocoaMQTT5, didConnectAck ack: CocoaMQTTCONNACKReasonCode, connAckData: MqttDecodeConnAck?) {
        print("DidConnectAck")
    }


    public func mqtt5DidReceivePong(_ mqtt5: CocoaMQTT5) {
        print("Did long Ping")
    }

    public func mqtt5DidDisconnect(_ mqtt5: CocoaMQTT5, withError err: Error?) {
        let name = NSNotification.Name(rawValue: "MQTTMessageNotificationDisconnect")
        NotificationCenter.default.post(name: name, object: nil)
        print("Did Disconnect")
    }
}
