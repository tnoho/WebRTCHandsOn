//
//  ChatViewController.swift
//  WebRTCHandsOn
//
//  Created by Takumi Minamoto on 2017/05/27.
//  Copyright © 2017 tnoho. All rights reserved.
//

import UIKit
import WebRTC
import Starscream

class ChatViewController: UIViewController, WebSocketDelegate {
    var websocket: WebSocket! = nil

    @IBOutlet weak var cameraPreview: RTCCameraPreviewView!
    @IBOutlet weak var remoteVideoView: RTCEAGLVideoView!
    @IBOutlet weak var connectButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        websocket = WebSocket(url: URL(string: "wss://conf.space/WebRTCHandsOnSig/tnoho")!)
        websocket.delegate = self
        websocket.connect()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  
    @IBAction func connectButtonAction(_ sender: Any) {
    }

    func websocketDidConnect(socket: WebSocket) {
        LOG("websocketが接続されました")
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        LOG("websocketが切断されました: \(String(describing: error?.localizedDescription))")
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        LOG("Messageを受信しました : \(text)")
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        LOG("Dataを受信しました : \(data.count)")
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        // 切断ボタンを押した時
        websocket.disconnect()
        _ = self.navigationController?.popToRootViewController(animated: true)
    }
    
    // 参考にさせていただきました！Thanks: http://seesaakyoto.seesaa.net/article/403680516.html
    func LOG(_ body: String = "",
             function: String = #function,
             line: Int = #line)
    {
        print("[\(function) : \(line)] \(body)")
    }
}
