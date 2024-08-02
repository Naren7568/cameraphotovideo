//
//  ViewController.swift
//  cameraMultiplePhotos
//
//  Created by matraex naren on 30/07/24.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var camPreviewContainer: cameraContainerView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.camPreviewContainer.setUp()
        self.camPreviewContainer.delegate = self
        // Do any additional setup after loading the view.
    }


}
extension ViewController:cameraContainerViewDelegate
{
    func cameraContainerViewDidCancelled(_ cameraContainer: cameraContainerView)
    {
        
    }
    func cameraContainerViewDidFinished(_ cameraContainer: cameraContainerView)
    {
        
    }
    func cameraContainerViewDidProcessedPhoto(_ imagedata: Data)
    {
        
    }
    func cameraContainerViewDidFinishedRecording(_ videoTempUrl: URL)
    {
        
    }
}
