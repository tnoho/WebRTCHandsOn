//
//  ChatViewController.swift
//  WebRTCHandsOn
//
//  Created by Takumi Minamoto on 2017/05/27.
//  Copyright © 2017 tnoho. All rights reserved.
//

import UIKit
import WebRTC

class ChatViewController: UIViewController {

    @IBOutlet weak var localVideoView: RTCEAGLVideoView!
    @IBOutlet weak var remoteVideoView: RTCEAGLVideoView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func disconnectButtonAction(_ sender: Any) {
        _ = self.navigationController?.popToRootViewController(animated: true)
    }
}
