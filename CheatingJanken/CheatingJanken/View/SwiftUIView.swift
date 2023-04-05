//
//  HandGestureTestView.swift
//  CheatingJanken
//
//  Created by トム・クルーズ on 2023/04/03.
//

import SwiftUI
import AVFoundation
import Vision

struct HandGestureTestView: View {
    // CameraModelのインスタンス生成
    @ObservedObject var camera = CameraModel()
    // Viewの背景色のプロパティ
    @State var backgroundColor = Color.red
    // カメラのオンオフを切り替えるプロパティ
    @State var isCamera = false
    
    var body: some View {
        ZStack {
            CameraView(camera: camera)
                .edgesIgnoringSafeArea(.all)
            
            backgroundColor.opacity(0.4)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text(camera.handGestureDetector.currentGesture.rawValue) // @Publishedプロパティを使用
                    .bold()
                    .font(.system(size: 50))
                    .foregroundColor(Color.white)
                
                // カメラのオンオフの切り替え
                Button {
                    isCamera ? camera.start() : camera.stop()
                    isCamera.toggle()
                } label: {
                    Text(isCamera ? "スタート" : "ストップ")
                        .bold()
                        .font(.system(size: 50))
                        .foregroundColor(Color.white)
                        .frame(width: 200, height: 80)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                }
            }
        }
        // currentGestureに応じて背景色を変化させる
        .onChange(of: camera.handGestureDetector.currentGesture.rawValue) { currentGesture in
            withAnimation {
                backgroundColor = (currentGesture == "？？？" ? .red : .green)
            }
        }
    }
}

// カメラのプレビューレイヤーを設定
struct CameraView: UIViewRepresentable {
    @ObservedObject var camera: CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let previewView = UIView(frame: UIScreen.main.bounds)
        camera.addPreviewLayer(to: previewView)
        context.coordinator.camera = camera // CoordinatorにCameraModelを渡す
        return previewView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // ここでは何もしない。
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(camera: camera)
        camera.handGestureDetector.delegate = coordinator // Coodinatorをデリゲートとして設定
        return coordinator
    }
    
    class Coordinator: NSObject, HandGestureDetectorDelegate {
        @ObservedObject var camera: CameraModel // CameraModelを監視可能にするために@ObservedObjectを追加
        
        init(camera: CameraModel) {
            self.camera = camera
        }
        
        // HandGestureを判定してcurrentGesture（画面に表示するプロパティ）に格納
        func handGestureDetector(_ handGestureDetector: HandGestureDetector, didRecognize gesture: HandGestureDetector.HandGesture) {
            DispatchQueue.main.async {
                self.camera.currentGesture = gesture // @Publishedプロパティに値を設定
            }
        }
    }
}

class CameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate, HandGestureDetectorDelegate {
    func handGestureDetector(_ handGestureDetector: HandGestureDetector, didRecognize gesture: HandGestureDetector.HandGesture) {
    }
    
    let session = AVCaptureSession()
    let handGestureDetector: HandGestureDetector
    weak var delegate: HandGestureDetectorDelegate?
    
    @Published var currentGesture: HandGestureDetector.HandGesture = .unknown // @Publishedプロパティに変更
    
    override init() {
        handGestureDetector = HandGestureDetector()
        super.init()
        handGestureDetector.delegate = self
        do {
            session.sessionPreset = .photo
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            let input = try AVCaptureDeviceInput(device: device!)
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: .main)
            session.addOutput(output)
            let view = UIView(frame: UIScreen.main.bounds)
            addPreviewLayer(to: view)
            session.commitConfiguration()
            session.startRunning()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // キャプチャを停止するメソッド
    func stop() {
        session.stopRunning()
    }
    
    // キャプチャを再開するメソッド
    func start() {
        session.startRunning()
    }
    
    // キャプチャセッションから得られたカメラ映像を表示するためのレイヤーを追加するメソッド
    func addPreviewLayer(to view: UIView) {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = UIScreen.main.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer) // UIViewにAVCaptureVideoPreviewLayerを追加
    }
    
    // AVCaptureVideoDataOutputから取得した動画フレームからてのジェスチャーを検出するメソッド
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let request = try? handGestureDetector.createDetectionRequest(pixelBuffer: pixelBuffer)
        
        guard let observations = request?.results as? [VNRecognizedPointsObservation] else {
            return
        }
        
        // 実際にジェスチャーからHandGestureを判別する
        handGestureDetector.processObservations(observations)
    }
}

// デリゲートのプロトコルを定義
protocol HandGestureDetectorDelegate: AnyObject {
    // HandGestureDetectorのHandGestureを監視してデリゲート経由でViewに通知する
    func handGestureDetector(_ handGestureDetector: HandGestureDetector, didRecognize gesture: HandGestureDetector.HandGesture)
}

// 検出されたジェスチャーからHandGestureを判別するクラス
class HandGestureDetector: ObservableObject {
    // ジャンケンの手の種類のenum
    enum HandGesture: String {
        case rock = "グー"
        case paper = "パー"
        case scissors = "チョキ"
        case unknown = "？？？"
    }
    
    // デリゲートメソッドに渡す用のHandGestureプロパティ
    var currentGesture: HandGesture = .unknown {
        didSet {
            delegate?.handGestureDetector(self, didRecognize: currentGesture)
        }
    }
    
    // デリゲートを持たせるためのプロパティ
    weak var delegate: HandGestureDetectorDelegate?
    
    // デリゲートを初期化
    init(delegate: HandGestureDetectorDelegate? = nil) {
        self.delegate = delegate
    }
    
    func createDetectionRequest(pixelBuffer: CVPixelBuffer) throws -> VNImageBasedRequest {
        // 人間の手を検出するリクエストクラスのインスタンス生成
        let request = VNDetectHumanHandPoseRequest()
        // 画像内で検出する手の最大数
        request.maximumHandCount = 1
        // 画像内に関する１つ以上の画像分析を要求する処理
        try VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
        return request
    }
    
    // HandPoseを判別するメソッド
    func processObservations(_ observations: [VNRecognizedPointsObservation]) {
        guard let points = try? observations.first?.recognizedPoints(forGroupKey: .all) else {
            return
        }
        
        // 指先
        let indexTip = points[VNHumanHandPoseObservation.JointName.indexTip.rawValue]?.location ?? .zero
        let middleTip = points[VNHumanHandPoseObservation.JointName.middleTip.rawValue]?.location ?? .zero
        let ringTip = points[VNHumanHandPoseObservation.JointName.ringTip.rawValue]?.location ?? .zero
        let littleTip = points[VNHumanHandPoseObservation.JointName.littleTip.rawValue]?.location ?? .zero
        // 近位指節間(PIP)関節 ＝ 第二関節のこと
        let indexPIP = points[VNHumanHandPoseObservation.JointName.indexPIP.rawValue]?.location ?? .zero
        let middlePIP = points[VNHumanHandPoseObservation.JointName.middlePIP.rawValue]?.location ?? .zero
        let ringPIP = points[VNHumanHandPoseObservation.JointName.ringPIP.rawValue]?.location ?? .zero
        let littlePIP = points[VNHumanHandPoseObservation.JointName.littlePIP.rawValue]?.location ?? .zero
        // 手首
        let wrist = points[VNHumanHandPoseObservation.JointName.wrist.rawValue]?.location ?? .zero
        
        // 手首から指先の長さ
        let wristToIndexTip = distance(from: wrist, to: indexTip)
        let wristToMiddleTip = distance(from: wrist, to: middleTip)
        let wristToRingTip = distance(from: wrist, to: ringTip)
        let wristToLittleTip = distance(from: wrist, to: littleTip)
        
        // 手首から近位指節間(PIP)関節の長さ
        let wristToIndexPIP = distance(from: wrist, to: indexPIP)
        let wristToMiddlePIP = distance(from: wrist, to: middlePIP)
        let wristToRingPIP = distance(from: wrist, to: ringPIP)
        let wristToLittlePIP = distance(from: wrist, to: littlePIP)
        
        // 人差し指が曲がっているかチェック
        if wristToIndexTip > wristToIndexPIP {
            print("人差し指：まっすぐ")
        } else if wristToIndexTip < wristToIndexPIP {
            print("人差し指：曲がってる")
        }
        // 中指が曲がっているかチェック
        if wristToMiddleTip > wristToMiddlePIP {
            print("中指：まっすぐ")
        } else if wristToMiddleTip < wristToMiddlePIP {
            print("中指：曲がってる")
        }
        // 薬指が曲がっているかチェック
        if wristToRingTip > wristToRingPIP {
            print("薬指：まっすぐ")
        } else if wristToRingTip < wristToRingPIP {
            print("薬指：曲がってる")
        }
        // 小指が曲がっているかチェック
        if wristToLittleTip > wristToLittlePIP {
            print("小指：まっすぐ")
        } else if wristToLittleTip < wristToLittlePIP {
            print("小指：曲がってる")
        }
        
        // HandPoseの判定(どの指が曲がっているかでグーチョキパーを判定する）
        if
            wristToIndexTip > wristToIndexPIP &&
                wristToMiddleTip > wristToMiddlePIP &&
                wristToRingTip > wristToRingPIP &&
                wristToLittleTip > wristToLittlePIP {
            // ４本の指が曲がっていないのでぱー
            currentGesture = .paper
        } else if
            wristToIndexTip > wristToIndexPIP &&
                wristToMiddleTip > wristToMiddlePIP &&
                wristToRingTip < wristToRingPIP &&
                wristToLittleTip < wristToLittlePIP {
            // IndexとMiddleが曲がっていないのでちょき
            currentGesture = .scissors
        } else if
            wristToIndexTip < wristToIndexPIP &&
                wristToMiddleTip < wristToMiddlePIP &&
                wristToRingTip < wristToRingPIP &&
                wristToLittleTip < wristToLittlePIP {
            // ４本の指が曲がっているのでぐー
            currentGesture = .rock
        } else {
            currentGesture = .unknown
        }
        
        print(currentGesture.rawValue)
        print("--------------")
        
        // デリゲートを呼び出す
        delegate?.handGestureDetector(self, didRecognize: currentGesture) // delegate 経由で currentGesture を通知する
    }
    
    // 画面上の２点間の距離を三平方の定理より求める
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        return sqrt(pow(from.x - to.x, 2) + pow(from.y - to.y, 2))
    }
}

struct HandGestureTestView_Previews: PreviewProvider {
    static var previews: some View {
        HandGestureTestView()
    }
}