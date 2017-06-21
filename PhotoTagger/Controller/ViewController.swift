/*
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import Alamofire


class ViewController: UIViewController {

  // MARK: - IBOutlets
  @IBOutlet var takePictureButton: UIButton!
  @IBOutlet var imageView: UIImageView!
  @IBOutlet var progressView: UIProgressView!
  @IBOutlet var activityIndicatorView: UIActivityIndicatorView!

  // MARK: - Properties
  fileprivate var tags: [String]?
  fileprivate var colors: [PhotoColor]?

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    guard !UIImagePickerController.isSourceTypeAvailable(.camera) else { return }

    takePictureButton.setTitle("Select Photo", for: .normal)
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    imageView.image = nil
  }

  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

    if segue.identifier == "ShowResults" {
      let controller = segue.destination as! TagsColorsViewController
      controller.tags = tags
      controller.colors = colors
    }
  }

  // MARK: - IBActions
  @IBAction func takePicture(_ sender: UIButton) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.allowsEditing = false

    if UIImagePickerController.isSourceTypeAvailable(.camera) {
      picker.sourceType = .camera
    } else {
      picker.sourceType = .photoLibrary
      picker.modalPresentationStyle = .fullScreen
    }

    present(picker, animated: true)
  }
}

// MARK: - UIImagePickerControllerDelegate
extension ViewController: UIImagePickerControllerDelegate {

  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String: Any]) {
    
    guard let image = info[UIImagePickerControllerOriginalImage] as? UIImage else {
      
      print("Info did not have the required UIImage for the Original Image")
      dismiss(animated: true)
      return
    }
    
    imageView.image = image
    
    takePictureButton.isHidden = true
    progressView.progress = 0.0
    progressView.isHidden = false
    activityIndicatorView.startAnimating()
    
    upload(image: image, progressCompletion: { [unowned self] percent in
      
      self.progressView.setProgress(percent, animated: true)
    }) { [unowned self] tags , colors in
      
      self.takePictureButton.isHidden = false
      self.progressView.isHidden = true
      self.activityIndicatorView.stopAnimating()
      
      self.tags = tags
      self.colors = colors
      
      self.performSegue(withIdentifier: "ShowResults", sender: self )
      
    }
    dismiss(animated: true)
  }
}

extension ViewController {
  
  func upload(image: UIImage,
              progressCompletion: @escaping (_ percent: Float) -> Void,
              completion: @escaping (_ tags: [String], _ colors: [PhotoColor]) -> Void) {
   
    guard let imageData = UIImageJPEGRepresentation(image, 0.5) else {
      print("Could not get JPEG representation of UIImage")
      return
    }
    
    Alamofire.upload(multipartFormData: { (multipartFormData) in
    
      //
      multipartFormData.append(imageData, withName: "imagefile", fileName: "image.jpg", mimeType: "image/jpeg")
    }, with: ImaggaRouter.content,
       encodingCompletion: { (endcodingResults) in
        switch endcodingResults {
         
        case .failure(let error):
          print("ERROR",error.localizedDescription)
          break
        case .success(let uploadResponse,_ ,_):
       
          uploadResponse.uploadProgress{ progress in
            
            progressCompletion(Float(progress.fractionCompleted))
          }
        uploadResponse.validate()
        uploadResponse.responseJSON { response in
          
          // 1.
          guard response.result.isSuccess else {
            print("Error while uploading file: \(String(describing: response.result.error))")
            completion([String](), [PhotoColor]())
            return
          }
          
          // 2.
          guard let responseJSON = response.result.value as? [String: Any],
            let uploadedFiles = responseJSON["uploaded"] as? [[String: Any]],
            let firstFile = uploadedFiles.first,
            let firstFileID = firstFile["id"] as? String else {
              print("Invalid information received from service")
              completion([String](), [PhotoColor]())
              return
          }
          
          
          //3.
          print("Content uploaded with ID: \(firstFileID)")
          self.downloadTag(contentID: firstFileID) { tags in
            completion(tags, [PhotoColor]())
          }
        }
          break
        }
        
      })
  
  }
  
  func  downloadTag(contentID: String, completion: @escaping ([String])->()){
    
    Alamofire.request(ImaggaRouter.tags(contentID)
    ).responseJSON { (response) in
      
      // 1.
      guard response.result.isSuccess else {
        print("Error while fetching tags: \(response.result.error)")
        completion([String]())
        return
      }
      
      // 2.
      guard let responseJSON = response.result.value as? [String: Any],
        let results = responseJSON["results"] as? [[String: Any]],
        let firstObject = results.first,
        let tagsAndConfidences = firstObject["tags"] as? [[String: Any]] else {
          print("Invalid tag information received from the service")
          completion([String]())
          return
      }
      
      print(responseJSON)
      
      // 3.
      let tags = tagsAndConfidences.flatMap({ dict in
        return dict["tag"] as? String
      })
      
      // 4.
      completion(tags)
    }
  
  }

  
  func downloadColor(){
    
  }
}


// MARK: - UINavigationControllerDelegate
extension ViewController: UINavigationControllerDelegate {
}


