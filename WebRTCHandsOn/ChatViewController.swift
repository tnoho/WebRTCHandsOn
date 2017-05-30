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
    var remoteVideoTrack: RTCVideoTrack?
    var audioSource: RTCAudioSource?
    var videoSource: RTCAVFoundationVideoSource?

    @IBOutlet weak var cameraPreview: RTCCameraPreviewView!
    @IBOutlet weak var remoteVideoView: RTCEAGLVideoView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        remoteVideoView.delegate = self
        // RTCPeerConnectionFactoryの初期化
        peerConnectionFactory = RTCPeerConnectionFactory()
        
        startVideo()
        
        websocket = WebSocket(url: URL(string: "wss://conf.space/WebRTCHandsOnSig/tnoho")!)
        websocket.delegate = self
        websocket.connect()
    }
    
    deinit {
        if peerConnection != nil {
            hangUp()
        }
        audioSource = nil
        videoSource = nil
        peerConnectionFactory = nil
    }
    
    func startVideo() {
        // 音声ソースの設定
        let audioSourceConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        // 音声ソースの生成
        audioSource = peerConnectionFactory.audioSource(with: audioSourceConstraints)
        
        // 映像ソースの設定
        let videoSourceConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        videoSource = peerConnectionFactory.avFoundationVideoSource(with: videoSourceConstraints)
        // 映像ソースをプレビューに設定
        cameraPreview.captureSession = videoSource?.captureSession
    }
    
    func prepareNewConnection() -> RTCPeerConnection {
        // STUN/TURNサーバーの指定
        let configuration = RTCConfiguration()
        configuration.iceServers = [
            RTCIceServer.init(
                urlStrings: ["stun:stun.l.google.com:19302"])]
        // PeerConecctionの設定(今回はなし)
        let peerConnectionConstraints = RTCMediaConstraints(
            mandatoryConstraints: nil, optionalConstraints: nil)
        // PeerConnectionの初期化
        let peerConnection = peerConnectionFactory.peerConnection(
            with: configuration, constraints: peerConnectionConstraints, delegate: self)
        
        // 音声トラックの作成
        let localAudioTrack = peerConnectionFactory.audioTrack(with: audioSource!, trackId: "ARDAMSa0")
        // PeerConnectionからSenderを作成
        let audioSender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindAudio, streamId: "ARDAMS")
        // Senderにトラックを設定
        audioSender.track = localAudioTrack
        
        
        // 映像トラックの作成
        let localVideoTrack = peerConnectionFactory.videoTrack(with: videoSource!, trackId: "ARDAMSv0")
        // PeerConnectionからVideoのSenderを作成
        let videoSender = peerConnection.sender(withKind: kRTCMediaStreamTrackKindVideo, streamId: "ARDAMS")
        // Senderにトラックを設定
        videoSender.track = localVideoTrack
        
        return peerConnection
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  
    @IBAction func connectButtonAction(_ sender: Any) {
        if peerConnection == nil {
            LOG("make Offer")
            makeOffer()
        } else {
            LOG("peer already exist.")
        }
    }
    
    func websocketDidConnect(socket: WebSocket) {
        LOG()
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        LOG("error: \(String(describing: error?.localizedDescription))")
    }
    
    func makeOffer() {
        peerConnection = prepareNewConnection()
        let constraints = RTCMediaConstraints(mandatoryConstraints: [
            "OfferToReceiveAudio": "true",
            "OfferToReceiveVideo": "true"
            ], optionalConstraints: nil)
        let offerCompletion = { (offer: RTCSessionDescription?, error: Error?) in
            if error != nil { return }
            self.LOG("createOffer() succsess")
            let setLocalDescCompletion = {(error: Error?) in
                if error != nil { return }
                self.LOG("setLocalDescription() succsess")
                self.sendSDP(offer!)
            }
            self.peerConnection.setLocalDescription(offer!, completionHandler: setLocalDescCompletion)
        }
        self.peerConnection.offer(for: constraints, completionHandler: offerCompletion)
    }
    
    func makeAnswer() {
        LOG("sending Answer. Creating remote session description...")
        if peerConnection == nil {
            LOG("peerConnection NOT exist!")
            return
        }
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let answerCompletion = { (answer: RTCSessionDescription?, error: Error?) in
            if error != nil { return }
            self.LOG("createAnswer() succsess")
            let setLocalDescCompletion = {(error: Error?) in
                if error != nil { return }
                self.LOG("setLocalDescription() succsess")
                self.sendSDP(answer!)
            }
            self.peerConnection.setLocalDescription(answer!, completionHandler: setLocalDescCompletion)
        }
        self.peerConnection.answer(for: constraints, completionHandler: answerCompletion)
    }
    
    func sendSDP(_ desc: RTCSessionDescription) {
        LOG("---sending sdp ---")
        let jsonSdp: JSON = [
            "sdp": desc.sdp,
            "type": RTCSessionDescription.string(for: desc.type)
        ]
        let message = jsonSdp.rawString()!
        LOG("sending SDP=" + message)
        websocket.write(string: message)
    }
    
    func setOffer(_ offer: RTCSessionDescription) {
        if peerConnection != nil {
            LOG("peerConnection alreay exist!")
        }
        peerConnection = prepareNewConnection()
        self.peerConnection.setRemoteDescription(offer, completionHandler: {(error: Error?) in
            if error == nil {
                self.LOG("setRemoteDescription(offer) succsess")
                self.makeAnswer()
            } else {
                self.LOG("setRemoteDescription(offer) ERROR: " + error.debugDescription)
            }
        })
    }
    
    func setAnswer(_ answer: RTCSessionDescription) {
        if peerConnection == nil {
            LOG("peerConnection NOT exist!")
            return
        }
        self.peerConnection.setRemoteDescription(answer, completionHandler: {
            (error: Error?) in
            if error == nil {
                self.LOG("setRemoteDescription(answer) succsess")
            } else {
                self.LOG("setRemoteDescription(answer) ERROR: " + error.debugDescription)
            }
        })
    }
    
    func addIceCandidate(_ candidate: RTCIceCandidate) {
        if peerConnection != nil {
            peerConnection.add(candidate)
        } else {
            LOG("PeerConnection not exist!")
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        LOG("message: \(text)")
        let jsonMessage = JSON.parse(text)
        let type = jsonMessage["type"].stringValue
        switch (type) {
        case "offer":
            LOG("Received offer ...")
            let offer = RTCSessionDescription(
                type: RTCSessionDescription.type(for: jsonMessage["type"].stringValue),
                sdp: jsonMessage["sdp"].stringValue)
            setOffer(offer)
        case "answer":
            LOG("Received answer ...")
            let answer = RTCSessionDescription(
                type: RTCSessionDescription.type(for: jsonMessage["type"].stringValue),
                sdp: jsonMessage["sdp"].stringValue)
            setAnswer(answer)
        case "candidate":
            LOG("Received ICE candidate ...")
            let candidate = RTCIceCandidate(
                sdp: jsonMessage["ice"]["candidate"].stringValue,
                sdpMLineIndex: jsonMessage["ice"]["sdpMLineIndex"].int32Value,
                sdpMid: jsonMessage["ice"]["sdpMid"].stringValue)
            addIceCandidate(candidate)
        case "close":
            LOG("peer is closed ...")
            hangUp()
        default:
            return
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: Data) {
        LOG("data.count: \(data.count)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        // 接続情報交換の状況が変化した際に呼ばれます
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        // 映像/音声が追加された際に呼ばれます
        LOG("-- peer.onaddstream()")
        DispatchQueue.main.async(execute: { () -> Void in
            if (stream.videoTracks.count > 0) {
                self.remoteVideoTrack = stream.videoTracks[0]
                self.remoteVideoTrack?.add(self.remoteVideoView)
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
        var state = ""
        switch (newState) {
        case RTCIceConnectionState.checking:
            state = "checking"
        case RTCIceConnectionState.completed:
            state = "completed"
        case RTCIceConnectionState.connected:
            state = "connected"
        case RTCIceConnectionState.closed:
            state = "closed"
            hangUp()
        case RTCIceConnectionState.failed:
            state = "failed"
            hangUp()
        case RTCIceConnectionState.disconnected:
            state = "disconnected"
        default:
            break
        }
        LOG("ICE connection Status has changed to \(state)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        // 接続先候補の探索状況が変化した際に呼ばれます
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        // Candidate(自分への接続先候補情報)が生成された際に呼ばれます
        if candidate.sdpMid != nil {
            sendIceCandidate(candidate)
        } else {
            LOG("empty ice event")
        }
    }
    
    func sendIceCandidate(_ candidate: RTCIceCandidate) {
        LOG("---sending ICE candidate ---")
        let jsonCandidate: JSON = [
            "type": "candidate",
            "ice": [
                "candidate": candidate.sdp,
                "sdpMLineIndex": candidate.sdpMLineIndex,
                "sdpMid": candidate.sdpMid!
            ]
        ]
        let message = jsonCandidate.rawString()!
        LOG("sending candidate=" + message)
        websocket.write(string: message)
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
    
    
    @IBAction func hangupButtonAction(_ sender: Any) {
        hangUp()
    }
    
    func hangUp() {
        if peerConnection != nil {
            if peerConnection.iceConnectionState != RTCIceConnectionState.closed {
                peerConnection.close()
                let jsonClose: JSON = [
                    "type": "close"
                ]
                LOG("sending close message")
                websocket.write(string: jsonClose.rawString()!)
            }
            if remoteVideoTrack != nil {
                remoteVideoTrack?.remove(remoteVideoView)
            }
            remoteVideoTrack = nil
            peerConnection = nil
            LOG("peerConnection is closed.")
        }
    }
    
    @IBAction func closeButtonAction(_ sender: Any) {
        // 切断ボタンを押した時
        hangUp()
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
