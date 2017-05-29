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
import SwiftyJSON

class ChatViewController: UIViewController, WebSocketDelegate,
                            RTCPeerConnectionDelegate, RTCEAGLVideoViewDelegate {
    var websocket: WebSocket! = nil
    
    var peerConnectionFactory: RTCPeerConnectionFactory! = nil
    var peerConnection: RTCPeerConnection! = nil
    var localVideoTrack: RTCVideoTrack?
    var remoteVideoTrack: RTCVideoTrack?

    @IBOutlet weak var cameraPreview: RTCCameraPreviewView!
    @IBOutlet weak var remoteVideoView: RTCEAGLVideoView!
    @IBOutlet weak var connectButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        remoteVideoView.delegate = self
        // RTCPeerConnectionFactoryの初期化
        peerConnectionFactory = RTCPeerConnectionFactory()
        
        websocket = WebSocket(url: URL(string: "wss://conf.space/WebRTCHandsOnSig/tnoho")!)
        websocket.delegate = self
        websocket.connect()
    }
    
    func createPeerConnection() {
        // STUN/TURNサーバーの指定
        let configuration = RTCConfiguration()
        configuration.iceServers = [
            RTCIceServer.init(
                urlStrings: ["stun:stun.l.google.com:19302"])]
        // PeerConecctionの設定(今回はなし)
        let peerConnectionConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        // PeerConnectionの初期化
        peerConnection = peerConnectionFactory.peerConnection(
            with: configuration, constraints: peerConnectionConstraints, delegate: self)
        
        // 音声ソースの設定
        let audioSourceConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        // 音声ソースの生成
        let audioSource = peerConnectionFactory.audioSource(with: audioSourceConstraints)
        // 音声トラックの作成
        let localAudioTrack = peerConnectionFactory.audioTrack(with: audioSource, trackId: "ARDAMSa0")
        // PeerConnectionからSenderを作成
        let audioSender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindAudio, streamId: "ARDAMS")
        // Senderにトラックを設定
        audioSender.track = localAudioTrack
        
        // 映像ソースの設定
        let videoSourceConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        let videoSource = peerConnectionFactory.avFoundationVideoSource(with: videoSourceConstraints)
        // 映像ソースをプレビューに設定
        cameraPreview.captureSession = videoSource.captureSession
        // 映像トラックの作成
        localVideoTrack = peerConnectionFactory.videoTrack(with: videoSource, trackId: "ARDAMSv0")
        // PeerConnectionからVideoのSenderを作成
        let videoSender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindVideo, streamId: "ARDAMS")
        // Senderにトラックを設定
        videoSender.track = localVideoTrack
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  
    @IBAction func connectButtonAction(_ sender: Any) {
        connectButton.isHidden = true
        createOffer()
    }
    
    func createOffer() {
        let constraints = RTCMediaConstraints(mandatoryConstraints: [
            "OfferToReceiveAudio": "true",
            "OfferToReceiveVideo": "true"
            ], optionalConstraints: nil)
        let offerCompletion = { (offer: RTCSessionDescription?, error: Error?) in
            let setLocalDescCompletion = {(error: Error?) in
                self.sendSDP(offer!)
            }
            self.peerConnection.setLocalDescription(offer!, completionHandler: setLocalDescCompletion)
        }
        self.peerConnection.offer(for: constraints, completionHandler: offerCompletion)
    }
    
    func createAnswer() {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let answerCompletion = { (answer: RTCSessionDescription?, error: Error?) in
            let setLocalDescCompletion = {(error: Error?) in
                self.sendSDP(answer!)
            }
            self.peerConnection.setLocalDescription(answer!, completionHandler: setLocalDescCompletion)
        }
        self.peerConnection.answer(for: constraints, completionHandler: answerCompletion)
    }
    
    func sendSDP(_ desc: RTCSessionDescription) {
        let jsonSdp: JSON = [
            "sdp": desc.sdp,
            "type": RTCSessionDescription.string(for: desc.type)
        ]
        websocket.write(string: jsonSdp.rawString()!)
    }

    func websocketDidConnect(socket: WebSocket) {
        LOG("websocketが接続されました")
        createPeerConnection()
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        LOG("websocketが切断されました: \(String(describing: error?.localizedDescription))")
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        LOG("Messageを受信しました : \(text)")
        let jsonMessage = JSON.parse(text)
        let type = jsonMessage["type"].stringValue
        switch (type) {
            case "offer":
                connectButton.isHidden = true
                let offer = RTCSessionDescription(
                    type: RTCSessionDescription.type(for: jsonMessage["type"].stringValue),
                    sdp: jsonMessage["sdp"].stringValue)
                self.peerConnection.setRemoteDescription(offer, completionHandler: {(error: Error?) in
                    self.createAnswer()
                })
            case "answer":
                let answer = RTCSessionDescription(
                    type: RTCSessionDescription.type(for: jsonMessage["type"].stringValue),
                    sdp: jsonMessage["sdp"].stringValue)
                self.peerConnection.setRemoteDescription(answer, completionHandler: {(error: Error?) in })
            case "candidate":
                let candidate = RTCIceCandidate(
                    sdp: jsonMessage["ice"]["candidate"].stringValue,
                    sdpMLineIndex: jsonMessage["ice"]["sdpMLineIndex"].int32Value,
                    sdpMid: jsonMessage["ice"]["sdpMid"].stringValue)
                self.peerConnection.add(candidate)
            default:
                return
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        LOG("Dataを受信しました : \(data.count)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        // 接続情報交換の状況が変化した際に呼ばれます
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        // 映像/音声が追加された際に呼ばれます
        DispatchQueue.main.async(execute: { () -> Void in
            if (stream.videoTracks.count > 0) {
                self.remoteVideoTrack = stream.videoTracks[0]
                self.remoteVideoTrack?.add(self.remoteVideoView)
                print("remoteVideoView added")
            }
        })
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        // 映像/音声削除された際に呼ばれます
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        // 接続情報の交換が必要になった際に呼ばれます
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        // PeerConnectionの接続状況が変化した際に呼ばれます
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        // 接続先候補の探索状況が変化した際に呼ばれます
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        // Candidate(自分への接続先候補情報)が生成された際に呼ばれます
        let jsonCandidate: JSON = [
            "type": "candidate",
            "ice": [
                    "candidate": candidate.sdp,
                    "sdpMLineIndex": candidate.sdpMLineIndex,
                    "sdpMid": candidate.sdpMid!
                ]
            ]
        websocket.write(string: jsonCandidate.rawString()!)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        // DataChannelが作られた際に呼ばれます
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        // Candidateが削除された際に呼ばれます
    }
    
    func videoView(_ videoView: RTCEAGLVideoView, didChangeVideoSize size: CGSize) {
        let width = self.view.frame.width
        let height = self.view.frame.width * size.height / size.width
        remoteVideoView.frame = CGRect(
            x: 0,
            y: (self.view.frame.height - height) / 2,
            width: width,
            height: height)
    }
    
    func hangUp() {
        if remoteVideoTrack != nil {
            remoteVideoTrack?.remove(remoteVideoView)
        }
        localVideoTrack = nil
        remoteVideoTrack = nil
        peerConnection = nil
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        // 切断ボタンを押した時
        websocket.disconnect()
        hangUp()
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
